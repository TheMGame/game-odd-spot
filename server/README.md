# Odd Spot Go 服务端

包含 `api`、`worker` 和 `migrate` 三个命令。配置 MySQL 后，身份、会话、关卡进度、奖励、配置、内容审核、分析、运营和生成任务均持久化；development/test 可使用内存实现。

```powershell
go test ./...
go vet ./...
go run ./cmd/api
```

数据库迁移：

```powershell
$env:ODDSPOT_DATABASE_DSN='user:password@tcp(host:port)/database?parseTime=true&charset=utf8mb4&loc=UTC'
$env:ODDSPOT_INSTALLATION_HMAC_KEY='至少 32 字符的独立随机密钥'
go run ./cmd/migrate
```

安全约束：DSN、HMAC 和管理令牌只通过环境或服务器 Secret 文件提供；installation ID 仅存 HMAC-SHA256；access/refresh token 仅存 SHA-256；写操作使用稳定 `Idempotency-Key`。生产环境拒绝测试账号、Mock 广告和 Mock 购买凭据。

设置 `ODDSPOT_TEST_MYSQL_DSN` 后可运行真实 MySQL 集成测试：

```powershell
go test ./internal/httpapi -run TestMySQLAccountRestoreReportAndMetrics -v
go test ./internal/level -run TestRemoteLevelFlow -v
go test ./internal/generation -run TestWorkerProcessesJob -v
```
