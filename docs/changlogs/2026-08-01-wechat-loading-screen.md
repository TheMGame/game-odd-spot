# 2026-08-01 微信小游戏品牌加载页

## 变更目标

将 Godot 微信适配模板默认的黄色加载页和 Godot Logo，替换为《火眼金睛》品牌启动页，并在资源下载、WASM 编译和 PCK 加载期间展示健康游戏忠告。

## 页面内容

- 使用 `client/assets/branding/guagua-rabbit-logo.png` 作为启动 Logo；
- 展示游戏名“火眼金睛”；
- 展示“健康游戏忠告”及四行标准文案；
- 保留资源加载、编译和引擎初始化状态；
- 进度条前景色调整为品牌金色 `#e6b95c`；
- 保留分包失败后的重试/退出处理。

健康游戏忠告：

```text
抵制不良游戏，拒绝盗版游戏。
注意自我保护，谨防受骗上当。
适度游戏益脑，沉迷游戏伤身。
合理安排时间，享受健康生活。
```

## 持久化方式

修改 `client/tools/wechat/finalize_export.py`，使每次微信导出收尾时自动：

1. 向 `godot-loader.js` 注入品牌页 Canvas 绘制逻辑；
2. 将兔子 Logo 复制为 `images/oddspot-logo.png`；
3. 修改 `game.js` 的 Logo、可见性和进度条配置；
4. 校验健康忠告和品牌配置确实存在；
5. 保持重复执行结果一致。

`build/wechat` 已同步更新，但该目录仍是被 `.gitignore` 忽略的本地导出产物。

## 验证

```text
FINALIZE_EXPORT_OK
VERIFY_EXPORT_OK
```

并使用 `node --check` 验证了 `game.js` 与 `godot-loader.js` 的 JavaScript 语法。
