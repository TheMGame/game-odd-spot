# game-odd-spot 多语言改造方案

> 适用仓库：`TheMGame/game-odd-spot`
>
> 基于分支：`master`
>
> 更新日期：2026-07-28

---

## 1. 改造目标

本次只支持多语言。

需要支持：

- 简体中文 `zh-CN`：安装包内置；
- 英文 `en-US`：安装包内置；
- 其他语言：远程语言包按需下载。

其他语言不随首包发布。满足以下任一条件时下载：

1. Web 根据 IP 判断用户对应某个已发布语言；
2. 用户在设置页主动选择该语言。

多语言覆盖：

1. Godot 客户端 UI 文案；
2. 系列标题和描述；
3. 关卡标题；
4. 错误提示和动态状态文案；
5. 运行时切换语言；
6. 本地语言选择持久化；
7. 设置页允许用户选择所有已发布语言；
8. Web 首次启动时根据用户 IP 选择默认语言；
9. 非内置语言按需下载、校验、缓存和更新；
10. Catalog 按 Locale 返回本地化内容。

---

## 2. 不在本次范围内

- 不新增 `/v1/preferences`；
- 不修改 AI 关卡生成、审核和内容生产流水线；
- 不实现图片内文字翻译；
- 不实现货币、价格和支付本地化。

---

## 3. Locale 规范

API、数据库和客户端本地设置统一保存 BCP 47：

```text
zh-CN
en-US
```

禁止把以下值作为不同 Locale：

```text
en-US
en_US
en
```

客户端可以接受系统返回的不同格式，但在保存或发送 API 前必须标准化。

建议服务端和客户端都提供公共标准化函数：

```text
zh / zh_CN / zh-Hans / zh-Hans-CN => zh-CN
en / en_US                         => en-US
其他                               => en-US
```

内置 Locale：

```text
zh-CN
en-US
```

其他 Locale 是否可用，以服务端语言清单为准，不在客户端代码中写死。

### 3.1 内置语言与远程语言包

内置语言：

- 无网络也能使用；
- 不需要下载；
- 不允许被远程包删除；
- 可随客户端版本更新。

远程语言：

- 由服务端语言清单发布；
- 首次需要时下载；
- 下载成功后缓存在本地；
- 后续按版本更新；
- 下载失败时继续使用当前语言或回退到 `en-US`；
- 不能阻塞登录和进入游戏。

远程语言包只包含客户端 UI 翻译资源。Series 和 Level 等服务端内容文案仍由 Catalog API 根据 Locale 返回。

建议使用 Godot 可运行时加载的语言资源包，例如经过发布流程生成并签名的 `.pck`。不要直接执行从网络下载的脚本。

---

## 4. Locale 来源与优先级

语言优先级：

```text
客户端本地保存的手动选择
    >
登录或 Session 请求提交的 Locale
    >
Web 服务端 IP 推断
    >
系统 Locale
    >
部署默认 Locale
    >
en-US
```

玩家手动选择语言后，不再用系统 Locale 自动覆盖。

本次不要求把 Locale 写入用户资料。服务端可以从当前 Session 获取 Locale；客户端同时在本地保存语言，以便启动时立即显示正确 UI。

### 4.1 Web IP 默认语言

Web 用户首次启动且本地没有手动语言选择时，由服务端根据客户端 IP 推断默认语言：

```text
中国大陆 IP => zh-CN
其他 IP     => 查询语言清单中的 country_codes 映射
无对应语言  => en-US
无法识别 IP => 浏览器/系统 Locale
仍无法识别  => en-US
```

IP 只用于选择默认语言，不用于筛选内容。

安全要求：

- 客户端不直接提交 IP；
- 服务端从请求连接获取 IP；
- 经过 CDN 或反向代理时，只读取部署配置中可信代理提供的真实 IP Header；
- 不信任任意客户端传入的 `X-Forwarded-For`；
- GeoIP 查询失败不能阻止游戏启动；
- IP 推断只在没有本地手动选择时生效；
- 用户在设置页选择语言后，IP 不得再次覆盖。
- IP 命中远程语言时，客户端在启动阶段尝试下载对应语言包；
- 下载失败时使用 `en-US` 继续启动，并允许用户稍后重试。

建议增加公开接口：

```http
GET /v1/locale/default
```

响应：

```json
{
  "data": {
    "locale": "fr-FR",
    "source": "geoip",
    "requires_download": true
  }
}
```

该接口无需登录，仅返回支持列表中的 Locale，不返回 IP、国家或其他定位信息。

### 4.2 语言清单

新增：

```http
GET /v1/locales
```

示例：

```json
{
  "data": {
    "default_locale": "en-US",
    "locales": [
      {
        "locale": "zh-CN",
        "display_name": "简体中文",
        "native_name": "简体中文",
        "builtin": true,
        "version": 1,
        "country_codes": ["CN"]
      },
      {
        "locale": "en-US",
        "display_name": "English",
        "native_name": "English",
        "builtin": true,
        "version": 1,
        "country_codes": []
      },
      {
        "locale": "fr-FR",
        "display_name": "French",
        "native_name": "Français",
        "builtin": false,
        "version": 3,
        "country_codes": ["FR"],
        "download_url": "https://cdn.example.com/i18n/fr-FR-v3.pck",
        "sha256": "...",
        "size_bytes": 123456,
        "resource_path": "res://i18n/fr_FR.translation"
      }
    ]
  }
}
```

规则：

- 设置页列表来自该接口；
- 非内置语言必须提供版本、下载地址、SHA-256、大小和包内 Translation 资源路径；
- `country_codes` 用于 IP 国家到默认语言的映射；
- 服务端只返回已经发布并启用的语言；
- 下载地址使用 HTTPS；
- 客户端必须校验文件大小和 SHA-256；
- 清单和语言包应支持 CDN 缓存。

---

## 5. Session Locale

当前服务端已经可以在 Session 创建时接收 Locale，并通过 Profile 返回 Locale。本次继续沿用这个体系。

Session Profile 中保留：

```go
type Profile struct {
    UserID string
    Locale string
}
```

Memory Session Service 必须保存真实 Locale，不能固定返回 `en`。

### 5.1 创建 Session

客户端提交：

```json
{
  "locale": "zh-CN"
}
```

服务端：

1. 标准化 Locale；
2. 验证是否为内置语言或语言清单中已发布的语言；
3. 保存到当前 Session；
4. 响应返回最终 Locale。

### 5.2 切换语言

新增仅更新当前 Session Locale 的接口：

```http
PUT /v1/session/locale
Authorization: Bearer <token>
Content-Type: application/json
```

请求：

```json
{
  "locale": "en-US"
}
```

响应：

```json
{
  "data": {
    "locale": "en-US"
  }
}
```

错误码：

```text
422 LOCALE_NOT_SUPPORTED
401 UNAUTHORIZED
```

更新语言不需要旋转 Access Token 或 Refresh Token。

Refresh Token 刷新后必须继承原 Session Locale。

---

## 6. 内容翻译数据模型

保留现有原始字段作为最终回退：

```text
content_series.title
content_series.description
level_versions.runtime_json.title
```

不删除旧字段，不复制 Series 或 Level。

### 6.1 Series 翻译

新增迁移：

```text
server/internal/database/migrations/016_i18n.sql
```

新增表：

```sql
CREATE TABLE IF NOT EXISTS content_series_i18n (
  series_id VARCHAR(64) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  description VARCHAR(500) NOT NULL DEFAULT '',
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (series_id, locale),
  CONSTRAINT fk_series_i18n_series
    FOREIGN KEY (series_id) REFERENCES content_series(id)
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

### 6.2 Level 标题翻译

新增：

```sql
CREATE TABLE IF NOT EXISTS content_level_i18n (
  level_id VARCHAR(64) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (level_id, locale),
  CONSTRAINT fk_level_i18n_level
    FOREIGN KEY (level_id) REFERENCES levels(id)
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

标题按 `level_id + locale` 保存，不绑定 Version。运行时关卡版本更新后不需要重复维护标题翻译。

### 6.3 现有数据

现有原始文案继续作为 legacy fallback。

如果已经人工确认现有 Series 文案全部为简体中文，可以回填：

```sql
INSERT IGNORE INTO content_series_i18n(
  series_id,
  locale,
  title,
  description
)
SELECT
  id,
  'zh-CN',
  title,
  description
FROM content_series;
```

不要把现有文案复制到所有 Locale，否则无法区分真实翻译和占位文案。

Level 标题是否回填 `zh-CN` 也必须先确认现有内容语言。

---

## 7. 内容文案回退规则

Series 和 Level 严格按以下顺序读取：

```text
1. 当前 Session 的精确 Locale
2. 部署默认 Locale
3. en-US
4. 原始 title/description 或 runtime_json.title
5. ID
```

示例：

```text
Session Locale = zh-CN
部署默认 Locale = zh-CN
```

Series 标题读取顺序：

```text
content_series_i18n.zh-CN
    >
content_series_i18n.en-US
    >
content_series.title
    >
series_id
```

不要用数据库顺序随机匹配 `zh-*`、`en-*` 等语言前缀。

---

## 8. Catalog 改造

Catalog 的内容范围和排序保持不变，只增加本地化文案。

修改：

```go
Public(context.Context, userID string)
```

为：

```go
type PublicQuery struct {
    UserID string
    Locale string
}

Public(context.Context, PublicQuery) ([]Series, error)
```

`GET /v1/catalog`：

```text
鉴权获得 userID
    -> Session Profile 获得 Locale
    -> Catalog.Public(PublicQuery)
    -> 返回本地化 Series 和 Level 标题
```

响应增加 Locale：

```json
{
  "data": {
    "locale": "zh-CN",
    "series": []
  }
}
```

客户端不能通过：

```text
GET /v1/catalog?locale=...
```

临时绕过当前 Session Locale。切换语言应先更新 Session Locale。

### 8.1 查询性能

翻译必须批量读取。

禁止：

- 每个 Series 查询一次翻译；
- 每个 Level 查询一次翻译。

推荐：

```text
一次查询 Series
一次批量查询 Series 翻译
一次批量查询所有 Series 的 Levels
一次批量查询 Level 翻译
一次批量查询完成状态
Go 层组装
```

当前 Catalog 已存在每个 Series 查询 Levels 的 N+1。本次至少不能再增加翻译 N+1；条件允许时一起消除原有 N+1。

---

## 9. Bootstrap

`GET /v1/bootstrap` 继续返回：

```json
{
  "data": {
    "locale": "en-US",
    "supported_locales": [
      "zh-CN",
      "en-US",
      "fr-FR"
    ]
  }
}
```

客户端使用服务端返回的 Locale 校准本地状态。

`supported_locales` 来自当前已发布语言清单。客户端不能因为某个 Locale 不在安装包内就判定它不受支持。

---

## 10. Godot 客户端国际化

涉及：

```text
client/project.godot
client/i18n/
client/scripts/storage/preferences.gd
client/scripts/api/api_client.gd
client/scenes/bootstrap/
client/scenes/home/
client/scenes/level_select/
client/scenes/game/
client/scenes/login/
client/scenes/settings/
```

### 10.1 内置翻译文件

新增：

```text
client/i18n/zh_CN.po
client/i18n/en_US.po
```

注册到：

```text
Project Settings
  -> Localization
  -> Translations
```

只有中文和英文注册为安装包内置翻译。

### 10.2 远程语言包管理器

新增 Autoload：

```text
LanguagePackManager="*res://scripts/localization/language_pack_manager.gd"
```

职责：

- 获取 `/v1/locales` 语言清单；
- 判断 Locale 是否内置；
- 下载非内置语言包；
- 校验大小和 SHA-256；
- 使用临时文件下载，校验成功后原子替换正式缓存；
- 加载语言资源并注册到 `TranslationServer`；
- 按 Locale 和 Version 缓存；
- 清理失效旧版本；
- 下载失败时保留已有可用版本；
- 发出下载进度、成功和失败信号。

缓存示例：

```text
user://i18n/fr-FR/3/language.pck
user://i18n/fr-FR/3/metadata.json
```

禁止覆盖内置中文和英文资源。

### 10.3 翻译 Key

客户端使用稳定业务 Key：

```text
APP_NAME
COMMON_BACK
COMMON_RETRY
HOME_TITLE
HOME_DAILY
SETTINGS_TITLE
SETTINGS_LANGUAGE
LOGIN_TITLE
LEVEL_COMPLETE
LEVEL_SYNC_PENDING
ERROR_CATALOG_LOAD_FAILED
```

场景：

```gdscript
text = "SETTINGS_TITLE"
```

动态文案：

```gdscript
status_label.text = tr("ERROR_CATALOG_LOAD_FAILED")
```

参数文案：

```gdscript
status_label.text = tr("APP_VERSION").format({
    "version": version
})
```

不要使用中文原文作为业务 Key。

### 10.4 硬编码清理

全仓搜索：

```text
text = "
placeholder_text = "
status_label.text =
_show_catalog_message(
```

所有玩家可见文案必须替换为翻译 Key。

以下内容无需翻译：

- 内部日志；
- API error code；
- Level ID；
- 调试信息。

### 10.5 LocaleManager

新增 Autoload：

```text
LocaleManager="*res://scripts/localization/locale_manager.gd"
```

职责：

- 读取本地 Locale；
- 标准化系统 Locale；
- 调用 `TranslationServer.set_locale()`；
- 保存手动选择；
- 应用 Bootstrap 返回的 Locale；
- 请求 LanguagePackManager 确保远程语言可用；
- 发出语言变化信号。

建议接口：

```gdscript
signal locale_changed(locale: String)

func initialize() -> void
func apply_bootstrap(data: Dictionary) -> void
func set_locale(locale: String) -> void
func current_locale() -> String
func normalize_locale(locale: String) -> String
```

### 10.6 本地设置

扩展：

```text
client/scripts/storage/preferences.gd
```

保存：

```ini
[localization]
locale="en-US"
locale_mode="manual"
locale_pack_version=0
```

`locale_mode`：

```text
automatic | manual
```

- automatic：跟随系统 Locale；
- manual：使用玩家选择。

### 10.7 启动顺序

Web 首次启动：

```text
读取本地 Preferences
    -> 本地存在手动 Locale：立即使用该 Locale
    -> 本地不存在手动 Locale：GET /v1/locale/default
    -> 服务端根据可信客户端 IP 返回默认 Locale
    -> 若为远程语言：下载并校验语言包
    -> 下载失败：回退 en-US 并继续启动
    -> 设置 TranslationServer Locale
    -> 创建或恢复 Session，并提交 Locale
    -> GET /v1/bootstrap
    -> GET /v1/catalog
    -> 进入首页
```

非 Web 客户端：

```text
读取本地 Preferences
    -> 立即设置 TranslationServer Locale
    -> 创建或恢复 Session，并提交 Locale
    -> GET /v1/bootstrap
    -> 用服务端 Locale 校准本地状态
    -> GET /v1/catalog
    -> 进入首页
```

---

## 11. 设置页语言选择

设置页增加：

```text
语言
  - 简体中文
  - English
  - 服务端语言清单中的其他已发布语言
```

这是首期必须实现的玩家功能，不是调试选项。

语言列表优先使用 Bootstrap 的：

```json
"supported_locales": []
```

语言的显示名称、是否内置、版本及下载信息来自 `/v1/locales`。

切换流程：

```text
用户选择新语言
    -> 如果是远程语言且本地没有当前版本
    -> 显示下载大小并下载语言包
    -> 校验并加载语言包
    -> PUT /v1/session/locale
    -> 服务端返回最终 Locale
    -> TranslationServer.set_locale()
    -> 保存本地 Preferences
    -> 清理 Catalog 内存引用
    -> 重新 GET /v1/catalog
    -> 刷新当前页面动态文案和内容标题
```

失败时：

- 恢复原选择；
- 不修改本地 Preferences；
- 不修改 TranslationServer Locale；
- 展示本地化错误。

远程语言下载失败时：

- 保持当前语言；
- 保留已经校验成功的旧语言包；
- 提供重试；
- 不更新 Session Locale；
- 不留下可被加载的半成品文件。

切换请求进行期间禁用语言控件，避免并发更新和旧响应覆盖新状态。

验收要求：

- 用户可以在设置页选择所有已发布语言；
- 中文和英文无需下载即可切换；
- 其他语言在首次选择时下载；
- 选择成功后当前页面立即切换语言；
- 首页、选关页和关卡标题使用新语言；
- 语言选择保存到 `user://settings.cfg`；
- 关闭并重新启动游戏后继续使用上次选择；
- 切换语言不影响账号、进度和游戏数据。

---

## 12. Catalog 缓存

Catalog 缓存必须按 Locale 隔离：

```text
catalog_zh-CN.json
catalog_en-US.json
```

禁止继续使用单一：

```text
user://catalog_cache.json
```

切换语言后清理：

- 当前 Catalog 内存引用；
- 首页 Series 文本和列表状态；
- LevelLoader Catalog；
- 当前页面动态内容文案。

图片缓存可以继续共用。

离线时只能读取当前 Locale 对应的缓存。

---

## 13. 字体

当前项目使用：

```text
NotoSansSC-Game.ttf
```

必须验证：

- 英文字母；
- 简体中文；
- 中英文标点；
- 数字和常用符号。

如果单一字体覆盖不足，在全局 Theme 中配置 Font Fallback。

不要在每个场景单独配置语言字体。

---

## 14. 翻译内容维护

不新增管理界面或管理接口。

Series 和 Level 翻译由维护者直接通过以下方式之一管理：

- SQL 数据脚本；
- 新增数据库迁移；
- 仓库内的内容导入工具。

建议把人工维护的翻译放入可版本控制的数据文件，再由脚本导入，避免只在线上数据库手工修改。

翻译写入必须校验：

- Locale 必须是内置语言或语言清单中已发布的语言；
- 同一内容的 Locale 不能重复；
- Title 不能为空；
- Locale 必须先标准化；
- 不允许同时保存 `en-US` 和 `en_US`；
- 缺少翻译时继续使用统一 fallback。

---

## 15. 测试要求

### 15.1 Locale 标准化

```text
zh / zh_CN / zh-Hans-CN => zh-CN
en / en_US              => en-US
未知 Locale             => 部署默认 Locale
```

### 15.2 Web 默认语言

- 中国大陆 IP 首次访问返回 `zh-CN`；
- 已发布远程语言对应国家的 IP 返回该 Locale；
- 没有对应已发布语言的国家返回 `en-US`；
- GeoIP 失败时使用浏览器/系统 Locale；
- 伪造的 `X-Forwarded-For` 不影响解析结果；
- 只信任配置中的 CDN/反向代理；
- 已有手动选择时不调用或不应用 IP 默认值；
- 默认语言接口不返回用户 IP 和国家信息。

### 15.3 远程语言包

- 中文和英文不触发下载；
- IP 命中已发布远程语言时自动下载；
- 用户主动选择远程语言时下载；
- 下载前检查可用空间和声明大小；
- 下载完成后校验 SHA-256；
- 校验失败不加载文件；
- 中断下载不留下可加载的半成品；
- 新版本下载失败时继续使用已校验的旧版本；
- 无旧版本时回退 `en-US`；
- 相同版本不重复下载；
- 不允许远程包覆盖内置中文和英文；
- 未发布 Locale 不能被选择或写入 Session。

### 15.4 Session

- 创建 Session 保存 Locale；
- Memory Session 返回真实 Locale；
- MySQL Session 返回真实 Locale；
- 切换 Locale 成功；
- 不支持的 Locale 返回稳定错误码；
- Refresh 后 Locale 不变；
- 切换 Locale 不旋转用户身份。

### 15.5 Catalog

- `zh-CN` 返回中文 Series 和 Level 标题；
- `en-US` 返回英文；
- 远程 Locale 返回对应内容翻译；
- 精确翻译缺失时使用部署默认 Locale；
- 默认翻译缺失时使用 `en-US`；
- 所有翻译缺失时使用 legacy；
- legacy 缺失时使用 ID；
- 翻译查询没有新增 N+1；
- 完成状态不受 Locale 影响。

### 15.6 客户端

- 非 Web 客户端首次启动使用系统 Locale；
- Web 首次启动且无手动选择时使用 IP 推断语言；
- Web IP 命中远程语言时自动下载安装；
- 手动选择后下次启动保持；
- Bootstrap 可以校准无效 Locale；
- 切换语言立即刷新 UI；
- 切换语言刷新 Series/Level 标题；
- 动态文案重新执行 `tr()`；
- 切换失败正确回滚；
- Catalog Cache 按 Locale 隔离；
- 离线读取对应 Locale 缓存；
- 中英文无缺字和布局溢出。

### 15.7 翻译数据

1. 导入 Series 中英文翻译；
2. 导入 Level 中英文标题；
3. 重复导入不会产生重复数据；
4. 缺失翻译时 Catalog 使用正确 fallback；
5. 更新翻译不影响 Series-Level 关系。

---

## 16. 实施顺序

### P0-1：Locale 基础

- Locale 标准化函数；
- Web 默认 Locale 接口和 GeoIP 推断；
- `/v1/locales` 语言清单；
- Session 保存 Locale；
- Memory Service 修复；
- `PUT /v1/session/locale`；
- Bootstrap 返回支持语言。

验收：

```text
当前 Session 的 Locale 可以读取、切换和刷新继承。
```

### P0-2：内容翻译

- 新增 `016_i18n.sql`；
- Series 翻译；
- Level 标题翻译；
- fallback；
- Catalog 返回 Locale。

验收：

```text
同一 Catalog 可按 Session Locale 返回不同文案。
```

### P0-3：Godot

- 内置中文和英文 PO 文件；
- LanguagePackManager；
- 远程包下载、校验、缓存和更新；
- LocaleManager；
- 清理硬编码中文；
- 设置页语言选择；
- 动态文案刷新；
- Locale Catalog 缓存；
- 字体验证。

验收：

```text
游戏运行中可以切换内置或已发布的远程语言，无需重启。
```

### P1

- Catalog 批量查询并消除原有 N+1；
- 伪本地化；
- 翻译完成度筛选；
- 日期和数字格式化；
- 自动化 UI 截图测试；
- 完整 OpenAPI 文档。

---

## 17. 明确禁止

1. 不把 UI 翻译和内容翻译全部放入 Godot PO。
2. 不把 Series 或 Level 标题硬编码到客户端。
3. 不为每种语言复制 Series 或 Level。
4. 不修改运行时 Level JSON，只为保存标题翻译。
5. 不删除旧 Series 文案和 `runtime_json.title`。
6. 不为每个 Series 或 Level 单独查询翻译。
7. 不把 `en-US` 和 `en_US` 保存成两个 Locale。
8. 不只翻译 `.tscn` 而遗漏 `.gd` 动态文案。
9. 不下载未经校验的语言包。
10. 不让远程语言包覆盖内置中文和英文。
11. 不把未完成下载的文件当成可用语言包。

---

## 18. 最终验收

同一套内容准备：

```text
series_001
  zh-CN: 世界地标
  en-US: World Landmarks
```

另准备一个已发布的测试远程语言包和对应内容翻译。

客户端选择简体中文：

```text
UI、Series、Level 标题显示简体中文
```

客户端选择 English：

```text
UI、Series、Level 标题显示英文
```

Web IP 命中测试远程语言，或用户主动选择该语言：

```text
客户端下载、校验并加载远程语言包
Catalog 返回对应 Locale 的内容翻译
```

切换语言后必须满足：

- 不要求重新登录；
- 不要求重启游戏；
- Catalog 文案立即刷新；
- 当前页面动态文案立即刷新；
- 玩家进度不变；
- 不出现其他语言的错误缓存；
- 缺少翻译时按统一规则回退。
- 远程语言下载失败时仍可使用英文进入游戏。
