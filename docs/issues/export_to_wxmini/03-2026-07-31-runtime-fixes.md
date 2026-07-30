# 2026-07-31 微信小游戏运行期问题修复记录

## 1. 文档目的

本文记录 2026-07-31 在 Godot 4.6 微信小游戏真机与微信开发者工具测试中发现并修复的运行期问题。

本日处理的内容不再属于此前的 WASM 编译、异常处理模型或分包加载问题。进入本轮测试时，引擎已经可以在 iPhone 上完成：

```text
engine subpackage ready
engine init
Engine has started!
```

本轮问题发生在 Godot 引擎启动之后，主要包括：

1. 节点已经离开 SceneTree 后仍被调用 `can_process()`；
2. 微信小游戏不支持浏览器标准振动接口；
3. `user://` 中空文件或不完整 JSON 导致 `JSON.parse_string()` 输出红色错误。

最终正式微信包目录：

```text
build/wechat
```

## 2. 基础构建环境

本轮继续沿用已经通过 iPhone 验证的微信引擎组合：

| 项目 | 值 |
| --- | --- |
| Godot | 4.6.2 stable/对应 4.6.2 源码线 |
| Web 构建 | `threads=no` |
| SIMD | `wasm_simd=no` |
| Emscripten | 4.0.10 |
| longjmp | `SUPPORT_LONGJMP='emscripten'` |
| 微信基础库 | 3.17.0 |
| 引擎补丁 | `godothub/godot-minigame` 公共补丁 + 本项目生命周期补丁 |

重要说明：

- 本轮没有重新切换到 Godot 4.7；
- Web 版本仍使用原有 Godot Web 流程；
- 微信专用 C++ 改动只进入微信自编译引擎；
- 应用层的振动和 JSON 修改同时保持普通 Web 行为。

## 3. 问题一：离树节点触发 `can_process()` 错误

### 3.1 现象

真机进入游戏后，vConsole 持续出现：

```text
ERROR: Condition "!is_inside_tree()" is true. Returning: false
at: can_process (scene/main/node.cpp:902)
```

最初错误会大量重复。第一轮修复后，重复日志减少，但进入关卡或产生触摸输入时仍会出现一次。

### 3.2 为什么不是 WASM 启动问题

错误之前已经输出：

```text
Engine has started!
```

同时画面、场景和网络功能已经可以运行。因此：

- WASM 已成功下载、解压和实例化；
- Godot 主循环已经启动；
- PCK 已加载；
- 错误发生在 SceneTree 节点生命周期和输入分发阶段。

### 3.3 根本原因

Godot 的 Process Group 和 Input Group 为了允许回调过程中增删节点，会复制一份节点列表再迭代。

同一帧或同一个输入事件中可能发生以下顺序：

1. 节点列表快照已经生成；
2. 前一个节点的回调切换场景、移除子节点或调用 `queue_free()`；
3. 后续节点已经不在 SceneTree 中，但仍存在于当前快照；
4. 循环直接调用 `node->can_process()`；
5. `Node::can_process()` 要求节点必须位于 SceneTree 中，因此输出错误。

微信真机触摸事件较密集，使输入分发路径比桌面环境更容易暴露这一时序。

### 3.4 第一轮修复及遗漏

第一轮只修改了：

```text
SceneTree::_process_group()
```

原判断：

```cpp
if (!n->can_process() || !n->is_inside_tree()) {
    continue;
}
```

改为先检查节点生命周期：

```cpp
if (!n->is_inside_tree() || !n->can_process()) {
    continue;
}
```

这消除了帧处理循环中的大部分错误，但输入分发函数 `_call_input_pause()` 仍直接调用 `can_process()`，因此进入关卡或发生触摸时仍可能报错。

### 3.5 完整修复

完整修复分为三层。

#### 第一层：Process Group

```cpp
if (!n->is_inside_tree() || !n->can_process()) {
    continue;
}
```

#### 第二层：Input Group

在：

```text
SceneTree::_call_input_pause()
```

中同样先判断：

```cpp
if (!n->is_inside_tree() || !n->can_process()) {
    continue;
}
```

#### 第三层：`Node::can_process()` 最终防御

将离树节点视为不能处理，直接返回 `false`：

```cpp
bool Node::can_process() const {
    if (!is_inside_tree()) {
        return false;
    }
    return !data.tree->is_suspended() && _can_process(data.tree->is_paused());
}
```

这层防御确保尚未枚举到的异步、输入或平台调用路径也不会因为合法的同帧生命周期竞态刷出错误。

### 3.6 补丁位置

可复现补丁保存在：

```text
client/tools/wechat/patches/godot-4.6-scene-tree-node-lifecycle.patch
```

本地用于构建的源码目录位于：

```text
.tmp/godot-4.6-wechat-source
```

`.tmp` 已加入 `.gitignore`，不会提交；真正需要提交和长期维护的是上述 patch 文件。

### 3.7 引擎重编译

加载 Emscripten 环境：

```powershell
& .tmp/emsdk/emsdk_env.ps1
```

在 Godot 源码目录执行：

```powershell
python -m SCons platform=web target=template_release threads=no wasm_simd=no -j4
```

本轮属于增量构建，重新编译了：

```text
scene/main/node.cpp
scene/main/scene_tree.cpp
```

随后重新链接并生成微信 WASM。

### 3.8 正式引擎标识与校验值

控制台标识：

```text
build=20260731-can-process-guard
```

正式压缩 WASM：

```text
build/wechat/engine/godot-wechat-clean.wasm.br
```

SHA-256：

```text
25290D0478C52115DEE93253832FFBAFBC779B94550DB6D3E6D97DC8EAEDA308
```

## 4. 问题二：微信小游戏不支持浏览器振动 API

### 4.1 现象

找到不同点或触发振动反馈后出现：

```text
This browser does not support vibration.
```

### 4.2 原因

原代码直接调用：

```gdscript
Input.vibrate_handheld(35)
```

Godot Web 会尝试使用浏览器振动能力。微信小游戏虽然运行 WebAssembly 和 WebGL，但不是普通浏览器页面，不提供相同的 `navigator.vibrate` 能力。

微信小游戏提供自己的振动 API：

```javascript
wx.vibrateShort(...)
```

### 4.3 修复

在平台封装中区分微信和普通 Web：

```gdscript
static func vibrate_handheld(duration_ms := 35) -> void:
    if is_wechat_minigame():
        var wechat = JavaScriptBridge.get_interface("wx")
        if wechat != null:
            wechat.vibrateShort({"type": "light"})
        return
    Input.vibrate_handheld(duration_ms)
```

游戏调用改为：

```gdscript
Platform.vibrate_handheld(35)
```

### 4.4 修改文件

```text
client/scripts/platform/platform.gd
client/scenes/game/game.gd
```

### 4.5 对 Web 版本的影响

普通 Web 环境不会进入微信分支，仍执行：

```gdscript
Input.vibrate_handheld(duration_ms)
```

因此该修改不会破坏原有 Web 版本。

## 5. 问题三：启动阶段 JSON 解析错误

### 5.1 现象

新引擎生效并启动完成后，真机立即出现：

```text
ERROR: Parse JSON failed. Error at line 0:
Unknown error getting token
at: parse_string (core/io/json.cpp:624)
```

此时控制台已经显示：

```text
Engine has started!
```

因此同样不是 WASM 或引擎初始化失败。

### 5.2 根本原因

启动阶段多个 Autoload 会从 `user://` 读取持久化数据：

```text
user://session.json
user://progress.json
user://sync_queue.json
user://sync_dead_letters.json
user://analytics_queue.json
user://catalog_*.json
```

微信小游戏文件系统中可能出现以下情况：

- 文件已经创建，但长度为 0；
- 上一次体验版被关闭时写入未完成；
- 老版本留下了不完整或格式不兼容的数据；
- JavaScript 桥或 HTTP 请求在某个时刻返回空字符串。

原代码直接调用：

```gdscript
JSON.parse_string(text)
```

Godot 的 `JSON.parse_string()` 内部在解析失败时会执行错误输出，所以即使业务代码随后检查返回类型，vConsole 中仍会先出现红色错误。

### 5.3 修复方案

新增：

```text
client/scripts/utils/json_utils.gd
```

实现：

```gdscript
class_name JsonUtils
extends RefCounted

static func parse_string(text: String) -> Variant:
    var normalized := text.strip_edges()
    if normalized.is_empty():
        return null
    var parser := JSON.new()
    if parser.parse(normalized) != OK:
        return null
    return parser.get_data()
```

处理原则：

1. 空字符串直接返回 `null`；
2. 使用 `JSON.new().parse()` 获取错误码；
3. 非法 JSON 返回 `null`，不调用会主动输出错误的便捷函数；
4. 原调用方继续进行 Dictionary/Array 类型检查；
5. 损坏缓存被忽略，随后由远端请求或正常保存覆盖。

### 5.4 覆盖范围

所有业务代码中的 `JSON.parse_string()` 已替换为安全入口，包括：

```text
client/scripts/storage/session_store.gd
client/scripts/storage/progress_store.gd
client/scripts/storage/sync_queue.gd
client/scripts/analytics/analytics.gd
client/scripts/catalog/catalog_repository.gd
client/scripts/api/api_client.gd
```

这同时保护：

- 本地 Session；
- 本地游戏进度；
- 待同步和死信队列；
- 埋点缓存；
- Catalog 缓存；
- 微信登录 JavaScript 桥；
- user_server 和 oddspot API 的 HTTP JSON 响应。

### 5.5 为什么不直接删除用户数据

修复没有在启动时清空整个 `user://`，原因是：

- Session 中可能包含仍然有效的登录信息；
- 进度和同步队列可能包含尚未上传的数据；
- 全量删除会造成不必要的数据损失；
- 安全忽略单个损坏内容即可恢复启动。

对于无法解析的文件，当前版本只不加载该内容，后续正常保存时会覆盖它。

### 5.6 PCK 重导出

JSON 修复属于 GDScript 应用层修改，不需要再次编译 Godot C++ 引擎，但必须重新生成 PCK。

使用 Godot 4.6.2 执行：

```powershell
Godot_v4.6.2-stable_win64_console.exe `
  --headless `
  --path .tmp/client-wechat-46 `
  --export-pack Web `
  ../game-odd-spot-46-json-guard.pck
```

正式 PCK：

```text
build/wechat/subpackages/project/demo-pck.bin
```

项目包标识：

```text
build=20260731-json-guard
```

PCK SHA-256：

```text
D58BFA4320110F1018FEE7B540DC3F1A56DA55D1EC28CC46B1AAD86C688D9844
```

## 6. 最终验证

### 6.1 自动验证

执行：

```powershell
python client/tools/wechat/verify_export.py build/wechat
```

结果：

```text
VERIFY_EXPORT_OK
```

验证内容包括：

- 微信包关键文件存在；
- 分包 PCK 存在且尺寸合理；
- Brotli WASM 可以解压；
- WASM 头和 section 合法；
- `WebAssembly.validate()` 成功；
- 不包含导致旧微信运行时失败的异常 section 13。

### 6.2 Godot PCK 冒烟测试

使用 Godot 4.6.2 直接加载正式 PCK：

```powershell
Godot_v4.6.2-stable_win64_console.exe `
  --headless `
  --main-pack build/wechat/subpackages/project/demo-pck.bin `
  --quit-after 3
```

项目脚本可解析并启动。强制退出时可能出现 ObjectDB leaked warning，这是 `--quit-after` 提前结束造成的测试退出提示，不是微信运行错误。

### 6.3 开发者工具和真机复测

每次替换引擎或 PCK 后，应在微信开发者工具执行：

```text
清缓存 -> 全部清除 -> 重新编译
```

控制台必须同时出现：

```text
build=20260731-can-process-guard
build=20260731-json-guard
```

若标识不同，说明开发者工具或体验版仍在运行旧包。

真机验收项目：

1. 引擎输出 `Engine has started!`；
2. 不再出现 `!is_inside_tree()` / `can_process()` 红色错误；
3. 不再出现浏览器不支持振动警告；
4. 不再出现 `Parse JSON failed`；
5. 微信登录、首页、关卡列表和关卡进入正常；
6. 点击不同点时微信振动正常或静默失败，不影响游戏；
7. 退出并再次进入后，Session 和进度仍可恢复；
8. 普通 Web 登录和游戏流程继续正常。

## 7. 本日修改清单

### 7.1 Godot 引擎补丁

```text
client/tools/wechat/patches/godot-4.6-scene-tree-node-lifecycle.patch
```

补丁涉及上游源码：

```text
scene/main/scene_tree.cpp
scene/main/node.cpp
```

### 7.2 应用层源码

```text
client/scenes/game/game.gd
client/scripts/platform/platform.gd
client/scripts/utils/json_utils.gd
client/scripts/api/api_client.gd
client/scripts/storage/session_store.gd
client/scripts/storage/progress_store.gd
client/scripts/storage/sync_queue.gd
client/scripts/analytics/analytics.gd
client/scripts/catalog/catalog_repository.gd
```

### 7.3 导出验证

```text
client/tools/wechat/verify_export.py
```

该脚本在此前基础上继续用于校验最终微信包，不应只依据开发者工具界面是否出现画面判断产物有效。

### 7.4 正式产物

正式产物位于：

```text
build/wechat
```

该目录属于本地导出产物并已被 `.gitignore` 忽略。仓库提交的是：

- Godot 源码补丁；
- GDScript 平台适配和安全解析；
- 构建、问题和变更文档；
- 导出校验工具。

## 8. 后续维护规则

1. 重新拉取 Godot 4.6 源码后，必须重新应用生命周期 patch；
2. 不要用未验证的 Godot 4.7 WASM 覆盖当前 4.6 微信引擎；
3. 新增 JSON 持久化文件时统一使用 `JsonUtils.parse_string()`；
4. 微信平台能力统一放入 `Platform` 或微信 JavaScript 适配层，不在游戏场景中直接假设浏览器 API；
5. 每次更新引擎和 PCK 都修改控制台构建标识；
6. 上传体验版前必须运行 `verify_export.py`；
7. 开发者工具成功不等于真机成功，最终必须使用 iPhone/Android 体验版复测；
8. 如再次出现引擎红色错误，应先确认错误发生在 `Engine has started!` 之前还是之后，以区分 WASM 启动问题和应用运行期问题。
