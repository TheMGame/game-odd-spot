# Odd Spot

AI 多地区找茬游戏 Monorepo，包含可运行的 Godot 客户端、Go/MySQL API、内容 Worker、静态管理后台和 Ubuntu 原生部署脚本。

## 当前运行模式

- 客户端采用账号登录：账号服务登录成功后，由 Odd Spot API 交换游戏 Session。服务端仍保留匿名会话 API，但当前 Godot 启动流程不会自动创建匿名账号。
- Bootstrap 加载已有 Session，必要时刷新 token，随后请求 `/v1/bootstrap`、重放同步队列；有效 Session 进入首页，无 Session 进入登录页。临时网络故障不会清空登录状态。
- Catalog 使用内存与磁盘缓存，远程图片使用最高 2 GiB 的本地磁盘缓存（超限后最旧优先淘汰）；已发布图片响应允许浏览器/CDN 缓存一年。客户端不内置备用关卡，首次使用必须联网。
- 关卡写入支持 `synced`、`queued`、`rejected` 三种结果；确定性 4xx 不会被显示为服务端完成。

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

该命令运行 Go test/vet、Godot 导入、场景冒烟测试和客户端单元测试。PR 与 `master` push 还会通过 `.github/workflows/ci.yml` 验证 Go、Godot 和 contracts 样例。

打开 `client/project.godot` 可运行游戏。客户端默认连接生产 API；本地联调可设置 `ODDSPOT_API_BASE_URL=http://127.0.0.1:8080`。后端配置环境变量后执行：

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
