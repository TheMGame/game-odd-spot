# 微信小游戏人工操作与真机清单

以下步骤必须由拥有微信账号、AppID 和设备的人员完成。

## 微信后台

- [ ] 创建微信小游戏并取得正式 AppID
- [ ] AppSecret 只保存在服务端安全环境，不写入客户端
- [ ] 添加 request 合法域名：
  - `https://oddspot.guaguatu.com`
  - `https://api.guaguatu.com`
- [ ] 从生产 Catalog/关卡响应采集全部实际图片 host，并加入 request 合法域名
- [ ] 确认 iOS 高性能模式配置
- [ ] 配置隐私保护指引、用户协议和隐私政策

静态代码表明生产资源 URL 会由服务端规范化到 `https://oddspot.guaguatu.com`，但仍需通过真实生产响应确认。Debug 构建会以 `[WechatDomainAudit] asset host: <scheme+host>` 记录首次出现的图片 host，不打印 query、Token 或 Authorization Header。

## Godot

- [ ] 执行插件安装脚本
- [ ] 打开 `client/project.godot` 并确认 `godot-minigame` 已启用
- [ ] 确认模板为 Godot 4.7.0 / `minigame4.7.tpz`
- [ ] 在“小游戏”导出项填写正式 AppID
- [ ] 导出到 `build/wechat/`
- [ ] 运行 `verify_export.py` 并确认 `VERIFY_EXPORT_OK`

## 微信开发者工具

- [ ] 创建或导入“小游戏”项目
- [ ] 项目目录选择 `build/wechat/`
- [ ] 编译并检查控制台无错误
- [ ] Android 真机预览
- [ ] iPhone 真机预览
- [ ] 测试前后台切换
- [ ] 杀进程后重新进入
- [ ] 上传体验版
- [ ] 体验版验收后再提交审核

## 真机验收

### 启动

- [ ] 启动不黑屏
- [ ] Logo、启动色和中文字体正常
- [ ] 竖屏方向正确
- [ ] 刘海、圆角和底部手势区不遮挡按钮
- [ ] 首次启动时间可接受

### 登录与会话

- [ ] 用户名密码登录成功
- [ ] 邮箱验证码流程正常
- [ ] Token 交换和刷新成功
- [ ] 退出登录成功
- [ ] 杀进程后 Session 可恢复
- [ ] 日志不打印 Token

### 网络

- [ ] bootstrap、home、catalog 成功
- [ ] level detail、start、progress、complete 成功
- [ ] 401 刷新后可重试
- [ ] 408/429/5xx 正确重试或入队
- [ ] 断网错误可理解，恢复网络后队列可重放

### 资源

- [ ] 两张关卡图可下载且 SHA-256 校验成功
- [ ] WebP 和 JPEG 解码成功
- [ ] 缓存命中成功
- [ ] 杀进程后缓存仍可用
- [ ] 缓存损坏后可重新下载
- [ ] 大图不会闪退
- [ ] 全部图片 host 已加入合法域名

### 玩法

- [ ] 双图同步缩放和平移
- [ ] 点击坐标正确
- [ ] 圆形和多边形差异可命中
- [ ] 重复点击不重复计数
- [ ] 提示及完成关卡正常
- [ ] 前后台切换后计时合理

### 商业化

- [ ] 微信环境不显示 Mock 广告或购买入口
- [ ] 不调用 `provider=mock` 的正式奖励
- [ ] 不调用 `platform=mock` 的正式购买验证

## 后续独立功能

本次已实现 `wx.login` 微信小游戏登录。尚未实现：微信分享、激励视频广告、微信虚拟支付、开放数据域排行榜、订阅消息、云开发、渠道统计、自动上传和自动提交审核。
