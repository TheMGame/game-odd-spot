# 错位大侦探：原生 Web 客户端

`webgame/` 是 `wechat/` 原生客户端的浏览器等价版本。它不使用 Godot、WASM 或 PCK，浏览器直接加载一个轻量 JavaScript 包和 Canvas，远程关卡仍使用现有生产 API 与同一份关卡数据。

## 已对齐功能

- Godot 客户端同款邮箱密码登录。
- 邮箱验证码登录/注册、资料完善、Session 恢复与退出登录。
- 系列首页、每日挑战、选关、完成状态与顺序解锁。
- `find_anachronism` 与 `image_puzzle` 两种模式；拼图直接显示错位棋盘。

正式打包：

```powershell
.\scripts\package-native-webgame.ps1 -Version 0.2.0
```

运行目录输出到 `build/webgame/`，发布压缩包和校验文件输出到 `build/packages/`。`build/web/` 保留给 Godot Web 导出，不要混用。
JavaScript bundle 的中间产物生成在 `build/.webgame-bundle/`，不会写回源码目录。
- 圆形/多边形命中、提示、解释、通关、重玩和下一关。
- 手机双指缩放、拖动；桌面鼠标拖动和滚轮缩放。
- 每账号每天 3 次免费提示。
- 本地进度、离线写入队列、幂等提交、死信记录与恢复同步。
- 音乐、音效、触感反馈、加大标记、匿名分析、双语、隐私政策。
- 图片 SHA-256 校验、浏览器缓存、下一关预取。
- Logo、默认头像、兔子动画及四个 WAV 与现有客户端文件一致。

Web 版本没有微信登录、微信授权、微信分包或任何 `wx.*` 依赖。

## 本地运行

首次安装和检查：

```bash
cd webgame
npm install
npm run check
```

启动任意静态 HTTP 服务，例如：

```bash
npx serve .
```

不要直接双击 `index.html`，浏览器的 Service Worker 和部分资源校验能力要求通过 HTTP/HTTPS 访问。

## 部署

整个 `webgame/` 都是静态文件，可直接放到 Nginx、对象存储或 CDN。入口是 `index.html`，无需 Node.js 运行时。

生产环境需要保证以下两个服务允许 Web 域名跨域访问：

- `https://oddspot.guaguatu.com`
- `https://api.guaguatu.com`

如需切换地址，在加载 `app.bundle.js` 前设置：

```html
<script>
window.ODDSPOT_CONFIG = {
  API_BASE_URL: 'https://oddspot.guaguatu.com',
  USER_SERVER_BASE_URL: 'https://api.guaguatu.com'
}
</script>
```

建议对 `index.html` 使用短缓存或 `no-cache`，对 `app.bundle.js`、图片和音频使用 CDN 缓存。Service Worker 会缓存首屏外壳和已访问的本地素材，使二次打开更快。
