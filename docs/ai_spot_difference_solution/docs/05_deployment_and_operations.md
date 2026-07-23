# 5. 部署与运维

## 5.1 MVP 部署

当前不使用 Docker。CI 在 Linux amd64 上交叉编译 Go API/Worker，管理后台构建为静态文件，并组成带 SHA-256 清单的版本包。Ubuntu 服务器使用 Nginx、systemd、MySQL 8 和 Redis 7；数据库也可替换为托管 MySQL。对象存储与 CDN 独立。AI Worker 不与在线 API 同步耦合。

推荐域名：`api.game.example.com`、`admin.game.example.com`、`cdn.game.example.com`，后续可增加 `events.game.example.com`。

目录约定：`/opt/oddspot/releases/<version>` 保存不可变版本，`/opt/oddspot/current` 是当前版本软链接，`/etc/oddspot/*.env` 保存 root 可读的环境变量，`/var/lib/oddspot` 保存运行数据，`/var/log/oddspot` 由 journald 或日志轮转管理。服务以无登录权限的 `oddspot` 用户运行。

发布顺序：上传版本包 → 校验 SHA-256 → 解压新目录 → 执行向后兼容迁移 → 切换 current 软链接 → 重启服务 → 检查 `/health/live` 与 `/health/ready` → 冒烟测试。失败时切回上一个软链接；数据库迁移必须遵循 expand/contract，发布期间不得执行不可逆删除。

## 5.2 环境隔离

至少 development、staging、production。生产对象存储 bucket、数据库和密钥完全隔离。AI 内容状态为 draft → generated → auto_review_failed/pending_review → approved → staging → published → disabled。

## 5.3 中国大陆部署预留

若面向中国大陆大规模发行，需要预留国内对象存储/CDN、国内 API 节点、域名备案、渠道 SDK 和隐私合规配置。MVP 可先通过统一全球服务验证，但代码必须抽象 `StorageProvider`、`CDNProvider`、`AdProvider`、`BillingProvider` 和 `AnalyticsProvider`。

## 5.4 客户端缓存

启动先使用本地配置快照，再异步请求 bootstrap。预加载后续 2-3 关；图片采用 WebP，多规格资源；缓存默认上限 300MB，LRU 清理。下载完成后校验 sha256，关卡开始前保证两张图都可用。

## 5.5 监控

API：请求量、P95/P99、5xx、数据库连接、Redis 错误、资源下载失败。
Worker：队列长度、生成成功率、单关成本、质检失败分布、重试次数。
业务：D1/D7、关卡开始/完成、提示率、广告完成率、ARPDAU、购买转化、崩溃率、内容举报率。

## 5.6 备份与恢复

MySQL 每日全量并保留增量日志；对象存储开启版本控制；配置与迁移脚本入 Git；Redis 不作为唯一数据源。必须至少每季度演练一次从备份恢复 staging。

## 5.7 发布

服务端采用滚动或蓝绿发布；数据库迁移遵循向后兼容：先加字段/表，再上线新代码，最后清理旧字段。远程配置支持草稿、审批、灰度、定时发布和一键回滚。

单机 MVP 不宣称真正蓝绿：systemd 重启会有短暂连接切换。需要零停机时，在同机运行两个 API 端口，由 Nginx upstream 切换并完成健康检查；访问量增长后再增加第二台 API 主机。

部署模板位于 `deploy/`。其中域名、证书路径、安装路径和服务用户均为变量，投入生产前必须替换示例值。
