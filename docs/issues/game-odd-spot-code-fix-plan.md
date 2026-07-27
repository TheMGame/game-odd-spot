# game-odd-spot 代码问题与改造任务清单

> 仓库：`TheMGame/game-odd-spot`  
> 审查基线：2026-07-27 可见的 `master` 分支  
> 用途：直接交给代码 AI，按优先级修改并补齐测试。

## 1. 本次改造范围

本次只处理以下内容：

- Godot 客户端状态一致性、启动流程、网络容错、缓存和性能问题。
- 客户端与服务端协议使用方式的问题。
- 服务端 HTTP 层可维护性问题。
- 自动化测试、CI 和文档一致性问题。

### 明确不在本次范围内

暂不实现或扩展“真实内容运营闭环”，包括但不限于：

- AI 图片生成模型接入。
- 视觉模型自动检测差异。
- Prompt、模型、Seed、成本等生成流水线追踪。
- 自动质检、人工审核、发布、回滚流程扩展。
- 内容 Worker 的真实模型调用。
- CMS 内容生产能力扩展。

现有 `generation`、`content-tools`、Admin 内容模块如果不影响本次缺陷修复，不要主动重构。

---

## 2. 修改原则

代码 AI 修改时必须遵守：

1. 先完成全部 P0，再处理 P1，最后处理 P2。
2. 不允许只修改 UI 文案掩盖状态错误。
3. 不允许删除离线队列或幂等机制来简化实现。
4. 不允许引入新的服务端微服务。
5. 保持现有 HTTP API 路径兼容，除非本文件明确要求调整。
6. 每个 P0、P1 问题必须有自动化测试。
7. 不要修改无关代码，不进行全项目格式化。
8. 客户端不能把“请求已从队列删除”等同于“服务端已成功处理”。
9. 所有异步请求必须区分：成功、等待重试、永久拒绝、身份失效。
10. 完成后必须同步更新 README 和相关设计文档，不能保留与实现冲突的说明。

---

# 3. P0：必须立即修复的正确性问题

## P0-01：同步队列把服务端永久拒绝误报为成功

### 涉及文件

- `client/scripts/storage/sync_queue.gd`
- `client/scenes/game/game.gd`
- 可能涉及：`client/scripts/api/api_client.gd`

### 当前问题

`SyncQueue.submit_with_key()` 的判断逻辑是：

1. 把请求加入 `_items`。
2. 执行 `flush()`。
3. 如果该 item 还在队列中，返回 `queued: true`。
4. 如果 item 已不在队列中，返回 `queued: false`。

但 `flush()` 遇到除 `401/408/429` 外的确定性 4xx 时，会直接删除该 item。因此以下两种情况都会返回同样结果：

- 服务端成功处理，item 被删除。
- 服务端返回 `400/403/404/409/422` 等永久拒绝，item 被删除。

调用方无法知道请求是真成功还是被拒绝。

### 风险

- 服务端拒绝完成关卡，客户端仍显示“全部找到了”。
- 本地完成状态与服务端状态永久分叉。
- 玩家换设备或重新登录后，进度可能回退。
- 错误只写 warning，用户和上层逻辑均无法恢复。

### 修改要求

为同步请求定义明确的终态，禁止只返回 `queued: bool`。

建议统一返回：

```gdscript
{
    "ok": true,
    "state": "synced", # synced | queued | rejected
    "status": 200,
    "error": ""
}
```

永久拒绝必须返回：

```gdscript
{
    "ok": false,
    "state": "rejected",
    "status": 422,
    "error": "LEVEL_INCOMPLETE",
    "response": {}
}
```

具体要求：

- `synced`：服务端 2xx，且已确认成功。
- `queued`：网络错误、超时、401 待刷新、408、429、5xx 等可重试错误。
- `rejected`：不可重试的 4xx。
- 不可重试 item 可以从待重试队列移除，但必须把结果返回给当前提交者。
- 后台重放时的永久失败应进入可诊断的 dead-letter 记录，不能只 `push_warning()` 后无痕删除。
- dead-letter 至少保存：path、body、idempotency key、status、error、response、created_at、failed_at、user_id。
- dead-letter 应设置数量上限，避免无限增长。

### 验收标准

- 2xx 返回 `state=synced`。
- 网络断开返回 `state=queued`，item 保留。
- 422 返回 `state=rejected`，不会被误报为成功。
- 后台重放遇到永久失败时可在日志或诊断接口中定位原始请求。
- 相同 Idempotency-Key 重试不会产生重复完成记录。

---

## P0-02：关卡完成后无条件写入本地“已完成”状态

### 涉及文件

- `client/scenes/game/game.gd`
- `client/scripts/storage/progress_store.gd`
- `client/scripts/storage/sync_queue.gd`

### 当前问题

`_finish_level()` 调用 `SyncQueue.submit()` 后，不检查 `result.ok` 或永久拒绝状态，直接执行：

- 显示完成面板。
- `ProgressStore.mark_completed(...)`。
- 预加载下一关。
- 记录 `level_complete` 分析事件。

当前仅使用 `queued` 区分“全部找到了”和“等待同步”。结合 P0-01，永久 4xx 也会被当作已经同步。

### 修改要求

完成流程必须区分三个状态：

#### `synced`

- 标记本地已完成。
- 标记服务端已同步。
- 显示正常完成结果。
- 记录 `level_complete_synced` 或带 `sync_state=synced` 的事件。

#### `queued`

- 允许标记“本地已完成”。
- 单独保存 `sync_state=queued`。
- UI 显示“本地完成，等待同步”。
- 后续重放成功后更新为 `synced`。

#### `rejected`

- 不得显示“已同步完成”。
- 不得把该关卡保存为服务端完成。
- UI 显示明确错误和重试入口。
- 保留玩家本轮找到的差异，避免直接丢失现场。
- 根据错误类型决定重新拉取关卡、重新提交或返回选关页。
- 分析事件不得记录为正常完成，应记录 `level_complete_rejected`。

`ProgressStore` 的完成状态建议拆分为：

```text
playing
local_completed
sync_queued
synced
rejected
```

至少不能只用一个 completed 布尔值表达全部状态。

### 验收标准

- 服务端 422 时客户端不会显示“全部找到了”。
- 离线完成后重启游戏，仍显示本地完成且等待同步。
- 恢复网络并同步成功后，状态切换为 synced。
- 永久拒绝不会被 Analytics 统计为正常服务端完成。

---

## P0-03：刷新 Token 的任意失败都会清空登录状态

### 涉及文件

- `client/scripts/api/api_client.gd`
- `client/scripts/storage/session_store.gd`

### 当前问题

`refresh_session()` 只要请求不成功，就执行 `SessionStore.clear_session()`。

以下临时故障也会导致玩家被强制退出：

- DNS 或网络短暂失败。
- 请求超时。
- API 502、503、504。
- 429 限流。
- 服务端返回非预期 JSON。

### 修改要求

只有能明确证明 refresh token 无效时才清空 Session，例如：

- 400 且错误码明确表示 refresh token 非法或格式错误。
- 401 且错误码表示 token expired、revoked、not found。
- 403 且明确禁止当前 token。

以下情况不得清空 Session：

- `status=0` 网络错误。
- 408。
- 429。
- 5xx。
- 响应解析失败。
- 请求无法启动。

建议返回统一认证状态：

```text
valid
refreshable_failure
invalid_session
```

发生临时失败时：

- 保留现有 access/refresh token。
- 返回可重试错误。
- UI 可以提示网络异常，但不得跳回登录页。

### 验收标准

- 断网时 refresh 失败不会清空 SessionStore。
- 503 时不会退出登录。
- 明确的 invalid refresh token 会清空 Session，并跳转登录页。
- 相关行为有自动化测试。

---

## P0-04：所有 API 请求固定 2 秒超时，缺少按类型配置和重试策略

### 涉及文件

- `client/scripts/api/api_client.gd`
- `client/scripts/cache/asset_cache.gd`
- `client/scenes/home/home.gd`

### 当前问题

`ApiClient` 使用统一的 `REQUEST_TIMEOUT_SECONDS := 2.0`。该值对以下环境过于激进：

- 移动网络。
- 跨地区访问。
- 服务冷启动。
- 弱网和高延迟网络。

同时代码缺少明确的指数退避、抖动和最大重试次数策略。

### 修改要求

按请求类型设置超时：

- 普通 JSON GET：8～10 秒。
- 登录、注册、refresh：8～10 秒。
- 写入请求：8～10 秒。
- 图片下载：15～30 秒。
- 健康检查可保留较短超时。

仅对安全可重试请求执行自动重试：

- GET 请求。
- 带稳定 Idempotency-Key 的写请求。
- 网络错误、408、429、5xx。

禁止对以下请求无条件重试：

- 没有幂等键的写请求。
- 确定性 4xx。

建议策略：

```text
第 1 次：立即
第 2 次：0.5s + jitter
第 3 次：1.5s + jitter
最大 3 次
```

429 应优先读取 `Retry-After`。

### 验收标准

- 模拟 3～5 秒延迟时普通请求不再直接失败。
- GET 遇到一次 503 后可自动恢复。
- 幂等写请求重试不会产生重复数据。
- 确定性 422 不重试。

---

## P0-05：Bootstrap 是伪加载流程，错误和离线入口实际不可用

### 涉及文件

- `client/scenes/bootstrap/bootstrap.gd`
- `client/README.md`
- `client/scripts/api/api_client.gd`
- `client/scripts/storage/session_store.gd`

### 当前问题

当前 Bootstrap：

- 只通过多个 timer 修改进度条。
- 没有调用 `ApiClient`。
- `_show_error()` 没有实际触发路径。
- 文案写“继续离线游戏”，但按钮最终仍进入登录场景。
- `client/README.md` 描述会创建 installation ID、调用匿名会话和 bootstrap，但当前代码没有执行这些步骤。

### 修改要求

Bootstrap 必须成为真实启动协调器，至少负责：

1. 初始化本地配置与 installation ID。
2. 加载现有 Session。
3. 检查 Session 是否仍可使用，必要时刷新。
4. 拉取 bootstrap 或启动所需配置。
5. 触发同步队列重放。
6. 根据实际状态进入登录页或首页。
7. 出错时展示真实错误和有效重试入口。

当前产品是否采用匿名登录，需要统一实现与文档。AI 不得继续保留以下混合状态：

- README 说匿名启动。
- 代码强制账号登录。
- Bootstrap 又声称可以离线进入。

如果暂时保留“必须登录”策略，则：

- 删除匿名启动和离线继续的错误文案。
- Bootstrap 成功后，有有效 Session 进入首页，无 Session 进入登录页。

如果项目已有明确匿名身份协议，则：

- 实现匿名 Session。
- 登录仅用于账号绑定和跨设备同步。

在没有用户进一步确认产品策略前，优先采用最小风险方案：**保持现有账号登录策略，但修复 Bootstrap 的真实请求、Session 恢复、错误处理和文档说明，不自行新增匿名账号协议。**

### 验收标准

- 启动时不再只是固定 timer 动画。
- 有有效 Session 时不经过登录页，直接进入首页。
- 无 Session 时进入登录页。
- 网络错误能够展示重试按钮。
- 不再出现“继续离线游戏”却跳到登录页的行为。
- README 与实际流程一致。

---

## P0-06：窗口尺寸变化后只重置右图，双图视口可能失去同步

### 涉及文件

- `client/scenes/game/game.gd`
- `client/scripts/game/spot_image.gd`

### 当前问题

`_apply_responsive_layout()` 在尺寸变化后仅执行：

```gdscript
target_panel.configure_fit_view()
```

`base_panel` 没有同步应用新的 zoom 和 offset。玩家先缩放或拖动，再调整窗口、旋转设备或进入分屏时，两张图可能产生不同视口。

### 修改要求

尺寸变化时必须由父控制器计算一次统一 ViewState，并同时应用到两张图。

建议：

```gdscript
var view := target_panel.calculate_fit_view()
base_panel.set_view(view.zoom, view.offset)
target_panel.set_view(view.zoom, view.offset)
_save_view(view.zoom, view.offset)
```

或者在调用 `configure_fit_view()` 后读取实际状态并显式同步到另一图。

要求：

- 不依赖 `view_changed` 信号是否在程序化设置时触发。
- 避免两个 panel 的信号互相递归。
- 横屏、竖屏、窗口缩放均使用相同逻辑。

### 验收标准

- 玩家缩放并拖动后改变窗口尺寸，两图仍完全对齐。
- 横竖屏切换后两图 zoom 和 offset 相同。
- 不出现无限信号循环。
- 恢复保存的 ViewState 后仍保持同步。

---

# 4. P1：MVP 发布前应完成的问题

## P1-01：首页启动请求完全串行

### 涉及文件

- `client/scenes/home/home.gd`

### 当前问题

首页 `_ready()` 顺序等待：

1. `refresh_user_profile()`
2. `_refresh_series()`
3. `_refresh_identity()`
4. `_refresh_sync()`

用户资料请求失败或延迟，会阻塞核心 Catalog 展示。头像下载也可能继续拖慢完整页面可用时间。

### 修改要求

- Catalog 是首页核心数据，优先加载。
- 用户资料、Catalog、同步队列应并行启动。
- 身份区域先显示 SessionStore 本地缓存，再异步更新。
- Catalog 有缓存时先渲染缓存，再后台刷新。
- 单个非关键请求失败不能阻止首页其他区域显示。

### 验收标准

- 用户资料接口 5 秒延迟时，Catalog 仍能先显示。
- 头像下载失败不影响系列卡片。
- 同步失败只更新 Footer 状态，不阻塞首页。

---

## P1-02：首页存在明显 N+1 请求和重复图片下载

### 涉及文件

- `client/scenes/home/home.gd`
- `client/scripts/cache/asset_cache.gd`
- 服务端 Catalog DTO 和对应 handler

### 当前问题

每个系列卡片可能执行：

1. 下载 `thumbnail_url`。
2. 请求该系列第一个完整关卡。
3. 再下载完整关卡图片覆盖缩略图。

系列越多，请求数线性增加，还会下载本不应在首页加载的完整图片。

### 修改要求

Catalog 中应直接提供可用于首页的系列封面资源，例如：

```json
{
  "cover_asset": {
    "url": "...",
    "width": 720,
    "height": 480,
    "sha256": "...",
    "variant": "series_cover"
  }
}
```

首页：

- 只加载 cover/thumbnail。
- 不调用 `get_level()` 获取完整关卡。
- 不下载完整游戏图片覆盖封面。
- 图片统一通过 AssetCache。

### 验收标准

假设首页有 10 个系列：

- 只产生 1 个 Catalog 请求。
- 每个系列最多 1 个封面资源请求，缓存命中时为 0。
- 不产生 10 个额外关卡详情请求。
- 不下载完整关卡图片。

---

## P1-03：Catalog 被多处重复拉取，缺少统一 Repository

### 涉及文件

- `client/scripts/game/level_loader.gd`
- `client/scenes/home/home.gd`
- `client/scenes/level_select/level_select.gd`
- 建议新增：`client/scripts/catalog/catalog_repository.gd`

### 当前问题

以下操作都会重新请求完整 Catalog：

- 首页刷新。
- 选择下一关。
- 预加载下一关。
- 打开每日任务。
- 可能还有选关页加载。

`select_next_level()` 和 `prefetch_next_level()` 在同一关卡流程中还可能各请求一次 Catalog。

### 修改要求

新增统一的 `CatalogRepository`，负责：

- 内存缓存。
- 磁盘缓存。
- 缓存版本。
- 过期策略。
- 强制刷新。
- 并发请求合并，避免同时发出多个相同请求。

建议接口：

```gdscript
get_catalog(force_refresh := false)
get_series(series_id)
get_next_level(series_id, current_level_id)
get_cached_catalog()
clear_cache()
```

如果服务端已有 `catalog_version`、ETag 或配置版本，应使用条件请求；否则至少设置合理 TTL。

### 验收标准

- 同一页面周期内多个调用只产生一个 Catalog 网络请求。
- 下一关和预加载共用同一 Catalog 数据。
- 离线时可以读取最近一次有效 Catalog 缓存。
- Catalog 版本变化后能刷新。

---

## P1-04：客户端关卡协议校验过浅

### 涉及文件

- `client/scripts/game/level_loader.gd`
- `contracts/level.schema.json` 或实际关卡 Schema 文件
- 建议新增：`client/scripts/game/level_validator.gd`

### 当前问题

当前 `_validate()` 主要检查：

- `schema_version == 1`
- mode 是否受支持
- differences 数量在 3～12

缺少对运行时关键字段的验证。

### 修改要求

新增独立 `LevelValidator`，至少检查：

#### 基础字段

- `level_id` 非空。
- `schema_version` 支持。
- `mode` 合法。
- `width/height` 为正数并在合理上限内。

#### Assets

- 对应 mode 所需图片字段存在。
- URL 非空且协议合法。
- width、height 合法。
- hash 格式合法。
- 资源类型受支持。

#### Differences

- 数量合法。
- ID 非空且唯一。
- shape 类型受支持。
- circle 坐标、半径合法。
- polygon 至少三个点。
- 所有归一化坐标在允许范围内。
- 不能包含 NaN、Infinity 或错误类型。

#### 文本字段

- title、instruction 等字段缺失时有安全默认值。
- 超长文本需限制，防止破坏 UI。

验证逻辑应尽量与 `contracts` 样例共享测试数据，避免客户端、服务端和 Schema 各自漂移。

### 验收标准

- 合法样例全部通过。
- contracts 中非法样例全部被拒绝。
- 重复 difference ID 被拒绝。
- 越界 circle/polygon 被拒绝。
- 缺少必要 asset 时不会进入 Game 场景后才崩溃。

---

## P1-05：离线能力的产品文案、数据能力和实现不一致

### 涉及文件

- `client/scenes/bootstrap/bootstrap.gd`
- `client/README.md`
- `client/scripts/cache/asset_cache.gd`
- `client/scripts/game/level_loader.gd`

### 当前问题

仓库说明强调：

- 关卡目录、关卡数据和图片全部从服务端读取。
- 客户端不内置备用关卡。

但 Bootstrap 又提示“仍然可以继续本地游戏”。若设备从未成功下载过关卡，实际上没有可玩的离线内容。

### 修改要求

明确区分两种情况：

1. **有缓存关卡**：允许离线继续，并显示当前可用的缓存关卡。
2. **无缓存关卡**：不能声称可离线游戏，应提示需要联网完成首次加载。

必须定义最小离线缓存：

- Catalog 最近有效版本。
- 已进入或主动下载的关卡 JSON。
- 对应图片资源。
- 本地进度和同步队列。

不要求本次增加“批量下载全部关卡”，但文案必须与实际缓存能力匹配。

### 验收标准

- 首次安装断网时不会显示虚假的离线继续入口。
- 已缓存至少一个关卡时断网可以进入该关卡。
- 缓存不完整时给出明确提示，不进入半加载状态。

---

## P1-06：图片下载逻辑重复，部分路径绕过 AssetCache

### 涉及文件

- `client/scenes/home/home.gd`
- `client/scripts/cache/asset_cache.gd`
- 其他直接创建 `HTTPRequest` 下载图片的场景

### 当前问题

首页 `_download_texture()` 自己实现 HTTP 下载和图片解码，而完整关卡图片走 `AssetCache`。这会造成：

- 缩略图和头像无法统一命中磁盘缓存。
- 超时策略不同。
- hash 校验策略可能不同。
- 错误处理和资源上限不同。
- 重复代码持续增加。

### 修改要求

所有远程图片统一通过 AssetCache 或统一的 AssetRepository。

AssetCache 应支持：

- URL-only 资源。
- 带 hash 的强校验资源。
- 缩略图、头像、关卡图不同 variant。
- 内存和磁盘缓存。
- 最大文件尺寸。
- Content-Type 校验。
- 解码失败处理。
- 并发相同 URL 请求合并。

### 验收标准

- `home.gd` 不再自己创建图片 HTTPRequest。
- 相同 URL 在同一时间只下载一次。
- 第二次进入首页可以命中缓存。
- 非图片响应不会尝试当图片解码。

---

## P1-07：每日提示日期每次使用时请求 Bootstrap，失败时默认日期不可靠

### 涉及文件

- `client/scenes/game/game.gd`

### 当前问题

每次使用提示都调用 `ApiClient.get_business_date()`，该函数再次调用 bootstrap。请求失败时回退到本地保存的 `last_business_date`，首次失败默认使用 `1970-01-01`。

可能出现：

- 点击提示前产生额外网络延迟。
- 离线多天一直使用同一个旧日期，免费次数不按日重置。
- 首次离线使用固定的 `1970-01-01`。
- Bootstrap 被当作频繁业务接口调用。

### 修改要求

- 启动或首页阶段获取并缓存 business date。
- Game 场景直接使用启动上下文，不要每次点击提示都请求 bootstrap。
- 在 app resume 或跨日时再刷新日期。
- 离线日期策略必须明确：使用最后一次服务端日期加本地经过时间推导，或保持旧日但清楚记录；不得默认 `1970-01-01`。
- 如果免费提示属于防作弊资源，最终额度应由服务端确认；本次至少修复客户端日期与网络调用问题。

### 验收标准

- 点击提示不会临时请求 bootstrap。
- 首次离线不会使用 1970-01-01。
- 跨日后能刷新额度。
- 连续离线时行为可预测且有测试。

---

## P1-08：核心客户端文件职责过多，状态逻辑难以测试

### 涉及文件

- `client/scripts/api/api_client.gd`
- `client/scenes/game/game.gd`
- `client/scenes/home/home.gd`

### 当前问题

这些文件同时承担多种职责：

#### `api_client.gd`

- Odd Spot API。
- 用户中心 API。
- 登录注册。
- Token exchange 和 refresh。
- 请求序列化。
- 错误转换。
- 重试和鉴权逻辑。

#### `game.gd`

- 关卡加载。
- 游戏状态。
- 输入和命中。
- 双图视口同步。
- 提示额度。
- 本地进度。
- 服务端同步。
- 完成弹窗。
- 响应式布局。
- Analytics。

这使关键逻辑只能通过完整场景间接测试。

### 修改要求

不进行大规模重写，但应最小拆分：

```text
client/scripts/api/
  http_client.gd
  oddspot_api.gd
  user_api.gd
  auth_service.gd

client/scripts/game/
  level_validator.gd
  attempt_controller.gd
  view_sync_controller.gd
  hint_service.gd
  completion_service.gd
```

场景脚本只负责绑定 UI 和调用服务。

### 验收标准

- Token refresh 可脱离场景单测。
- SyncQueue 可注入假的 API transport。
- 关卡完成状态机可单测。
- ViewState 同步可单测。
- 不改变现有场景路径和用户可见功能。

---

## P1-09：服务端 `httpapi/router.go` 责任集中

### 涉及文件

- `server/internal/httpapi/router.go`
- `server/internal/httpapi/router_test.go`

### 当前问题

HTTP 层将路由注册、中间件、玩家接口、Admin 接口、资源上传、错误映射、健康检查等集中在同一文件。继续增加接口会提高冲突和误改风险。

### 修改要求

保持模块化单体，不拆微服务。仅按 HTTP 职责拆文件：

```text
server/internal/httpapi/
  router.go
  middleware/
    auth.go
    admin_auth.go
    request_id.go
    cors.go
  handlers/
    bootstrap.go
    catalog.go
    level.go
    session.go
    account.go
    monetization.go
    analytics.go
    reports.go
    admin_content.go
    admin_assets.go
  response/
    envelope.go
    errors.go
```

要求：

- 路由路径和响应格式保持兼容。
- 现有测试全部继续通过。
- 公共鉴权和错误映射不能复制到每个 handler。

### 验收标准

- `router.go` 主要只负责依赖组装和路由注册。
- handler 按业务域拆分。
- API 行为无变化。
- Go 单元测试和集成测试全部通过。

---

## P1-10：客户端测试基本只验证场景能实例化

### 涉及文件

- `client/tests/run_smoke.gd`
- 建议新增多个测试文件
- `scripts/test-all.ps1` 及 Linux 对应脚本

### 当前问题

当前 smoke test 主要验证场景可以 load、instantiate、free，无法发现：

- 同步永久失败误报成功。
- Token 临时失败清空 Session。
- 双图缩放失去同步。
- 关卡坐标和 shape 非法。
- Catalog 重复请求。
- 离线完成恢复。

### 修改要求

至少新增：

```text
client/tests/test_sync_queue.gd
client/tests/test_session_refresh.gd
client/tests/test_level_validator.gd
client/tests/test_hit_detection.gd
client/tests/test_view_sync.gd
client/tests/test_progress_restore.gd
client/tests/test_catalog_repository.gd
client/tests/test_bootstrap_flow.gd
```

必须支持注入假的 HTTP transport，不能依赖真实生产 API。

关键测试矩阵：

| 模块 | 必测场景 |
|---|---|
| SyncQueue | 2xx、断网、401、408、429、422、500、重放、幂等 |
| Session | refresh 成功、网络失败、503、invalid token |
| LevelValidator | 合法样例、非法 shape、重复 ID、越界坐标、缺 asset |
| View Sync | 拖动、缩放、resize、横竖屏、恢复状态 |
| Progress | 退出重进、本地完成、等待同步、永久拒绝 |
| Catalog | 内存命中、磁盘命中、并发合并、版本刷新、离线 |
| Bootstrap | 有 Session、无 Session、refresh 临时失败、配置失败 |

### 验收标准

- 每个 P0 问题至少有一个失败前可复现、修复后通过的测试。
- 测试不请求线上域名。
- Windows 和 Linux headless 环境可运行。

---

# 5. P2：工程质量和仓库治理

## P2-01：缺少持续集成工作流

### 涉及文件

建议新增：

- `.github/workflows/ci.yml`

### 修改要求

CI 至少执行：

1. `go test ./...`
2. `go vet ./...`
3. MySQL 之外的服务端单元测试。
4. Godot headless smoke 和新增客户端测试。
5. contracts Schema 合法/非法样例校验。
6. 检查仓库中是否意外提交常见密钥格式。

MySQL 集成测试可以独立 job，通过 GitHub Actions service container 启动 MySQL，或先保留为可选手工 job。

### 验收标准

- PR 和 master push 自动运行。
- 任意 Go 测试或 Godot 测试失败都会阻止 CI 通过。
- CI 不依赖生产数据库和生产 API。

---

## P2-02：README、设计文档和当前实现存在漂移

### 涉及文件

- `README.md`
- `client/README.md`
- `server/README.md`
- `docs/ai_spot_difference_solution/` 下相关文档

### 当前问题

已确认至少存在以下冲突：

- 客户端 README 描述匿名会话启动，但代码当前要求登录。
- Bootstrap 声称可离线继续，但实际跳转登录页。
- README 描述 Bootstrap 负责真实 API 初始化，但实际只是 timer。

### 修改要求

代码修改完成后，文档必须准确描述：

- 当前认证模式。
- 启动流程。
- 离线能力边界。
- SyncQueue 的 synced、queued、rejected 语义。
- Catalog 和资源缓存策略。
- 本地测试和 CI 命令。

禁止保留“计划实现”内容并写成“已经实现”。未实现能力必须标记为 TODO 或规划。

### 验收标准

- 新开发者只阅读 README，可以正确启动客户端和服务端。
- README 描述的页面跳转与实际一致。
- 离线说明不夸大。

---

## P2-03：缺少基础开源仓库治理文件

### 建议新增

- `LICENSE`
- `SECURITY.md`
- `CONTRIBUTING.md`

### 说明

这是公开仓库。是否允许第三方使用和贡献需要明确。如果该仓库只用于公开展示、不允许复用，也应选择符合实际目标的 License 或在 README 中明确版权策略。

该项不影响运行，可最后处理。

---

# 6. 统一错误模型建议

客户端目前多个模块自行返回不同结构，建议在不改变服务端 API 的前提下，先统一客户端内部结果模型：

```gdscript
{
    "ok": false,
    "category": "network", # success | network | auth | retryable | rejected | invalid_data
    "status": 0,
    "error_code": "NETWORK_TIMEOUT",
    "message": "",
    "data": {},
    "retryable": true
}
```

同步队列额外返回：

```gdscript
{
    "sync_state": "queued" # synced | queued | rejected
}
```

推荐分类：

| 条件 | category | retryable |
|---|---|---:|
| 2xx | success | false |
| 请求无法启动、DNS、断网、超时 | network | true |
| 401 且 refresh 可用 | auth | true |
| refresh token 明确无效 | auth | false |
| 408、429、5xx | retryable | true |
| 其他确定性 4xx | rejected | false |
| JSON/关卡协议非法 | invalid_data | 视情况 |

所有 UI、SyncQueue、Bootstrap、Analytics 都应使用同一错误分类，不再各自猜测 status。

---

# 7. 推荐实施顺序

## 第一批：状态正确性

- [ ] P0-01 同步队列三态结果。
- [ ] P0-02 完成状态机和 ProgressStore 状态拆分。
- [ ] P0-03 refresh 临时失败不清 Session。
- [ ] P0-04 超时和重试策略。
- [ ] 为以上问题补测试。

## 第二批：启动和游戏视图

- [ ] P0-05 真实 Bootstrap。
- [ ] P0-06 双图 resize 同步。
- [ ] P1-05 离线能力和文案一致。
- [ ] P1-07 business date 缓存。
- [ ] 补 Bootstrap、离线、ViewState 测试。

## 第三批：首页和数据层

- [ ] P1-01 首页请求并行。
- [ ] P1-02 移除首页 N+1。
- [ ] P1-03 CatalogRepository。
- [ ] P1-06 统一图片缓存。
- [ ] 补缓存和并发请求测试。

## 第四批：协议和代码组织

- [ ] P1-04 LevelValidator。
- [ ] P1-08 客户端最小职责拆分。
- [ ] P1-09 服务端 HTTP 文件拆分。
- [ ] P1-10 完整客户端测试集。

## 第五批：工程治理

- [ ] P2-01 CI。
- [ ] P2-02 文档同步。
- [ ] P2-03 仓库治理文件。

---

# 8. 完成定义（Definition of Done）

本次改造只有同时满足以下条件才算完成：

1. 所有 P0 已修复。
2. P0 和 P1 均有自动化测试。
3. `go test ./...` 通过。
4. `go vet ./...` 通过。
5. Godot headless 测试通过。
6. 不连接生产 API 也能完成自动化测试。
7. 客户端支持 synced、queued、rejected 三种同步结果。
8. 临时网络错误不会清空登录状态。
9. 服务端永久拒绝不会显示为正常完成。
10. 横竖屏和窗口 resize 后双图仍同步。
11. 首页不存在按系列请求完整关卡的 N+1 行为。
12. Catalog 有统一缓存入口。
13. README 与实际认证、启动、离线和同步流程一致。
14. 未实现“真实内容运营闭环”，且没有无关改动 generation/content-tools。

---

# 9. 可直接交给代码 AI 的执行指令

请基于本仓库当前代码，严格按照本文件从 P0 到 P2 依次修改。

执行要求：

- 先阅读相关代码和现有测试，再修改。
- 每完成一个问题，补对应自动化测试。
- 不实现本文件明确排除的真实 AI 内容生产和运营闭环。
- 不删除现有幂等、离线队列、MySQL 持久化或部署能力。
- 不改变现有 API 路径和响应结构，除非为了兼容新增字段；新增字段必须向后兼容。
- 对不确定的产品逻辑，不要自行扩大范围；优先保持当前账号登录策略并修复实现与文档的一致性。
- 最终输出：修改文件清单、每项问题的解决方式、测试结果、仍未完成的项目和风险。
