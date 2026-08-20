# 错位大侦探：原生微信小游戏客户端

当前修复包版本：`0.1.1-media-entry-fixed`。解压后可通过根目录的
`BUILD_VERSION.txt` 确认版本；`subpackages/media/game.js` 必须存在。

这是 `client/` Godot 客户端的原生微信小游戏等价实现。它不包含 Godot、WASM 或 PCK，直接使用微信小游戏 Canvas、网络、文件缓存、音频、登录、触摸和震动 API。

## 已对齐能力

- 微信登录：`wx.getUserProfile`（用户可拒绝）→ `wx.login` → `user_server` → 游戏 Session。
- 启动：恢复/刷新 Session、Bootstrap、离线进度重放。
- 首页：动态系列、每日挑战、封面渐进加载、设置入口、同步状态。
- 选关：服务端目录、缩略图、完成状态、顺序解锁和锁定提示。
- 游戏：`find_anachronism` 与 `image_puzzle`、圆形/多边形判定、拼图点击交换、双指缩放、拖动、标记动画、发现说明、举报协议预留。
- 提示：按账号和业务日期每天 3 次免费提示，次数用完弹窗。
- 完成：进度/完成提交、幂等键、离线队列、拒绝死信、下一关预取、重玩/地图/下一关。
- 设置：震动、背景音乐、音效、大标记、匿名分析、中文/英文、隐私政策、退出登录。
- 素材：原样复制 `client/assets/branding` 和 `client/assets/audio`；远程关卡图片继续使用同一 Catalog/Level 数据。
- 声音：原样复用 `ui_click.wav`、`correct.wav`、`complete.wav`、`quiet_search_loop.wav`。
- 分包：背景音乐和通关音效位于原生 `media` 分包，文件内容保持不变，避免挤占首包；登录页 Logo 与首页默认头像保留在首包。

## 微信开发者工具

1. 选择“导入项目”，目录选择本 `wechat/`。
2. AppID 已与现有项目保持一致：`wx80a481e147abda26`。
3. 请求合法域名至少配置：
   - `https://oddspot.guaguatu.com`
   - `https://api.guaguatu.com`
4. 下载文件域名需覆盖生产 Catalog 实际返回的图片域名；当前服务端会把内容资源规范化到 `https://oddspot.guaguatu.com`。
5. 开发者工具调试可临时关闭合法域名校验，体验版/正式版必须在微信后台配置。

不要把 AppSecret 写入本目录。AppSecret 只保存在 `user_server` 的服务端配置中。

## 本地检查

```bash
cd wechat
npm run check
```

自动检查覆盖 JavaScript 语法、关卡校验、圆形/多边形基础逻辑、Session、按账号隔离的本地进度和版本完成状态。微信登录、合法域名、真机音频、内存峰值与上传仍必须在微信开发者工具和真机中验证。

## 与旧导出链路的关系

`client/` 保留为 Godot/Web 客户端；`wechat/` 是独立的微信小游戏客户端。二者共用服务端协议和内容资产，但不共享运行时，因此以后更新业务时应同时运行 Godot 测试和 `wechat/npm run check`。
