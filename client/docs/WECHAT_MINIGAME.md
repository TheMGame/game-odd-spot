# 微信小游戏导出

本项目保留原有 Windows 与 Web 导出，同时增加 Godot 4.7 微信小游戏导出。普通 Web 继续使用 `res://web/shell.html`；微信小游戏使用独立的“小游戏” preset 和 `wechat_minigame` feature。

## 环境

- Godot 4.7 标准版
- Python 3
- SCons
- Git
- 微信开发者工具（导入和真机预览时需要）

插件版本锁定在 `tools/wechat/godot-minigame.lock`。安装脚本只安装该 commit，不会自动更新 lock。

## 安装插件

Windows：

```powershell
client\tools\wechat\install_plugin.ps1
```

macOS/Linux：

```bash
client/tools/wechat/install_plugin.sh
```

新的工作副本必须先安装插件，再打开 `client/project.godot`。

## 导出

小游戏 preset 中的 AppID 默认为占位值：

```text
wx0000000000000000
```

该占位值可以生成本地测试工程，但不能上传。正式导出前，在 Godot 的“小游戏”导出项中填写真实 AppID。不要把 AppSecret 写进客户端或仓库。

Windows：

```powershell
$env:GODOT_BIN="C:\path\to\Godot_v4.7-stable_win64.exe"
client\tools\wechat\export_wechat.ps1
```

macOS/Linux：

```bash
GODOT_BIN=/path/to/godot client/tools/wechat/export_wechat.sh
```

输出目录：

```text
build/wechat/
```

验证已有 GUI 导出物：

```powershell
python client\tools\wechat\verify_export.py build\wechat
```

成功时打印 `VERIFY_EXPORT_OK`。

导出脚本会在验证前自动执行 `finalize_export.py`，用于：

- 让 `engine/game.js` 加载项目的 `engine/demo-pck.bin`，而不是模板演示包；
- 清理模板自带的 `empty-tips.bin`；
- 用项目导出的原生音频清单覆盖模板演示音频清单；
- 删除不再被清单引用的模板音频文件。

## Web 共存

Web preset 保持以下行为：

- 继续使用 `res://web/shell.html`；
- 继续关闭线程；
- 不打包小游戏编辑器插件、工具脚本和发布文档；
- Web 与小游戏共同使用 `Platform.is_web_like()` 处理 HTTP 压缩限制；
- 仅小游戏使用 `Platform.is_wechat_minigame()` 隔离 Mock 广告和购买。

## 微信开发者工具

选择“小游戏”项目并导入 `build/wechat/`。该目录必须直接包含：

```text
project.config.json
game.js
game.json
engine/godot.wasm.br
engine/demo-pck.bin
```
