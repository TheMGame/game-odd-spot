# 微信小游戏适配验证报告

## 状态

`VALIDATED`：代码侧适配、插件构建、项目解析、现有测试、普通 Web 导出、微信小游戏导出和产物验证均已完成。

## 环境

```text
OS: Windows
Godot: 4.7.stable.official.5b4e0cb0f（标准版）
Python: 3.14.3
SCons: 4.10.1
godot-minigame commit: 67cde32e26b539518c845feea557dddaf84f19ec
Godot template: minigame4.7.tpz
```

上游插件存在两条关于 RefCounted singleton 的未来兼容性警告，不影响本次插件加载和导出结果。

## 基线差异

- 实际 `asset_cache.gd` 缓存上限为 2 GB，不是任务书初始基线中的 300 MB；本次未擅自改变。
- 设置页“移除广告”入口在改动前已经全平台隐藏；本次增加了微信环境的底层 Mock 调用保护。
- 首次小游戏导出刷新远程模板索引失败，但插件成功下载并缓存 `minigame4.7.tpz`；使用缓存再次导出成功。
- 初始模板的 `engine/game.js` 默认加载 `empty-tips.bin`，且携带演示 MP3 清单；已增加自动收尾步骤，强制加载项目 `demo-pck.bin` 并清除模板音频残留。

## 修改内容

- `project.godot`：启用 `godot-minigame` 编辑器插件。
- `export_presets.cfg`：保留 Windows/Web，新增“小游戏” preset；Web 与小游戏分别排除不需要的编辑器和文档资源。
- `scripts/platform/platform.gd`：增加 Web-like 和微信小游戏 feature 判断。
- `scripts/api/api_client.gd`、`scripts/cache/asset_cache.gd`：Web 与小游戏共同关闭 HTTPRequest gzip 接受；增加安全的 Debug 图片 host 审计。
- `scripts/monetization/monetization.gd`、`scenes/game/game.gd`：微信环境阻断 Mock 广告/购买，并移除广告诱导文案。
- `tools/wechat/*`：增加锁文件、跨平台安装/导出脚本、产物收尾脚本和导出验证器。
- `docs/*`：增加使用说明、人工清单和本报告。

## 实际执行命令

```text
git status --short
git branch --show-current
git rev-parse HEAD
python -m pip install --user scons
client\tools\wechat\install_plugin.ps1
Godot_v4.7-stable_win64.exe --headless --editor --path client --quit
Godot_v4.7-stable_win64.exe --headless --path client --script res://tests/run_unit_tests.gd
Godot_v4.7-stable_win64.exe --headless --path client --script res://tests/run_smoke.gd
client\tools\wechat\export_wechat.ps1
python client\tools\wechat\finalize_export.py build\wechat
python client\tools\wechat\verify_export.py build\wechat
Godot_v4.7-stable_win64.exe --headless --path client --export-release Web build\web\index.html
```

## 测试结果

```text
PASS: godot-minigame Windows x86_64/x86_32 构建
PASS: 插件安装和 commit 校验
PASS: Godot 4.7 项目解析及插件加载
PASS: run_unit_tests.gd
PASS: run_smoke.gd
PASS: 普通 Web 导出及自定义 Shell
PASS: 微信小游戏导出
PASS: 模板演示包和演示原生音频残留清理
PASS: verify_export.py（VERIFY_EXPORT_OK）
```

## 微信导出物

```text
输出目录: build/wechat/
文件数: 25
总大小: 19,958,962 bytes
最大文件: engine/demo-pck.bin（10,954,812 bytes）
wasm.br: 是，engine/godot.wasm.br
pck/bin: 是，engine/demo-pck.bin
AppID: wx0000000000000000（占位值）
```

## 阻塞与跳过

```text
BLOCKED: 上传或正式微信开发者工具编译需要真实 AppID
BLOCKED: 当前机器未安装微信开发者工具，无法在该 GUI 中执行导入和编译
SKIPPED: 当前环境未执行微信后台配置
SKIPPED: Android/iPhone 真机预览
SKIPPED: 上传体验版和提交审核（不在授权范围）
```

## 人工下一步

1. 取得正式 AppID，并在 Godot“小游戏”导出项中替换占位值。
2. 在微信后台配置两个 API 域名以及生产关卡响应中的全部图片 host。
3. 用微信开发者工具导入 `build/wechat/`，完成编译和真机验收。
