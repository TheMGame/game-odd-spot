# 4. API 与数据

> 当前客户端说明：服务端保留以下完整会话 API，但 Godot 默认使用账号服务登录后调用 `POST /v1/sessions/user-server`，不会在 Bootstrap 中调用匿名会话接口。

## 4.1 主要 API

- `POST /v1/sessions/anonymous`：服务端兼容的匿名用户与设备会话；当前 Godot 客户端不主动调用。
- `POST /v1/sessions/user-server`：将账号服务 token 交换为当前客户端使用的游戏 Session。
- `POST /v1/sessions/refresh`：单次使用 refresh token，轮换 access/refresh token。
- `POST /v1/sessions/logout`：撤销当前会话；重复调用仍视为成功。
- `GET /v1/bootstrap`：市场、语言、版本、功能开关、广告参数、配置版本。
- `GET /v1/home`：首页模块和推荐内容。
- `GET /v1/levels/{id}`：关卡协议与签名资源 URL。
- `POST /v1/levels/{id}/start`：开始关卡。
- `POST /v1/levels/{id}/progress`：增量进度，可选。
- `POST /v1/levels/{id}/complete`：结算，服务端校验基本合理性。
- `POST /v1/rewards/ad`：领取激励广告奖励，必须幂等。
- `POST /v1/purchases/verify`：验证交易并更新权益。
- `POST /v1/events/batch`：批量埋点。
- `GET /v1/config/{version}`：配置增量或完整快照。

## 4.2 API 通用要求

- 所有写请求支持 `Idempotency-Key`。
- 响应包含 request_id、server_time、config_version。
- 错误使用稳定 error_code，不以错误文案作为客户端逻辑判断。
- 资源协议带 schema_version；客户端至少兼容当前和前一版本。
- 列表 API 使用 cursor 分页。
- 用户标识、设备标识和广告标识分离。
- 认证使用短期 Bearer access token 和可轮换 refresh token；管理 API 使用独立身份、角色权限和审计日志。
- 幂等键作用域、冲突与响应重放规则见 `07_state_machines_and_quality.md`。
- 精确请求/响应结构以 `schemas/api.openapi.yaml` 为准。

## 4.3 进度与资源契约

- start 创建 `attempt_id` 并绑定不可变 `level_version`。
- progress 上传找到的 difference_id 增量；服务端按主键合并，不相信客户端 found_count。
- complete 上传完整 difference_id 集合、耗时和提示数；服务端对版本、差异全集、状态和异常耗时做校验。
- 关卡详情返回结构化 asset 对象。客户端以 `asset_id + sha256` 缓存，签名 URL 过期时重新请求详情。
- published 关卡版本不可原地覆盖；修复内容必须创建新版本。

## 4.4 推荐打分

MVP 使用可解释规则：地区匹配 + 语言匹配 + 主题偏好 + 活动权重 + 新鲜度 + 质量分 - 已玩惩罚 - 负反馈。需保留每次推荐的 reason 字段，便于调试和 A/B 分析。

## 4.5 事件规范

关键事件：app_open、bootstrap_result、home_impression、theme_click、level_download、level_start、difference_found、wrong_tap、hint_request、rewarded_ad_result、level_complete、level_quit、purchase_start、purchase_result、content_report、crash。

事件必须包含 event_id、user_id、session_id、market、locale、app_version、occurred_at、payload。客户端离线暂存后批量上报；服务端按 event_id 去重。

## 4.6 防作弊与合理性校验

休闲游戏不需要重型反作弊，但需防止无限奖励：广告凭证/回调校验、交易唯一性、每日领取上限、完成时间异常、一次请求完成多个不可能状态、客户端时钟不可信。对异常用户降权或冻结奖励，不要影响普通玩家。

## 4.7 错误与缓存

稳定错误码至少包括 `UNAUTHENTICATED`、`FORBIDDEN`、`VALIDATION_FAILED`、`LEVEL_NOT_FOUND`、`LEVEL_VERSION_MISMATCH`、`INVALID_STATE`、`IDEMPOTENCY_CONFLICT`、`REQUEST_IN_PROGRESS`、`REWARD_NOT_VERIFIED` 和 `PURCHASE_INVALID`。

bootstrap 支持 ETag/If-None-Match；客户端只在完整验证新配置后替换最后可用快照。home cursor 为服务端签名的不透明字符串。关卡详情可以缓存，但签名 URL 的过期时间不得被当成关卡版本有效期。

当前客户端已实现 Catalog 内存/磁盘缓存和图片磁盘缓存；关卡 JSON 的完整离线缓存仍是待办。首次安装没有缓存时必须联网，不能承诺离线进入游戏。
