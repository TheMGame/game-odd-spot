# Ubuntu 原生部署

目标系统为 Ubuntu 22.04/24.04 amd64，不使用 Docker。服务器预装 Nginx、MySQL 8、Redis 7、CA 证书和 systemd。生产环境推荐使用托管 MySQL；若同机安装，必须单独配置备份和磁盘告警。

## 发布包

CI 输出 `oddspot-<version>-linux-amd64.tar.gz` 和同名 `.sha256`。压缩包必须包含：

```
bin/oddspot-api
bin/oddspot-worker
bin/oddspot-migrate
admin/
migrations/
VERSION
```

Go 二进制通过 `CGO_ENABLED=0 GOOS=linux GOARCH=amd64` 构建。VERSION 使用 Git commit 或语义化版本。禁止上传 `.env`、证书和数据库备份到发布包。

## 首次安装

1. 创建系统用户 `oddspot`，目录 `/opt/oddspot/releases`、`/var/lib/oddspot` 和 `/etc/oddspot`。
2. 将 `oddspot-api.service`、`oddspot-worker.service` 安装到 `/etc/systemd/system/`。
3. 将环境文件按 `oddspot.env.example` 创建为 `/etc/oddspot/oddspot.env`，权限设为 root:oddspot 0640。API、Worker 和部署期 Migrate 共用该文件。
4. 安装并修改 Nginx 配置，使用 ACME 客户端签发证书。
5. 上传发布包后运行 `deploy-release.sh <archive> <sha256-file>`。

首次安装可在 deploy 目录以 root 运行 `install-first-time.sh`。发布完成后运行 `smoke-test.sh https://api.game.example.com`。数据库备份通过 root-only 环境提供凭据后运行 `backup-db.sh`；脚本不会自动删除历史备份。

## 发布门禁

- 迁移脚本支持 `status` 和 `up`，并使用数据库 advisory lock 防并发。
- API `/health/live` 只表示进程存活；`/health/ready` 检查数据库、Redis 和必要配置。
- 冒烟测试至少覆盖 session、bootstrap、home 和一个关卡资源 HEAD 请求。
- 保留最近 5 个版本；只在确认没有进程引用且备份完成后人工清理旧版本。
- 回滚应用版本时不得自动回滚数据库；数据库必须保持前后两个应用版本兼容。
