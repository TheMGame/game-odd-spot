# game-odd-spot 导出微信小游戏：根因与解决方案

> 记录日期：2026-07-30  
> 适用项目：`game-odd-spot`  
> 最终状态：正式游戏包已在微信开发者工具和 iPhone 微信体验版中启动成功

## 1. 问题概述

`game-odd-spot` 原本是 Godot 4.7 Web 项目。普通 Web 版本可以正常运行，但通过第三方 Godot 微信小游戏适配器导出后，出现了明显的环境差异：

- 微信开发者工具中可能正常运行；
- 上传体验版后，iPhone 真机无法完成 Godot 引擎初始化；
- 某些构建停在“编译中”；
- 某些构建出现大量 `ObjectDB`、`add_instance`、无效 `Callable` 错误；
- 另一些构建直接报：

```text
CompileError: WebAssembly.instantiate(): unexpected section <Exception>
(enable with --experimental-wasm-eh)
```

最终通过空项目隔离、源码重编译和 WASM section 检查，确认可解决的核心兼容问题位于 Godot Web 引擎的编译参数，而不是游戏业务代码、登录接口或资源 PCK。

## 2. 最终结论

本次稳定方案使用以下组合：

```text
Godot 基础源码：4.6.2-rc，commit a16e481cf424f8e39dc2cdea1a6bdc1e309acdc1
微信适配补丁：godothub/godot-minigame
Emscripten：4.0.10
threads：no
wasm_simd：no
SUPPORT_LONGJMP：emscripten
微信基础库：3.17.0
```

决定真机能否加载 WASM 的关键修改是：

```python
# 不兼容的实现
env.Append(CCFLAGS=["-sSUPPORT_LONGJMP='wasm'"])
env.Append(LINKFLAGS=["-sSUPPORT_LONGJMP='wasm'"])

# 最终使用的兼容实现
env.Append(CCFLAGS=["-sSUPPORT_LONGJMP='emscripten'"])
env.Append(LINKFLAGS=["-sSUPPORT_LONGJMP='emscripten'"])
```

修改位置位于打过微信适配补丁的 Godot 源码：

```text
platform/web/detect.py
```

## 3. `SUPPORT_LONGJMP` 是什么

`setjmp`/`longjmp` 是 C/C++ 运行时中的非局部跳转机制。程序可以先通过 `setjmp` 保存执行状态，再通过 `longjmp` 跳回保存的位置。

Godot 本身不使用 C++ exception，因此默认带有：

```text
-fno-exceptions
```

但是，这并不代表生成的 WASM 一定不包含 WebAssembly Exception Handling。原因是 Emscripten 可以使用 WebAssembly 异常机制实现 `setjmp`/`longjmp`。

### 3.1 `SUPPORT_LONGJMP='wasm'`

此模式使用 WebAssembly 原生异常处理能力实现 `longjmp`。

优点：

- 实现更接近 WASM 原生能力；
- 在完整支持 Wasm EH 的运行环境中可能更高效。

问题：

- Emscripten 4.0.10 会在 WASM 中生成 Tag/Exception section；
- 当前测试的手机微信基础库 3.17.0 无法解析该 section；
- `WebAssembly.instantiate()` 会在 Godot 运行前直接失败。

因此，即使编译命令含有 `-fno-exceptions`，仍可能看到：

```text
unexpected section <Exception>
```

这不是 Godot 游戏脚本抛出的异常，而是微信 WASM 解析器无法接受该二进制结构。

### 3.2 `SUPPORT_LONGJMP='emscripten'`

此模式保留 `setjmp`/`longjmp` 功能，但使用 Emscripten 的兼容实现，不要求运行环境支持 Wasm EH。

最终构建的 WASM section 为：

```text
1, 2, 3, 4, 5, 6, 7, 9, 12, 10, 11
```

其中不含 section 13（Tag/Exception）。

真机验证结果：

```text
[OddSpot] production source engine: Godot 4.6,
threads=no, wasm_simd=no, longjmp=emscripten,
build=20260730-eh-free

Engine has started!
```

## 4. 为什么最终使用 Godot 4.6，而不是直接使用 4.7

这不表示 Godot 4.7 原理上不能运行在微信小游戏中。

实际原因是：

1. 现有 4.7 微信引擎是预编译产物；
2. 该产物标识为：

   ```text
   Godot Engine for Wechat v4.7.2.rc.custom_build.546797c73
   ```

3. 当前仓库没有这份 4.7 引擎的完整、可复现构建环境；
4. 其构建过程还引用了外部工具目录，无法确认所有源码、补丁和参数；
5. 无法只修改 `SUPPORT_LONGJMP` 后可信地重建同一套 4.7 微信引擎；
6. 公开微信适配补丁明确锁定 Godot 官方提交：

   ```text
   a16e481cf424f8e39dc2cdea1a6bdc1e309acdc1
   ```

7. 该补丁能在 4.6.2-rc 基线上完整应用和复现。

因此，4.6 是本次可控制、可验证、已通过真机测试的稳定基线，而不是对 4.7 能力的否定。

## 5. 源码与补丁来源

### 5.1 Godot 官方源码

仓库：

```text
https://github.com/godotengine/godot
```

使用提交：

```text
a16e481cf424f8e39dc2cdea1a6bdc1e309acdc1
```

本地构建目录：

```text
.tmp/godot-4.6-wechat-source
```

### 5.2 微信小游戏适配补丁

仓库：

```text
https://github.com/godothub/godot-minigame
```

本次取得的适配仓库提交：

```text
de3200265fc50f4c757be037e64529814cd9ecdd
```

补丁包 ID：

```text
godot-4.6.2-rc-a16e481cf4
```

本地补丁目录：

```text
.tmp/godot-minigame-4.6.2/skills/patches/godot-4.6.2-rc-a16e481cf4
```

主要补丁：

```text
core/001-build-and-runtime-glue.patch
optional/001-audio-worker.patch
```

配套源码和处理脚本包括：

```text
skills/sources/godot-4.6.2-rc-a16e481cf4/
skills/scripts/apply_godot_patchset.py
skills/scripts/godot_process.js
skills/scripts/compress_wasm.*
```

## 6. 引擎构建方法

### 6.1 准备环境

使用 Emscripten 4.0.10，并加载其环境变量：

```powershell
. .\.tmp\emsdk\emsdk_env.ps1
```

### 6.2 应用微信补丁

补丁必须应用到指定的 Godot 官方提交。由于 Windows 换行和空白差异，必要时需要先检查：

```powershell
git apply --check --ignore-space-change --ignore-whitespace <patch-file>
```

确认后再应用对应补丁。

### 6.3 修改 `longjmp` 实现

在 `platform/web/detect.py` 中把：

```python
env.Append(CCFLAGS=["-sSUPPORT_LONGJMP='wasm'"])
env.Append(LINKFLAGS=["-sSUPPORT_LONGJMP='wasm'"])
```

改为：

```python
env.Append(CCFLAGS=["-sSUPPORT_LONGJMP='emscripten'"])
env.Append(LINKFLAGS=["-sSUPPORT_LONGJMP='emscripten'"])
```

### 6.4 编译单线程、无 SIMD 引擎

```powershell
python -m SCons `
  platform=web `
  target=template_release `
  threads=no `
  wasm_simd=no `
  -j6
```

本次全量编译耗时约 8 分钟。

### 6.5 后处理和 Brotli 压缩

先运行适配器提供的 `godot_process.js`，完成微信运行时相关替换，再将：

```text
bin/.web_zip/godot.wasm
```

压缩为：

```text
bin/.web_zip/godot.wasm.br
```

最终正式包中使用：

```text
build/wechat/engine/godot-wechat-clean.wasm.br
```

## 7. 正式游戏 PCK 的处理

Godot 4.7 导出的 PCK 不应直接交给 Godot 4.6 引擎。

因此正式游戏也使用 Godot 4.6.2 编辑器重新导出 PCK：

```text
build/wechat/subpackages/project/demo-pck.bin
```

处理原则：

- 不永久降低正式 `client/project.godot` 的版本；
- 建立临时 4.6 导出副本；
- 将临时副本的 feature 标记从 `4.7` 改为 `4.6`；
- 为导出 preset 增加 `wechat_minigame` custom feature；
- 使用 Godot 4.6 执行资源导入和 `--export-pack`；
- 检查导出日志中不存在脚本解析和资源加载错误；
- 使用 Godot 4.6 实际加载生成的 PCK 做 smoke test。

最终 PCK 大小：

```text
10,958,396 bytes
```

## 8. 最终微信包结构

正式微信开发者工具工程：

```text
build/wechat/
├── game.js
├── game.json
├── project.config.json
├── godot-loader.js
├── engine/
│   ├── game.js
│   ├── godot.js
│   ├── godot-sdk.js
│   └── godot-wechat-clean.wasm.br
└── subpackages/
    └── project/
        ├── game.js
        └── demo-pck.bin
```

关键配置：

```text
AppID：wx80a481e147abda26
基础库：3.17.0
iOSHighPerformance：true
iOSHighPerformance+：true
```

## 9. 验证方法

### 9.1 检查 WASM section

不能只看编译命令，应解压 `.wasm.br` 并解析实际 WASM。

验收条件：

- `WebAssembly.validate()` 返回 `true`；
- `WebAssembly.compile()` 成功；
- section 列表不包含 `13`。

### 9.2 检查 PCK

验收条件：

- 由与运行引擎一致的 Godot 4.6 导出；
- 导出日志不存在 `SCRIPT ERROR`、`Parse Error` 或资源加载失败；
- Godot 4.6 能通过 `--main-pack` 加载；
- 启动检查进程退出码为 0。

### 9.3 微信环境验证

必须分三层验证：

1. 微信开发者工具；
2. 上传后的体验版；
3. iPhone 真机微信。

本问题不能只以开发者工具成功作为完成标准。最终必须在手机端看到：

```text
Engine has started!
```

## 10. 对普通 Web 版本的影响

本次方案不会改变现有普通 Web 构建：

- EH-free 引擎只放入 `build/wechat`；
- 普通 Web 继续使用原有 Godot Web 导出流程；
- 登录逻辑通过平台判断区分普通 Web 与微信；
- 正式 `client` 工程没有永久降级为 4.6；
- 微信 PCK 由独立的临时 4.6 导出副本生成。

## 11. 已知边界

### 11.1 4.7 仍可作为后续目标

如果未来需要恢复 Godot 4.7 微信引擎，应完成以下工作：

1. 将公开微信补丁迁移到官方 Godot 4.7 源码；
2. 解决补丁冲突并审查 4.6 → 4.7 的 Web 平台变化；
3. 保留：

   ```text
   threads=no
   wasm_simd=no
   SUPPORT_LONGJMP=emscripten
   ```

4. 重新编译引擎；
5. 使用 4.7 导出对应 PCK；
6. 重新执行空项目和正式游戏的 iPhone 真机验证。

### 11.2 不能把所有 `ObjectDB` 错误都归因于 Wasm EH

预编译 4.7 引擎在 iPhone 上出现大量：

```text
object_slots[slot].object != nullptr
add_instance
Cannot connect to 'changed'
```

空项目也能复现，已经证明它不是游戏业务代码导致的。但目前没有该 4.7 引擎的完整可复现构建，无法严谨证明其内部错误与 `SUPPORT_LONGJMP='wasm'` 是同一个直接原因。

可以确定的是：

- 4.7 预编译引擎存在真机引擎层兼容问题；
- 4.6 初始源码构建明确包含不受支持的 Exception section；
- 改为 `longjmp=emscripten` 后，EH-free 4.6 空项目和正式游戏均在手机端启动成功。

## 12. 最终产物校验值

本次验证通过的正式引擎：

```text
文件：build/wechat/engine/godot-wechat-clean.wasm.br
SHA-256：3ad60b741a22063dd4e1ac95cf48e489c31996309c097fa8093ff32a82e4c983
压缩大小：6,454,986 bytes
解压大小：36,998,239 bytes
```

正式 PCK：

```text
文件：build/wechat/subpackages/project/demo-pck.bin
SHA-256：13306416ad2433bfae48392c541220c8080525ecae2adfaa1128faad1699ad0b
大小：10,958,396 bytes
```

以上校验值用于确认当前真机验证通过的构建，不应被当作后续版本的固定值。
