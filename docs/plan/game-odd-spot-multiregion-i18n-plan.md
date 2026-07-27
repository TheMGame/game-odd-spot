# game-odd-spot 多语言与多地区改造方案

> 适用仓库：`TheMGame/game-odd-spot`  
> 基于分支：`master`  
> 编写日期：2026-07-27  
> 用途：直接交给代码 AI 按任务顺序实施  
> 本文不包含 AI 关卡生成、自动审核和内容运营流水线。

---

## 1. 改造目标

项目需要支持多个海外地区和多种语言，并满足以下业务要求：

1. 玩家可以选择“地区”。
2. 不同地区展示不同的内容系列。
3. 一个系列可以：
   - 仅属于一个地区；
   - 同时属于多个地区；
   - 属于 `global`，在所有地区展示。
4. 内容管理后台的系列编辑功能必须增加地区选择和地区区分。
5. 玩家可以独立选择语言。
6. UI 文案、系列标题/描述、关卡标题根据语言显示。
7. 玩家切换地区后，首页和选关页立即刷新为该地区的系列。
8. 切换地区不能清空或复制玩家已有的关卡进度。
9. 保持现有 `market`、`locale`、Session、Catalog 体系，不新增重复的 Region 子系统。

---

## 2. 不在本次范围内

本次不要实现：

- AI 图片生成；
- AI 关卡生成；
- 自动内容审核；
- 内容生产 Worker 扩展；
- 地区货币、价格和支付差异；
- 广告平台地区策略；
- App Store / Google Play 分地区包体；
- 图片内文字自动翻译；
- CDN 多区域部署；
- 不同地区使用不同服务器。

本次只解决：

> 地区识别与选择、地区系列过滤、多语言文案、后台地区配置、客户端切换和相关测试。

---

## 3. 现有基础与缺口

### 3.1 已有能力

项目已经存在：

- `markets` 表；
- `global`、`cn`、`us`、`jp` 市场；
- `markets.default_locale`；
- `market_country_aliases`；
- `users.market_id`；
- `users.locale`；
- Session 创建时保存 `market` 和 `locale`；
- Bootstrap 返回 `market` 和 `locale`；
- 日常挑战和活动接口已经按用户 Market 查询。

因此，不要新增 `regions` 表，也不要同时维护 `region_id` 和 `market_id`。

### 3.2 当前缺口

当前 Catalog 仍然是全局 Catalog：

- `content_series` 没有 Market 关系；
- `content_series` 的 `title`、`description` 只有一种语言；
- `/v1/catalog` 没有读取当前用户的 `market/locale`；
- `catalog.Service.Public()` 只接收 `userID`；
- 后台系列表单不能选择地区；
- 客户端设置页没有地区和语言选择；
- 客户端大量 UI 文案直接写死为中文；
- Catalog 缓存或内存状态没有按 `market + locale` 隔离；
- 外部账号登录接口只提交 locale，初次登录不能传 store country；
- Memory Session Service 的 Profile 固定返回 `global/en`，无法测试切换。

---

## 4. 统一概念

### 4.1 Market

代码和数据库统一使用：

```text
market
market_id
```

用户界面显示为：

```text
地区
Region
地域
```

Market 决定：

- 展示哪些系列；
- 系列排序；
- 系列是否启用；
- 地区封面覆盖；
- Remote Config；
- Daily Challenge；
- Activities；
- 后续可能增加的地区运营配置。

### 4.2 Locale

统一使用 BCP 47 格式：

```text
en-US
zh-CN
ja-JP
```

Locale 决定：

- 客户端 UI 文案；
- 系列标题和描述；
- 关卡标题；
- 日期、数字等显示格式。

Locale 不决定系列是否可见。

错误做法：

```text
locale=ja-JP，所以自动认为 market=jp
```

这只允许用于首次安装时的默认推断。玩家明确选择地区以后，不得再用 Locale 覆盖 Market。

### 4.3 Country

`store_country` 或设备国家仅用于首次建立用户时推断默认 Market。

优先级：

```text
玩家明确保存的 Market
    >
服务端已有 users.market_id
    >
store_country 映射
    >
locale 推断
    >
服务端默认 Market
```

---

## 5. 内容归属规则

### 5.1 系列与地区

一个系列可以绑定多个 Market：

```text
series_world_landmarks
  ├── global
  ├── us
  └── jp
```

也可以只属于一个 Market：

```text
series_japan_showa
  └── jp
```

### 5.2 Global 规则

`global` 是公共内容池。

查询 `jp` Catalog 时：

```text
jp 专属系列 + global 公共系列
```

查询 `us` Catalog 时：

```text
us 专属系列 + global 公共系列
```

### 5.3 显式地区配置优先

当同一个系列同时存在：

```text
global 配置
jp 配置
```

在日本地区必须使用 `jp` 配置覆盖 `global` 配置。

覆盖字段包括：

- `enabled`
- `sort_order`
- `cover_url`
- `available_from`
- `available_until`

特别规则：

> 如果系列在 `global` 为启用，但在 `jp` 存在一条 `enabled=false` 的显式配置，则日本地区必须隐藏该系列。

不能因为 global 已启用而继续展示。

### 5.4 关卡归属

本阶段不增加 `level_market`。

关卡仍通过：

```text
content_series_levels
```

归属于系列，系列再决定地区。

原因：

- 当前需求的地区边界在“系列”；
- 可以通过不同地区系列组合不同关卡；
- 避免同时维护“系列地区”和“关卡地区”两套容易冲突的规则。

同一个 Level 可以加入多个系列。玩家进度仍然按 `level_id` 保存，不按 Market 复制。

---

## 6. 数据库改造

新增迁移：

```text
server/internal/database/migrations/016_multiregion_i18n.sql
```

### 6.1 Market 支持的语言

```sql
CREATE TABLE IF NOT EXISTS market_locales (
  market_id VARCHAR(32) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (market_id, locale),
  INDEX idx_market_locales_enabled (market_id, enabled, sort_order, locale),
  CONSTRAINT fk_market_locales_market
    FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

`markets.default_locale` 继续作为唯一默认语言来源，不新增第二个 `is_default` 字段，避免两个默认值不一致。

初始数据建议：

```sql
INSERT IGNORE INTO market_locales(market_id, locale, sort_order) VALUES
  ('global', 'en-US', 10),
  ('global', 'zh-CN', 20),
  ('global', 'ja-JP', 30),

  ('cn', 'zh-CN', 10),
  ('cn', 'en-US', 20),

  ('us', 'en-US', 10),
  ('us', 'zh-CN', 20),

  ('jp', 'ja-JP', 10),
  ('jp', 'en-US', 20);
```

这些只是初始配置，后台应允许后续启用或禁用语言。

### 6.2 Market 显示名称多语言

```sql
CREATE TABLE IF NOT EXISTS market_i18n (
  market_id VARCHAR(32) NOT NULL,
  locale VARCHAR(16) NOT NULL,
  display_name VARCHAR(64) NOT NULL,
  PRIMARY KEY (market_id, locale),
  CONSTRAINT fk_market_i18n_market
    FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

示例数据：

```sql
INSERT IGNORE INTO market_i18n(market_id, locale, display_name) VALUES
  ('global', 'en-US', 'Global'),
  ('global', 'zh-CN', '全球'),
  ('global', 'ja-JP', 'グローバル'),

  ('cn', 'en-US', 'China'),
  ('cn', 'zh-CN', '中国'),
  ('cn', 'ja-JP', '中国'),

  ('us', 'en-US', 'United States'),
  ('us', 'zh-CN', '美国'),
  ('us', 'ja-JP', 'アメリカ'),

  ('jp', 'en-US', 'Japan'),
  ('jp', 'zh-CN', '日本'),
  ('jp', 'ja-JP', '日本');
```

### 6.3 系列与 Market 的关系

```sql
CREATE TABLE IF NOT EXISTS content_series_markets (
  series_id VARCHAR(64) NOT NULL,
  market_id VARCHAR(32) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  cover_url VARCHAR(1024) NOT NULL DEFAULT '',
  available_from TIMESTAMP(3) NULL,
  available_until TIMESTAMP(3) NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (series_id, market_id),
  INDEX idx_series_market_catalog (
    market_id,
    enabled,
    sort_order,
    series_id
  ),
  CONSTRAINT fk_series_markets_series
    FOREIGN KEY (series_id) REFERENCES content_series(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_series_markets_market
    FOREIGN KEY (market_id) REFERENCES markets(id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

说明：

- `content_series.enabled`：系列总开关。
- `content_series_markets.enabled`：该地区开关。
- 两者都为 true 才允许展示。
- `content_series.cover_url`：旧版和默认封面。
- `content_series_markets.cover_url`：地区封面覆盖；空字符串表示使用系列默认封面。
- `sort_order` 使用地区配置；不再使用 `content_series.sort_order` 作为公开 Catalog 的最终排序，但保留旧字段用于兼容和回退。

### 6.4 系列多语言

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

### 6.5 关卡标题多语言

当前 Catalog 从 `level_versions.runtime_json.title` 读取标题。为避免修改不可变运行时关卡协议，新增独立翻译表：

```sql
CREATE TABLE IF NOT EXISTS content_level_i18n (
  level_id VARCHAR(64) NOT NULL,
  level_version INT NOT NULL,
  locale VARCHAR(16) NOT NULL,
  title VARCHAR(128) NOT NULL,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (level_id, level_version, locale),
  CONSTRAINT fk_level_i18n_version
    FOREIGN KEY (level_id, level_version)
    REFERENCES level_versions(level_id, version)
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
```

不要把不同语言标题重复写入整个 `runtime_json`，也不要为每种语言创建一个新的 Level。

### 6.6 现有数据回填

所有现有系列先归入 `global`：

```sql
INSERT IGNORE INTO content_series_markets(
  series_id,
  market_id,
  enabled,
  sort_order,
  cover_url
)
SELECT
  id,
  'global',
  enabled,
  sort_order,
  cover_url
FROM content_series;
```

现有 `title/description` 保留，不删除。

它们作为迁移期最终 fallback。

不要把现有标题自动复制到所有语言，否则后台会错误显示“所有翻译均已完成”。

如果已经确认现有内容全部为简体中文，可以只回填 `zh-CN`：

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

执行前必须人工确认现有系列文案确实为简体中文。

---

## 7. 语言回退规则

服务端读取系列和关卡文案时，严格按以下顺序：

```text
1. 用户请求的精确 locale
2. 当前 Market 的 default_locale
3. en-US
4. content_series.title / description 或 runtime_json.title
5. ID
```

示例：

```text
Market = jp
Locale = en-US
```

系列标题读取顺序：

```text
content_series_i18n.en-US
    >
content_series_i18n.ja-JP
    >
content_series.title
    >
series_id
```

不要做模糊的语言前缀随机匹配，例如在多个中文变体存在时直接取任意 `zh-*`。

后续需要 `zh-TW` 时，应显式建立对应翻译或显式定义 fallback，不要依赖数据库排序。

---

## 8. 服务端接口改造

### 8.1 获取可选地区和语言

新增：

```http
GET /v1/markets
Authorization: Bearer <token>
```

响应：

```json
{
  "data": {
    "current_market": "jp",
    "current_locale": "ja-JP",
    "markets": [
      {
        "id": "global",
        "name": "グローバル",
        "default_locale": "en-US",
        "locales": ["en-US", "zh-CN", "ja-JP"]
      },
      {
        "id": "jp",
        "name": "日本",
        "default_locale": "ja-JP",
        "locales": ["ja-JP", "en-US"]
      }
    ]
  }
}
```

规则：

- 只返回 `markets.enabled=true`。
- 只返回 `market_locales.enabled=true`。
- Market 名称使用当前 Locale。
- 名称缺失时按语言回退规则读取。
- 当前用户 Market 已禁用时，返回服务端默认 Market。
- 当前 Locale 不受该 Market 支持时，返回 Market 默认 Locale。

### 8.2 更新玩家地区和语言

新增：

```http
PUT /v1/preferences
Authorization: Bearer <token>
Content-Type: application/json
```

请求：

```json
{
  "market_id": "jp",
  "locale": "en-US"
}
```

服务端验证：

1. `market_id` 存在且启用；
2. `locale` 存在于该 Market 的启用语言列表；
3. 用户存在；
4. 更新必须在一个事务中完成。

更新：

```sql
UPDATE users
SET market_id=?, locale=?
WHERE id=?;
```

响应：

```json
{
  "data": {
    "market": "jp",
    "locale": "en-US",
    "catalog_invalidated": true
  }
}
```

错误：

```text
404 MARKET_NOT_FOUND
422 MARKET_DISABLED
422 LOCALE_NOT_SUPPORTED
```

无需旋转 Access Token 或 Refresh Token，因为现有鉴权只从 Token 解析 `user_id`，Market 和 Locale 应每次从用户 Profile 读取。

### 8.3 Bootstrap

扩展 `GET /v1/bootstrap`：

```json
{
  "data": {
    "market": "jp",
    "locale": "en-US",
    "supported_locales": ["ja-JP", "en-US"],
    "config_source_market": "jp",
    "config_version": 3
  }
}
```

Bootstrap 不需要返回完整 Market 列表；完整列表由 `/v1/markets` 提供。

### 8.4 Catalog

修改：

```go
Public(context.Context, string)
```

为：

```go
Public(
    ctx context.Context,
    userID string,
    marketID string,
    locale string,
) ([]Series, error)
```

推荐增加参数结构体，避免继续扩展长参数：

```go
type PublicQuery struct {
    UserID   string
    MarketID string
    Locale   string
}

Public(context.Context, PublicQuery) ([]Series, error)
```

`GET /v1/catalog` 流程：

```text
鉴权得到 userID
    ↓
Sessions.Profile(userID)
    ↓
得到 marketID + locale
    ↓
Catalog.Public(PublicQuery)
    ↓
返回地区过滤并本地化后的系列
```

响应必须包含：

```json
{
  "data": {
    "market": "jp",
    "locale": "en-US",
    "series": []
  }
}
```

普通玩家 Catalog 不接受客户端传入的：

```text
?market=jp
X-Market-ID: jp
```

原因：

- 服务端用户偏好才是数据源；
- 避免客户端状态和服务端状态不一致；
- 防止绕过地区配置；
- 降低缓存键混乱。

### 8.5 Admin Catalog

修改：

```http
GET /admin/v1/catalog
```

支持：

```http
GET /admin/v1/catalog?market_id=jp&locale=en-US&enabled=true
```

后台必须可以：

- 查看全部 Market；
- 按 Market 过滤；
- 按 Locale 预览；
- 查看系列的所有地区绑定和翻译，而不只是公开 Catalog 结果。

建议区分两个接口：

```text
GET /admin/v1/series
GET /admin/v1/catalog/preview?market_id=jp&locale=en-US
```

- `/admin/v1/series`：完整管理数据。
- `/admin/v1/catalog/preview`：模拟玩家实际看到的 Catalog。

不要继续让一个 `/admin/v1/catalog` 同时承担“管理原始数据”和“玩家结果预览”两种语义。

---

## 9. 服务端数据结构

建议把公开响应和后台写入结构分开。

### 9.1 公开 Series

```go
type Series struct {
    ID           string  `json:"id"`
    Title        string  `json:"title"`
    Description  string  `json:"description"`
    Mode         string  `json:"mode"`
    CoverURL     string  `json:"cover_url"`
    SortOrder    int     `json:"sort_order"`
    Enabled      bool    `json:"enabled"`
    SourceMarket string  `json:"source_market"`
    Levels       []Level `json:"levels"`
}
```

`SourceMarket` 用于调试和后台预览：

```text
jp
global
```

生产客户端可以忽略此字段。

### 9.2 后台系列写入结构

不要继续直接使用公开 `catalog.Series` 作为后台 Upsert 输入。

新增：

```go
type SeriesTranslationInput struct {
    Locale      string `json:"locale"`
    Title       string `json:"title"`
    Description string `json:"description"`
}

type SeriesMarketInput struct {
    MarketID      string     `json:"market_id"`
    Enabled       bool       `json:"enabled"`
    SortOrder     int        `json:"sort_order"`
    CoverURL      string     `json:"cover_url"`
    AvailableFrom *time.Time `json:"available_from"`
    AvailableUntil *time.Time `json:"available_until"`
}

type UpsertSeriesInput struct {
    ID           string                   `json:"id"`
    Mode         string                   `json:"mode"`
    Enabled      bool                     `json:"enabled"`
    DefaultTitle string                   `json:"default_title"`
    DefaultDescription string             `json:"default_description"`
    DefaultCoverURL string                `json:"default_cover_url"`
    Markets      []SeriesMarketInput      `json:"markets"`
    Translations []SeriesTranslationInput `json:"translations"`
}
```

兼容旧数据时可继续接收原来的字段，但写入逻辑必须统一转为新结构。

### 9.3 后台 Upsert 事务

`UpsertSeries` 必须在同一个数据库事务中完成：

1. Upsert `content_series`；
2. Upsert `content_series_markets`；
3. 删除此次请求中已移除的 Market 绑定；
4. Upsert `content_series_i18n`；
5. 删除此次请求中明确移除的翻译；
6. 校验每个启用 Market 的默认语言翻译；
7. Commit。

不要在第 1 步成功后，后续失败却留下半个系列配置。

---

## 10. Catalog 查询逻辑

### 10.1 Market 选择

查询候选：

```text
selected market
global
```

对于每个 `series_id`：

1. 有 selected market 行：选择 selected market 行；
2. 没有 selected market 行：选择 global 行；
3. 选择出的行 `enabled=false`：隐藏；
4. `content_series.enabled=false`：隐藏；
5. 当前时间不在可用时间范围：隐藏。

### 10.2 避免重复系列

同一个系列同时存在 `global` 和 `jp` 时，只返回一次。

可使用 MySQL 8 Window Function：

```sql
ROW_NUMBER() OVER (
  PARTITION BY series_id
  ORDER BY (market_id = ?) DESC
)
```

也可以在 Go 层去重，但必须保证：

- 地区行优先；
- 显式禁用能覆盖 global；
- 最终按地区 `sort_order` 排序；
- 查询结果稳定。

### 10.3 Series 文案

Series 查询时使用：

```text
requested locale
market.default_locale
en-US
legacy
```

建议一次 JOIN/子查询完成，不要为每个系列分别查询翻译，避免新增 N+1。

### 10.4 Level 文案

关卡标题从 `content_level_i18n` 读取，fallback 到 `runtime_json.title`。

不要为每个 Level 单独发 SQL。

当前 Catalog 已经有“每个 Series 再查 Levels”的 N+1 结构。本次改造至少不能继续增加“每个 Series/Level 再查翻译”的额外 N+1。

如果时间允许，应同时把 Catalog 改造成：

```text
一次查询 Series
一次批量查询所有 Series 的 Levels
一次批量查询完成状态
Go 层组装
```

这是推荐优化，但不是多地区功能上线的阻塞项。

---

## 11. Session 与 Market Service

涉及：

```text
server/internal/session/service.go
server/internal/session/mysql_service.go
server/internal/market/service.go
server/internal/httpapi/router.go
```

### 11.1 Session Service

新增：

```go
UpdateProfile(
    ctx context.Context,
    userID string,
    marketID string,
    locale string,
) error
```

MySQL 实现更新 `users.market_id/locale`。

Memory 实现必须真正保存用户 Profile，不能继续固定返回：

```text
global / en
```

MemoryService 应增加：

```go
profiles map[string]Profile
```

否则本地模式和单元测试无法验证地区切换。

### 11.2 External User Session

当前 `/v1/sessions/user-server` 只接收：

```json
{
  "token": "...",
  "locale": "ja-JP"
}
```

扩展为：

```json
{
  "token": "...",
  "locale": "ja-JP",
  "store_country": "JP"
}
```

首次建立外部用户时：

```go
marketID := Markets.Resolve(
    ctx,
    input.StoreCountry,
    input.Locale,
    config.Market,
)
```

再调用：

```go
IssueExternal(ctx, userID, marketID, locale)
```

现有 `EnsureExternalUser` 对已存在用户不覆盖 Market/Locale 的行为应保留，避免每次登录都覆盖玩家手动选择。

### 11.3 Market Service

扩展接口，不再只有 Resolve：

```go
type Service interface {
    Resolve(ctx context.Context, country, locale, fallback string) string
    List(ctx context.Context, displayLocale string) ([]Market, error)
    ValidatePreference(
        ctx context.Context,
        marketID string,
        locale string,
    ) error
    DefaultLocale(ctx context.Context, marketID string) (string, error)
}
```

---

## 12. 客户端国际化

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

### 12.1 翻译文件

新增：

```text
client/i18n/en_US.po
client/i18n/zh_CN.po
client/i18n/ja_JP.po
```

推荐使用 PO，而不是把所有语言放进一个巨大 CSV：

- 每种语言独立修改；
- Git diff 更清楚；
- 后续容易接入翻译工具；
- 多行文案更容易维护。

把翻译文件注册到 Godot Project Settings：

```text
Localization > Translations
```

### 12.2 翻译 Key

场景和代码中不要继续使用中文原文作为业务 Key。

示例：

```text
APP_NAME
COMMON_BACK
COMMON_RETRY
HOME_TITLE
HOME_DAILY
SETTINGS_TITLE
SETTINGS_REGION
SETTINGS_LANGUAGE
SETTINGS_REGION_CHANGED
LOGIN_TITLE
LEVEL_COMPLETE
LEVEL_SYNC_PENDING
ERROR_CATALOG_LOAD_FAILED
```

场景中的 Label/Button：

```gdscript
text = "SETTINGS_TITLE"
```

程序动态文案：

```gdscript
status_label.text = tr("SETTINGS_REGION_CHANGED")
```

带参数：

```gdscript
status_label.text = tr("APP_VERSION").format({
    "version": version
})
```

### 12.3 清理硬编码文案

全仓搜索：

```text
text = "
placeholder_text = "
status_label.text =
_show_catalog_message(
push_error(
```

所有玩家可见字符串必须改为翻译 Key。

以下内容不用翻译：

- 日志内部错误；
- API error code；
- Level ID；
- 调试信息；
- 管理员技术字段。

### 12.4 Locale 格式

API 使用：

```text
en-US
zh-CN
ja-JP
```

Godot `TranslationServer.set_locale()` 会标准化已知 Locale，因此客户端可直接传 API 返回值：

```gdscript
TranslationServer.set_locale("en-US")
```

保存时仍使用 API 的 BCP 47 格式，不要一部分存 `en_US`，另一部分存 `en-US`。

### 12.5 字体

当前项目只配置了：

```text
NotoSansSC-Game.ttf
```

必须验证：

- 英文字符；
- 简体中文；
- 日文假名；
- 日文汉字字形；
- 标点；
- 数字。

如覆盖不足，增加 Font Variation/Fallback 配置。

不要在每个场景单独切换字体，应在全局 Theme 中配置 fallback。

---

## 13. 客户端地区与语言状态

### 13.1 Preferences

扩展：

```gdscript
var market_id := ""
var locale := ""
var locale_mode := "automatic" # automatic | manual
```

保存位置：

```text
user://settings.cfg
```

建议字段：

```ini
[localization]
market_id="jp"
locale="en-US"
locale_mode="manual"
```

服务端 `users.market_id/locale` 是最终来源；本地 Preferences 用于启动时快速显示和离线回退。

### 13.2 LocaleManager

新增 Autoload：

```text
LocaleManager="*res://scripts/localization/locale_manager.gd"
```

职责：

- 初始化系统语言；
- 标准化 Locale；
- 调用 `TranslationServer.set_locale()`；
- 保存 Preferences；
- 根据 Bootstrap 校准本地状态；
- 发出语言变化信号。

建议接口：

```gdscript
signal locale_changed(locale: String)
signal market_changed(market_id: String)

func apply_bootstrap(data: Dictionary) -> void
func set_locale(locale: String) -> void
func set_market(market_id: String) -> void
func current_locale() -> String
func current_market() -> String
```

### 13.3 启动顺序

目标流程：

```text
读取本地 Preferences
    ↓
立即设置 TranslationServer Locale
    ↓
确保登录 Session
    ↓
GET /v1/bootstrap
    ↓
用服务端 market/locale 校准本地值
    ↓
GET /v1/catalog
    ↓
进入首页
```

当前 `bootstrap.gd` 只是定时器模拟进度。本次应把真实 Bootstrap 接入。

---

## 14. 设置页改造

在设置页新增独立卡片：

```text
地区与语言
├── 地区
└── 语言
```

### 14.1 地区选择

控件使用 `OptionButton`。

数据来自：

```http
GET /v1/markets
```

不要在客户端写死 `global/cn/us/jp`。

展示名称使用 API 返回的本地化 Market Name。

### 14.2 语言选择

语言列表根据当前 Market 的：

```json
"locales": []
```

生成。

不要把所有语言无条件展示给所有 Market。

### 14.3 切换地区

流程：

```text
玩家选择新地区
    ↓
如当前 Locale 不受新地区支持
    ↓
自动选择新地区 default_locale
    ↓
PUT /v1/preferences
    ↓
更新 LocaleManager + Preferences
    ↓
清理 Catalog 内存状态/缓存
    ↓
重新 GET /v1/bootstrap
    ↓
重新 GET /v1/catalog
    ↓
刷新首页
```

显示提示：

```text
更改地区后，可用的内容系列会发生变化。
你的游戏进度不会丢失。
```

切换失败：

- UI 恢复原选择；
- 不修改本地 Preferences；
- 展示本地化错误。

### 14.4 切换语言

流程：

```text
PUT /v1/preferences
    ↓
TranslationServer.set_locale()
    ↓
重新获取 Catalog
    ↓
刷新当前页面文案
```

已打开场景中的自动翻译节点应随 Locale 更新；动态文案必须监听 `locale_changed` 后重新赋值。

---

## 15. Catalog 缓存和页面状态

任何 Catalog 缓存必须使用复合键：

```text
market_id + locale
```

示例：

```text
catalog_jp_ja-JP.json
catalog_jp_en-US.json
catalog_us_en-US.json
```

禁止使用：

```text
catalog.json
```

否则切换地区或语言后会看到旧内容。

切换 Market 后必须清理：

- 首页 `series_items`；
- `series_images`；
- `series_image_quality`；
- LevelLoader 内存 Catalog；
- 下一关预加载；
- 当前地区 Catalog 缓存引用。

图片文件本身可继续按 URL/hash 共用，不必全部删除。

---

## 16. 内容管理后台

涉及：

```text
admin/index.html
admin/app.js
admin/styles.css
server/internal/httpapi/router.go
server/internal/catalog/service.go
```

### 16.1 系列列表

增加列：

| 字段 | 内容 |
|---|---|
| 系列 | ID + 默认标题 |
| 地区 | Market Badge 列表 |
| 翻译 | 已完成数量 / 所需数量 |
| 模式 | side_by_side 等 |
| 全局状态 | content_series.enabled |
| 地区状态 | 各地区 enabled |
| 更新时间 | updated_at |

增加筛选：

- Market；
- Locale；
- 全局 Enabled；
- 地区 Enabled；
- 翻译完整；
- 缺少翻译。

### 16.2 系列编辑表单

增加“适用地区”区域：

```text
☑ Global
☐ China
☑ United States
☑ Japan
```

每个选中的地区可展开配置：

```text
地区启用状态
排序
地区封面 URL
可用开始时间
可用结束时间
```

增加“多语言文案”区域：

```text
[简体中文] [English] [日本語]
标题
描述
```

翻译 Tab 来自已启用的 `market_locales`，不是写死。

### 16.3 校验

系列保存时：

1. 至少选择一个 Market；
2. `id`、`mode` 必填；
3. 选中并启用的 Market 必须有该 Market 默认语言标题；
4. `available_until` 必须晚于 `available_from`；
5. Market 必须存在且启用；
6. Locale 必须是已配置 Locale；
7. 同一个 Market 不能重复；
8. 同一个 Locale 不能重复；
9. `sort_order` 必须为整数；
10. URL 字段只能为空或合法 HTTP(S)/项目允许的相对路径。

### 16.4 Catalog 预览

后台增加：

```text
地区：Japan
语言：English
[预览玩家 Catalog]
```

预览必须调用服务端 Preview API，不能在浏览器端自己模拟过滤和 fallback。

这样后台看到的结果与玩家实际接口一致。

### 16.5 关卡标题

关卡编辑区域增加：

```text
Localized Titles
├── zh-CN
├── en-US
└── ja-JP
```

保存到 `content_level_i18n`。

本次不做关卡图片按语言替换。图片内包含文本时，应建立地区专属系列/关卡或人工制作无文字版本。

---

## 17. Admin API 建议

新增或调整：

```text
GET    /admin/v1/markets
GET    /admin/v1/series
POST   /admin/v1/series
GET    /admin/v1/series/{seriesId}
PUT    /admin/v1/series/{seriesId}
GET    /admin/v1/catalog/preview?market_id=jp&locale=en-US
PUT    /admin/v1/levels/{levelId}/versions/{version}/translations
```

当前只有：

```text
GET  /admin/v1/catalog
POST /admin/v1/series
```

可以保留旧接口用于兼容，但新后台应切换到语义明确的新接口。

删除系列 Market/Translation 时建议使用完整替换语义：

```http
PUT /admin/v1/series/{seriesId}
```

请求中的 `markets` 和 `translations` 代表最终完整状态。

这比多个小 Patch 更容易保证后台表单与数据库一致。

---

## 18. Analytics

事件公共属性增加：

```json
{
  "market": "jp",
  "locale": "en-US"
}
```

至少覆盖：

- `app_open`
- `home_impression`
- `series_open`
- `level_start`
- `level_complete`
- `market_changed`
- `locale_changed`

切换事件示例：

```json
{
  "event_type": "market_changed",
  "properties": {
    "from_market": "global",
    "to_market": "jp",
    "locale": "en-US"
  }
}
```

不要依赖客户端为关键服务端业务事件填 Market；服务端可以从用户 Profile 补充时，应以服务端值为准。

---

## 19. 测试要求

### 19.1 数据库迁移测试

验证：

- 迁移可在现有数据库执行；
- 重复执行不会破坏数据；
- 现有系列全部进入 global；
- Foreign Key 正确；
- 删除 Series 会清理 Market 和翻译关系；
- 旧 `content_series.title/description` 仍可回退。

### 19.2 Catalog 单元测试

必须包含：

#### 地区过滤

```text
JP 用户看到 jp + global
US 用户看到 us + global
JP 用户看不到仅 us 系列
```

#### 显式覆盖

```text
global enabled=true
jp enabled=false
=> JP 隐藏
```

```text
global sort=100
jp sort=10
=> JP 使用 10
```

#### 去重

```text
同一系列绑定 global + jp
=> JP Catalog 只返回一次
```

#### 时间范围

```text
未到 available_from => 隐藏
超过 available_until => 隐藏
```

#### 文案回退

```text
requested locale
market default locale
en-US
legacy
ID
```

#### 进度

同一个 Level 在不同 Market 系列中出现时：

```text
Completed 状态一致
```

### 19.3 Preference API 测试

覆盖：

- 正常修改；
- 不存在 Market；
- Disabled Market；
- 不支持的 Locale；
- 未鉴权；
- 用户不存在；
- 更新后 Bootstrap 返回新值；
- 更新后 Catalog 返回新地区系列；
- 更新无需刷新 Token。

### 19.4 Client 测试

覆盖：

- 首次启动使用系统 Locale；
- Bootstrap 覆盖本地过期 Market；
- 地区切换刷新系列；
- 语言切换刷新 UI；
- 语言切换刷新系列/关卡标题；
- 切换失败回滚 OptionButton；
- 切换地区不清空 ProgressStore；
- Catalog Cache 按 `market + locale` 隔离；
- 离线时使用当前地区和语言对应缓存；
- 动态状态文案可重新翻译；
- 日文字符无缺字。

### 19.5 Admin 验收

手工验证：

1. 创建仅 Japan 可见的系列；
2. 绑定 ja-JP 和 en-US 文案；
3. Japan/ja-JP 预览显示日文；
4. Japan/en-US 预览显示英文；
5. US 预览不显示该系列；
6. 改为 global 后 US 可以显示；
7. Japan 显式禁用后 Japan 不显示；
8. 缺少 Japan 默认语言标题时不能启用；
9. 删除 Market 绑定后刷新仍保持一致；
10. 编辑旧系列不会丢失已有 Level 关系。

---

## 20. 实施优先级

### P0-1：数据库和领域模型

- 新增 `016_multiregion_i18n.sql`；
- 增加 Market Locale、Market 名称、Series Market、Series 翻译、Level 翻译；
- 回填现有 Series 到 global；
- 增加结构体和 Repository。

验收：

```text
数据库可迁移，旧 Catalog 仍可通过 legacy fallback 返回。
```

### P0-2：Preference 和 Market API

- 扩展 Session Service；
- 实现 `GET /v1/markets`；
- 实现 `PUT /v1/preferences`；
- 扩展 external session 的 `store_country`；
- Bootstrap 返回支持语言。

验收：

```text
用户地区和语言可持久保存，重新登录后仍保持。
```

### P0-3：地区 Catalog

- Catalog 按 Profile Market 过滤；
- global fallback；
- 显式 Market 覆盖；
- 本地化系列和关卡标题；
- 响应增加 market/locale。

验收：

```text
不同地区用户获得不同系列，且无重复、无越区内容。
```

### P0-4：Admin 系列地区管理

- 系列列表显示 Market；
- 系列表单支持多 Market；
- 每个 Market 支持地区配置；
- 支持多语言文案；
- 增加 Catalog 预览。

验收：

```text
无需直接操作数据库即可配置 Japan-only、US-only 和 Global 系列。
```

### P0-5：Godot 多语言

- 添加 PO 文件；
- 所有玩家可见中文替换为 Key；
- LocaleManager；
- 全局 Theme 字体覆盖；
- 动态文案监听 Locale 变化。

验收：

```text
zh-CN、en-US、ja-JP 三种语言可以在运行时切换。
```

### P0-6：Godot 地区设置

- 设置页 Region/Language；
- 调用 Market 和 Preference API；
- 切换后清 Catalog；
- 重载 Bootstrap/Home；
- 进度不变。

验收：

```text
不重启游戏即可切换地区，并立即看到该地区系列。
```

### P1：完善与优化

- Catalog 批量查询，减少 N+1；
- 翻译完成度统计；
- 后台缺翻译筛选；
- 伪本地化测试；
- Analytics Market/Locale 维度；
- Catalog 离线缓存；
- 地区内容发布时间；
- 完整 OpenAPI 文档。

---

## 21. 明确禁止的实现

代码 AI 不得采用以下方案：

1. 新建一套 `regions` 表，与现有 `markets` 并行。
2. 在 `content_series` 只加一个 `region` 字符串字段。
3. 用逗号字符串保存多个地区：
   ```text
   global,us,jp
   ```
4. 用 JSON 数组代替标准关系表保存 Series Markets。
5. 根据 Locale 每次自动覆盖玩家已选择的 Market。
6. 通过 `/v1/catalog?market=...` 让普通客户端任意切换地区而不保存 Profile。
7. 为每种语言复制一套 Series ID 或 Level ID。
8. 切换 Market 时清空 ProgressStore。
9. 将 UI 翻译和内容翻译全部塞入 Godot PO 文件。
10. 将系列标题硬编码到客户端。
11. 在 Admin 前端自行模拟 Catalog 过滤规则。
12. 为每个 Series 或 Level 单独查询一次翻译。
13. 删除 `content_series.title/description`，导致旧数据无法回退。
14. 把地区显示名称直接固定为英文。
15. 只翻译 `.tscn`，遗漏 `.gd` 中动态文案。
16. 把 `en-US` 和 `en_US` 作为两个不同 Locale 保存。
17. 修改运行时关卡 JSON 协议，只为存储标题翻译。
18. 把地区配置与 AI 内容生产流水线耦合。

---

## 22. 最终验收场景

准备以下系列：

```text
series_global_001
  markets: global
  locales: zh-CN, en-US, ja-JP

series_us_001
  markets: us
  locales: en-US

series_jp_001
  markets: jp
  locales: ja-JP, en-US

series_asia_001
  markets: cn, jp
  locales: zh-CN, ja-JP, en-US
```

### 中国地区 + 简体中文

应显示：

```text
series_global_001
series_asia_001
```

文案为简体中文。

### 美国地区 + English

应显示：

```text
series_global_001
series_us_001
```

文案为英文。

### 日本地区 + 日本語

应显示：

```text
series_global_001
series_jp_001
series_asia_001
```

文案为日文。

### 日本地区 + English

显示系列不变：

```text
series_global_001
series_jp_001
series_asia_001
```

仅文案切换为英文。

### 从日本切换到美国

必须满足：

- 日本专属系列立即消失；
- 美国专属系列立即出现；
- global 系列继续存在；
- 已完成 Level 仍显示完成；
- 不要求重新登录；
- 不要求重启游戏；
- Catalog 不出现日本缓存数据；
- Bootstrap 返回 `market=us`；
- Analytics 后续事件使用 `market=us`。

---

## 23. 代码 AI 执行要求

代码 AI 修改前必须先读取：

```text
server/internal/database/migrations/
server/internal/market/
server/internal/session/
server/internal/catalog/
server/internal/httpapi/router.go
admin/
client/project.godot
client/scripts/api/api_client.gd
client/scripts/storage/preferences.gd
client/scripts/storage/session_store.gd
client/scenes/bootstrap/
client/scenes/home/
client/scenes/level_select/
client/scenes/settings/
contracts/
```

执行规则：

1. 按 P0-1 到 P0-6 顺序修改。
2. 每完成一个阶段先运行该阶段测试。
3. 不改动 AI generation Worker。
4. 不删除现有 API，除非新 API 已完成兼容迁移。
5. SQL 迁移只能新增 `016`，不得修改已经执行过的 `001-015`。
6. 所有新增 API 补 OpenAPI。
7. 所有新增错误必须使用稳定 `error_code`。
8. 管理后台写入必须使用事务。
9. 公开 Catalog 必须以服务端 Profile 为准。
10. 提交最终变更时输出：
    - 修改文件列表；
    - 数据库迁移说明；
    - API 变化；
    - 客户端变化；
    - Admin 变化；
    - 测试结果；
    - 尚未完成项。
