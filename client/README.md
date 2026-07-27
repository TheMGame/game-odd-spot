# Godot 客户端

使用 Godot 4.x 打开 `project.godot`。当前使用账号登录模式，不会自动创建匿名账号。Bootstrap 场景会：

1. 由 `SessionStore` 创建并持久化 installation_id。
2. 加载已有 Session；必要时刷新 access token。
3. 使用 Bearer token 调用 bootstrap。
4. 重放当前账号的待同步队列。
5. 有效 Session 进入首页，无 Session 进入登录页；临时网络错误保留 Session 并提供重试。

点击“开始测试关卡”可进入 P0 可玩场景：

- 两张图片同步缩放和平移。
- 任意一张图均可点击圆形或多边形差异。
- 命中后两图同步标记，重复点击不重复计数。
- 提示会自动标出一个尚未找到的差异。
- 关卡目录、关卡数据和图片全部从服务端读取，客户端不内置备用关卡。

## 离线同步

start、progress、complete 在发送前写入 `user://sync_queue.json`，每项保存稳定的 Idempotency-Key。队列严格按顺序重放：

- `synced`：服务端已返回 2xx。
- `queued`：网络错误、401、408、429 或 5xx，保留等待重试。
- `rejected`：确定性 4xx，当前提交者会收到拒绝结果，并保存到有上限的 `user://sync_dead_letters.json`。

Catalog 使用内存和磁盘缓存；已访问的关卡图片使用带 SHA-256 校验的磁盘缓存。首次安装且尚未缓存内容时，必须联网完成加载，客户端不内置备用关卡。

本地检查运行 `scripts/test-all.ps1`，包括 Go test/vet、Godot 场景冒烟测试和客户端单元测试。PR 与 master push 也会运行相同类别的 CI 检查。

客户端默认连接生产 API `https://oddspot.guaguatu.com`。仅在需要本地调试时，通过运行环境变量 `ODDSPOT_API_BASE_URL` 显式覆盖，例如 `http://127.0.0.1:8080`；Android 模拟器应填写宿主机可访问地址。
