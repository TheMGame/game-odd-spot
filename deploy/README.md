# Deployment

当前 Ubuntu 原生部署模板位于设计包：

- `../docs/ai_spot_difference_solution/deploy/oddspot-api.service`
- `../docs/ai_spot_difference_solution/deploy/oddspot-worker.service`
- `../docs/ai_spot_difference_solution/deploy/nginx.oddspot.conf`
- `../docs/ai_spot_difference_solution/deploy/deploy-release.sh`

等 `server/cmd/migrate` 接入真实 MySQL 迁移后，再将经过服务器验证的模板提升到本目录作为正式部署资产。当前不使用 Docker。
