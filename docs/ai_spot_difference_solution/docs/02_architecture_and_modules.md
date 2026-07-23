# 2. 架构与模块

## 2.1 逻辑架构

Godot 客户端通过 HTTPS 访问 Go 单体 API。API 使用 MySQL 保存业务数据、幂等记录和可锁定任务队列；对象存储和 CDN 保存图片、缩略图、mask 与元数据。AI Worker 异步生成和校验内容，管理后台负责审核、配置、灰度与下架。MVP 不强制引入 Redis，达到需要独立扩展队列或缓存的负载后再增加。

## 2.2 客户端模块

- Bootstrap：版本、市场、语言、功能开关、商业化参数。
- Content Catalog：章节、推荐、每日挑战和分页。
- Asset Cache：下载、校验、缓存上限、LRU 清理、断点续传。
- Game Runtime：图片显示、缩放、点击命中、差异状态、计时、结算。
- Monetization：广告、IAP、权益缓存和恢复购买。
- Analytics：批量事件、失败重试、隐私同意状态。
- Local Storage：本地进度、缓存索引、配置快照。

## 2.3 服务端模块

- Identity：匿名设备用户、账号绑定预留。
- Market Resolution：商店地区、系统语言、系统地区、IP 和用户选择。
- Remote Config：版本化、灰度、回滚。
- Recommendation：规则打分，不在 MVP 引入复杂机器学习。
- Level Service：统一关卡协议、版本和资源 URL。
- Progress：开始、暂停、完成、提示与奖励。
- Monetization Verification：广告奖励幂等、Apple/Google 或国内渠道支付验证。
- Content Management：标签、审核、发布、下架。
- Generation Pipeline：任务、模型、成本、质量结果和失败重试。
- Analytics Ingestion：事件接收、批处理和数据清洗。

## 2.4 关键边界

- 客户端禁止出现 `if country == ...` 的内容分支。
- Worker 不直接操作已发布数据，发布必须经过 Content Service 状态机。
- 游戏 API 不同步调用生成模型。
- 资源 URL 使用版本化不可变路径，替换内容时生成新版本，避免 CDN 脏缓存。
- 支付、广告奖励、礼包领取必须使用 idempotency key。

## 2.5 物理部署与进程

MVP 是模块化单体，不是单进程限制。构建产物包含 `oddspot-api`、`oddspot-worker` 和 `oddspot-migrate` 三个 Go 二进制：API 提供在线请求，Worker 使用 MySQL `FOR UPDATE SKIP LOCKED` 消费任务，Migrate 只在发布期间运行。管理后台是静态文件，通过同一 API 的 `/admin` 认证接口工作。

在线 API 不读写本机内容文件，图片只进入对象存储/CDN。本机 `/var/lib/oddspot` 仅用于临时工作目录和可重建缓存，MySQL 是业务事实源。

## 2.6 依赖方向

HTTP handler → application service → domain → repository/provider。domain 不依赖 Godot、HTTP、数据库驱动或第三方 SDK。市场差异只进入 Remote Config、Content Policy 和 Provider 选择，玩法核心与国家无关。

外部接口至少包括 `Clock`、`IDGenerator`、`ObjectStorage`、`CDNURLSigner`、`AdVerifier`、`BillingVerifier`、`EventSink` 和 `ContentSafetyScanner`，均提供 fake/mock。支付和广告 provider 的原始响应只存受限引用或脱敏审计信息，不写普通业务日志。

## 2.7 资源与版本

`level_id` 表示逻辑关卡，`level_version` 表示不可变发布版本，`asset_id + sha256` 表示不可变资源。签名 URL 只是可刷新的下载位置，不能作为缓存键。客户端使用 asset_id 和 sha256 缓存；URL 过期时重新获取关卡详情，不删除已验证缓存。
