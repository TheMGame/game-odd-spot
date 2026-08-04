# 错位大侦探 Go 服务端

包含 `api`、`worker` 和 `migrate` 三个命令。配置 MySQL 后，身份、会话、关卡进度、奖励、配置、内容审核、分析、运营和生成任务均持久化；development/test 可使用内存实现。

Godot 客户端当前通过账号服务登录，再调用 `/v1/sessions/user-server` 换取游戏 access/refresh token。`/v1/sessions/anonymous` 是兼容 API，但不是当前客户端 Bootstrap 的默认入口。只有明确的无效 refresh token 响应才应使客户端清除 Session。

```powershell
go test ./...
go vet ./...
go run ./cmd/api
```

仓库根目录的 `scripts/test-all.ps1` 还会运行 Godot 导入、场景冒烟测试和客户端单元测试；CI 同时校验 contracts 合法/非法样例。

数据库迁移：

```powershell
$env:ODDSPOT_DATABASE_DSN='user:password@tcp(host:port)/database?parseTime=true&charset=utf8mb4&loc=UTC'
$env:ODDSPOT_INSTALLATION_HMAC_KEY='至少 32 字符的独立随机密钥'
go run ./cmd/migrate
```

Windows 可直接使用本地环境文件启动三个命令：

```powershell
..\scripts\run-windows.ps1 -Target migrate
..\scripts\run-windows.ps1 -Target api
..\scripts\run-windows.ps1 -Target worker
```

Linux 源码环境使用 `scripts/run-linux.sh api|worker|migrate server/.env.linux`；正式发布时 systemd 从 `/etc/oddspot/oddspot.env` 加载同一组变量。

交叉编译发布包：

```powershell
# 在 Windows 上同时构建 Windows/Linux amd64
.\scripts\build-cross-windows.ps1 -TargetOS all -Arch amd64 -Version 1.0.0

# 只构建 Ubuntu arm64
.\scripts\build-cross-windows.ps1 -TargetOS linux -Arch arm64 -Version 1.0.0
```

```bash
# 在 Linux 上同时构建 Windows/Linux amd64
./scripts/build-cross-linux.sh all amd64 1.0.0

# 只构建 Windows arm64
./scripts/build-cross-linux.sh windows arm64 1.0.0
```

输出位于 `build/cross/`，每个包均包含 API、Worker、迁移器、Admin 静态文件、素材目录、环境配置样例以及 SHA-256 校验文件。

安全约束：DSN、HMAC 和管理令牌只通过环境或服务器 Secret 文件提供；installation ID 仅存 HMAC-SHA256；access/refresh token 仅存 SHA-256；写操作使用稳定 `Idempotency-Key`。生产环境拒绝测试账号、Mock 广告和 Mock 购买凭据。

设置 `ODDSPOT_TEST_MYSQL_DSN` 后可运行真实 MySQL 集成测试：

```powershell
go test ./internal/httpapi -run TestMySQLAccountRestoreReportAndMetrics -v
go test ./internal/level -run TestRemoteLevelFlow -v
go test ./internal/generation -run TestWorkerProcessesJob -v
```

## 动态内容

- 玩家目录：`GET /v1/catalog`
- 已发布关卡：`GET /v1/levels/{levelId}`
- 图片资源：`GET /content/{asset}`
- 管理后台：`http://127.0.0.1:8080/admin/`
- 管理 API：`/admin/v1/catalog`、`/admin/v1/series`、`/admin/v1/levels/{levelId}`、`/admin/v1/assets/{assetId}`

客户端对 `/v1/catalog` 使用内存/磁盘缓存和短 TTL。start、progress、complete 写请求携带稳定 `Idempotency-Key`；2xx 为 `synced`，网络错误、401、408、429 和 5xx 为 `queued`，其余确定性 4xx 为 `rejected`。

本地服务设置 `ODDSPOT_PUBLIC_BASE_URL=http://127.0.0.1:8080`，线上设置为公开 HTTPS API 或 CDN 域名。Godot 编辑器、Debug 包和 Release 包默认连接 `client/project.godot` 中的生产地址；仅在本地联调时通过 `ODDSPOT_API_BASE_URL` 环境变量显式覆盖。

迁移并启动 API 后，可通过 Admin API 导入当前历史系列：

```powershell
.\scripts\import-local-content.ps1
```
