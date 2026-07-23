# Godot 客户端

使用 Godot 4.x 打开 `project.godot`。当前 Bootstrap 场景会：

1. 创建并持久化 installation_id。
2. 调用匿名会话接口。
3. 使用 Bearer token 调用 bootstrap。
4. 显示解析后的市场和语言。

点击“开始测试关卡”可进入 P0 可玩场景：

- 两张图片同步缩放和平移。
- 任意一张图均可点击圆形或多边形差异。
- 命中后两图同步标记，重复点击不重复计数。
- 提示会自动标出一个尚未找到的差异。
- 联网时上报 start/progress/complete；离线时仍可完成本地关卡。
- 远程测试图片尚未上传 CDN，因此 `global_demo_001` 使用打包内 SVG 资源。

## 离线同步

start、progress、complete 在发送前写入 `user://sync_queue.json`，每项保存稳定的 Idempotency-Key。队列严格按顺序重放；成功后删除，网络错误、401、408、429 和 5xx 会保留，其他确定性 4xx 会记录警告后丢弃。Bootstrap 和首页刷新都会触发同步。

本地 API 默认地址为 `http://127.0.0.1:8080`。Android 模拟器调试时应通过运行配置将其改为宿主机可访问地址，正式环境必须使用 HTTPS。
