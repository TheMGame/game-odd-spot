# Odd Spot

AI 多地区找茬游戏 Monorepo，包含可运行的 Godot 客户端、Go/MySQL API、内容 Worker、静态管理后台和 Ubuntu 原生部署脚本。

## 代码位置

- `client/`：Godot 4.7 客户端（前端）。
- `server/`：Go API、Worker、数据库迁移（后端）。
- `admin/`：静态 CMS 管理后台。
- `contracts/`：OpenAPI、关卡 JSON Schema 和示例。
- `docs/ai_spot_difference_solution/`：产品、架构、数据和部署设计。
- `scripts/`：全量测试与 Linux 发布包构建。

## 本地验证

```powershell
.\scripts\test-all.ps1
```

打开 `client/project.godot` 可运行游戏。后端配置环境变量后执行：

```powershell
cd server
go run ./cmd/migrate
go run ./cmd/api
```

生成 Ubuntu amd64 发布包：

```powershell
.\scripts\build-release.ps1
```

生产部署不使用 Docker，发布包内包含 systemd、nginx、备份和 smoke test 模板。测试账号、Mock 广告和 Mock 购买仅在 development/test 环境启用；生产环境需要接入实际平台验证器。
