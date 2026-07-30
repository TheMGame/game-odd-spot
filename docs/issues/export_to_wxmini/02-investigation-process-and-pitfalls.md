# game-odd-spot 导出微信小游戏：完整排障流程与踩坑记录

> 记录日期：2026-07-30  
> 目的：记录从“Web 正常、微信失败”到正式体验版真机运行成功的全过程，避免重复走弯路。

## 1. 初始目标

项目原始目标不是把 Web 版本替换成微信版本，而是同时满足：

- 普通 Web 继续正常运行；
- 微信小游戏使用微信平台 API；
- 微信环境只展示微信登录；
- 非微信环境保持原有账号密码登录；
- 最终产出可直接由微信开发者工具打开、上传和真机运行的工程。

最初项目是 Godot 4.7 工程，已有普通 Web 导出能力，但没有经过真机验证的微信小游戏发布链路。

## 2. 第一阶段：建立微信导出结构

首先完成了微信小游戏工程所需的基础适配：

- 安装 `godothub/godot-minigame` 导出插件；
- 创建微信小游戏 export preset；
- 生成 `build/wechat`；
- 配置微信 AppID；
- 拆分 engine、project 等分包；
- 建立微信启动器；
- 添加微信平台判断；
- 添加微信键盘输入桥接；
- 添加微信登录桥接；
- 为 Web 保留原登录路径；
- 配置 API 请求和资源加载。

最终使用的 AppID：

```text
wx80a481e147abda26
```

微信开发者工具基础库：

```text
3.17.0
```

### 本阶段的坑：开发者工具“能显示画面”不等于导出完成

最初微信开发者工具能加载 Godot 演示界面，但这只能说明：

- 微信工程入口存在；
- 一部分 JS 和资源可以加载；
- 开发者工具的 WASM 环境能够执行某些代码。

它不能证明：

- 正式游戏 PCK 已正确替换；
- 手机微信使用相同的 WASM 能力；
- 登录、音频、输入法和远程资源均可工作；
- 上传体验版后仍能启动。

## 3. 第二阶段：确认正式 PCK 是否真正打入

早期导出包曾显示插件自带演示内容，而不是正式游戏。

原因是微信工程仍引用：

```text
demo-pck.bin
```

如果没有在导出后明确替换，该文件可能仍是模板演示 PCK。

解决方式：

- 每次正式导出后检查 PCK 大小和修改时间；
- 检查 `engine/game.js` 中实际传给 `GODOTSDK.startGame()` 的 pack 路径；
- 确保：

  ```text
  /subpackages/project/demo-pck.bin
  ```

  已替换为当前游戏 PCK；
- 对最终 PCK 计算 SHA-256，避免误用旧包。

### 本阶段的坑：只看文件名无法确认是否重新打包

模板和正式资源都可能叫 `demo-pck.bin`。必须结合：

- 文件大小；
- 时间戳；
- 哈希值；
- 真正加载的场景内容；

共同判断。

## 4. 第三阶段：登录请求和 AppID 问题

正式游戏能显示登录页后，首先遇到的错误是：

```json
{"code":1007,"message":"应用不存在","data":null}
```

随后登录成功后，创建游戏 session 又出现：

```text
could not create game session
```

### 4.1 误区：看到微信中的登录页，就认为所有登录都必须改成微信

实际需求是：

- 微信小游戏：只显示微信登录；
- 普通 Web：保留账号密码登录；
- 微信环境使用 `wx.login()` 获取临时 code；
- 只有微信平台调用微信登录 API；
- 不能影响现有普通登录。

因此最终采用平台隔离，而不是把所有登录请求统一改成微信登录。

### 4.2 服务端配置问题

服务端日志明确给出：

```text
登录失败: 应用未启用微信小程序登录
```

这说明当时已经不是客户端导出错误，而是 `user_server` 的应用配置没有启用微信小程序登录。

管理端需要配置微信小程序 provider、AppID 和 AppSecret。

### 4.3 OAuth 回调 URI 的误区

微信小程序登录使用：

```text
wx.login -> 临时 code -> 服务端 code2session
```

它不是浏览器 OAuth redirect 流程，因此微信小程序 provider 不需要依赖普通 OAuth 回调 URI。

管理页面仍要求填写“服务端回调 URI”时，属于通用 OAuth/OIDC 表单与微信小程序 provider 语义不一致的问题。正确处理应是：

- `wechat_miniprogram` provider 不强制回调 URI；
- 普通 OAuth/OIDC provider 继续校验回调白名单；
- 不要为了通过表单随便填写无意义的 redirect URI。

### 4.4 AppSecret 数据库长度问题

配置微信 AppSecret 后，服务端迁移曾失败：

```text
Error 1406 (22001): Data too long for column 'app_secret'
```

原因是数据库字段长度只考虑了原始 secret，没有考虑加密后密文长度增长。

这属于服务端数据模型问题，不是微信客户端导出问题。需要扩大字段长度或使用适合保存加密文本的字段类型。

### 本阶段结论

登录链路最终能够成功，但它与后续 Godot WASM 真机崩溃是两个不同问题。排障时必须分层：

```text
微信工程加载
→ Godot 引擎启动
→ 游戏 PCK 启动
→ 微信登录
→ user_server 登录
→ oddspot session
```

不能把后一层的错误提前归因到前一层。

## 5. 第四阶段：微信输入法适配

Godot Web 的 HTML 输入方式不能直接等同于微信小游戏输入。

开发者工具中曾出现输入体验很差、软键盘区域异常的问题。

处理方式是通过微信键盘 API 桥接：

- `wx.showKeyboard`
- `wx.onKeyboardInput`
- `wx.onKeyboardConfirm`
- `wx.onKeyboardComplete`
- `wx.hideKeyboard`

并在 GDScript 平台层中只对微信环境启用。

### 本阶段的坑

- 开发者工具的键盘行为与手机真机不完全一致；
- 不能只依赖 DOM input；
- 回调必须成对注册和注销；
- 微信登录页只保留微信登录后，也应避免让隐藏的账号密码输入框继续抢焦点。

## 6. 第五阶段：音频接口错误

微信开发者工具中出现：

```text
No interface 'OddSpotAudio' registered.
```

这是 `JavaScriptBridge.get_interface()` 查询了一个未注册的 JS 接口。

处理原则：

- 微信音频接口存在时使用微信原生音频；
- 接口不存在时回退到 Godot/Web 音频；
- 不应让可选音频能力阻止整个游戏启动。

### 本阶段的坑

该错误容易被误认为真机无法启动的根因。但后续空项目仍能复现引擎错误，说明游戏自定义音频不是最终的引擎崩溃原因。

## 7. 第六阶段：合法域名和体验版差异

开发者工具可以关闭合法域名检查，而体验版和正式版会执行微信平台限制。

需要分别配置：

- request 合法域名；
- downloadFile 合法域名；
- uploadFile 合法域名；
- socket 合法域名。

项目涉及的 API、资源 CDN 和游戏服务域名必须按实际调用方式填写。

### 本阶段的坑

开发者工具中的：

```text
不校验合法域名、web-view、TLS 版本以及 HTTPS 证书
```

只适用于本地调试，不能证明手机体验版能访问这些域名。

但域名问题通常会产生明确的网络失败，不会生成 WASM：

```text
unexpected section <Exception>
```

因此域名配置与引擎二进制兼容问题必须分开处理。

## 8. 第七阶段：分包进度变成负数

体验版加载 engine 分包时出现：

```text
totalBytesExpectedToWrite: 4294967295
totalBytesWritten: 0
progress: 负数
```

进度先接近 1，随后变成负数并不断下降。

### 原因

`4294967295` 是 `uint32` 最大值，经常被底层 API 用作“未知大小”或无效哨兵值。

如果启动器直接使用：

```text
totalBytesWritten / totalBytesExpectedToWrite
```

或不校验微信回调中的 `progress`，就会把无效值显示为实际进度。

### 解决方法

进度处理增加以下保护：

- `progress` 只接受 `0..1` 或 `0..100`；
- `totalBytesExpectedToWrite == 4294967295` 时不参与计算；
- `totalBytesWritten` 必须大于等于 0；
- `totalBytesWritten` 不能大于有效 total；
- 最终显示值 clamp 到 `0..1`；
- 分包 success 回调才表示加载完成，不以进度值是否达到 100% 作为唯一依据。

### 本阶段的坑

修复负数进度后，游戏仍可能卡在编译阶段。进度显示错误不是 WASM 无法实例化的根因，只是掩盖了真正错误。

## 9. 第八阶段：手机出现大量 `ObjectDB` 错误

上传体验版后，iPhone 出现大量：

```text
Condition "object_slots[slot].object != nullptr" is true.
Returning: ObjectID()
at: add_instance (core/object/object.cpp:2470)

Cannot connect to 'changed':
the provided callable is not valid
```

同时表现为：

- 启动内存达到 1～3 GB；
- 编译阶段卡死；
- 日志爆量；
- 开发者工具可能正常，手机失败。

### 9.1 最重要的隔离实验：创建真正的空项目

为排除业务代码，创建了：

- 空 Godot 4.7 项目；
- 只有一个空 Node；
- 无登录；
- 无音频；
- 无远程资源；
- 无游戏脚本；
- PCK 只有约 1.9 KB。

结果：

- 空项目在 iPhone 上仍出现相同 `ObjectDB/add_instance` 错误。

这一步证明问题位于：

```text
预编译 Godot 4.7 微信引擎 / 手机微信 WASM 运行环境
```

而不是：

- `game-odd-spot` 场景；
- 登录代码；
- API；
- 音频；
- 大 PCK；
- CDN。

### 9.2 本阶段的误判

排障过程中曾怀疑：

- Godot 4.7 本身不支持微信；
- 微信基础库版本不一致；
- 手机仍在使用缓存；
- PCK 中某个场景信号损坏；
- 游戏脚本触发 `ObjectDB` 重复注册；
- 资源包太大；
- 分包进度异常导致重复初始化。

空项目实验排除了大部分业务层假设。但因为预编译 4.7 引擎无法完整复现，不能严谨地把 `ObjectDB` 崩溃定位到一个具体编译选项。

正确结论应是：

> 该预编译 4.7 微信引擎在 iPhone 微信运行环境中存在引擎层兼容问题；具体内部原因尚未由其源码构建证明。

## 10. 第九阶段：改用公开源码构建链

为了得到可修改、可验证的引擎，选择：

```text
Godot 官方 4.6.2-rc 指定提交
+ godothub/godot-minigame 公开补丁
+ Emscripten 4.0.10
```

公开补丁锁定：

```text
a16e481cf424f8e39dc2cdea1a6bdc1e309acdc1
```

使用精确基线的原因：

- 补丁上下文确定；
- 微信文件系统、请求、显示、输入和退出适配可复现；
- 不依赖旧 4.7 预编译引擎的私有工具路径。

### 本阶段的坑：补丁因空白/换行失败

Windows 工作区可能存在 CRLF 或空白差异，补丁初次检查失败。

使用：

```text
--ignore-space-change
--ignore-whitespace
```

后确认补丁内容本身可以应用。

这类问题不能通过 `--allow-base-mismatch` 粗暴跳过。必须先确认：

- Git commit 完全一致；
- 冲突是否只是空白；
- 补丁修改的逻辑位置仍然正确。

## 11. 第十阶段：首次源码构建仍然失败

第一次源码编译采用：

```text
threads=no
wasm_simd=no
Emscripten 4.0.10
```

生成了空 Godot 4.6 包。

起初开发者工具表现为一直等待：

```text
still waiting on run dependencies:
dependency: wasm-instantiate
```

随后获得明确错误：

```text
CompileError: WebAssembly.instantiate():
unexpected section <Exception>
```

这次错误比 4.7 的 `ObjectDB` 日志更有价值，因为它直接指出 WASM 二进制包含运行环境不支持的 section。

## 12. 第十一阶段：找到真正可修复的根因

检查 Godot Web 平台编译配置发现：

```python
env.Append(CCFLAGS=["-sSUPPORT_LONGJMP='wasm'"])
env.Append(LINKFLAGS=["-sSUPPORT_LONGJMP='wasm'"])
```

同时 Godot 全局已有：

```text
-fno-exceptions
```

### 关键认识

`-fno-exceptions` 只表示 C++ exception 被关闭，不代表 WASM 中不会出现 Exception Handling section。

Emscripten 的：

```text
SUPPORT_LONGJMP='wasm'
```

会使用 Wasm EH 实现 `setjmp/longjmp`，仍然会生成 Exception/Tag section。

这解释了为什么：

- 源码中看起来“已经关闭异常”；
- 微信仍然报 `<Exception>`；
- 开发者工具和手机的结果可能不同。

### 最终修改

改为：

```text
SUPPORT_LONGJMP='emscripten'
```

功能没有被关闭，只是换成不依赖 Wasm EH 的兼容实现。

## 13. 第十二阶段：不要相信配置，检查最终二进制

修改后进行了全量重编译。

不能只通过日志中的编译参数判定成功，还必须读取最终 WASM section。

修改前的失败构建含有 Exception/Tag section。

修改后的 section：

```text
1, 2, 3, 4, 5, 6, 7, 9, 12, 10, 11
```

不包含：

```text
13
```

并通过：

```text
WebAssembly.validate() == true
WebAssembly.compile() == success
```

### 本阶段的坑：压缩包也要验证

引擎最终上传的是 `.wasm.br`，而不是未压缩 `.wasm`。

因此验收必须针对正式包：

1. 读取 `godot-wechat-clean.wasm.br`；
2. Brotli 解压；
3. 解析解压后的 WASM；
4. 再做 section、validate 和 compile 检查。

否则可能出现：

- 原始 WASM 是新的；
- `.wasm.br` 仍是旧文件；
- 开发者工具继续加载旧错误引擎。

## 14. 第十三阶段：空项目真机验证成功

EH-free 4.6 空项目上传体验版后，iPhone 显示：

```text
Godot Engine v4.6.2.rc.custom_build.a16e481cf
Build configuration: Emscripten 4.0.10, single-threaded
Engine has started!
```

并且：

- 不再出现 `<Exception>`；
- 不再出现 `ObjectDB/add_instance` 日志风暴；
- 空场景正常渲染；
- 手机真机通过。

这一步才标志着引擎层方案成立。

## 15. 第十四阶段：正式游戏不能直接复用 4.7 PCK

空项目通过后，不能只把 4.6 WASM 替换到原来的 4.7 游戏包中。

原因：

- Godot PCK 包含引擎版本相关的资源格式和导入产物；
- 4.7 导入生成的资源不应默认交给 4.6 引擎；
- 即使文件名相同，也可能在运行时出现资源版本或脚本兼容问题。

### 正确处理

1. 复制一份临时项目；
2. 不修改正式 `client`；
3. 临时把 `project.godot` feature 从 `4.7` 改成 `4.6`；
4. 使用 Godot 4.6 重新导入资源；
5. 给导出 preset 添加：

   ```text
   custom_features="wechat_minigame"
   ```

6. 使用 Godot 4.6 `--export-pack` 生成正式 PCK；
7. 检查导出日志；
8. 使用 Godot 4.6 `--main-pack` 做启动 smoke test；
9. 再替换微信工程中的 `demo-pck.bin`。

### 本阶段的坑：4.7 export preset 格式变化

Godot 4.7 的 `export_presets.cfg` 带有新的：

```text
[runnable_presets]
```

Godot 4.6 还会读取每个 preset 内的：

```text
runnable=true/false
```

临时导出副本中需要补齐兼容字段，否则 4.6 会报告：

```text
Couldn't find the given section "preset.0" and key "runnable"
```

### 本阶段的坑：首次打开缺少 `.godot/imported`

临时副本没有复制 `.godot`，首次启动会短暂出现字体导入文件不存在：

```text
Cannot open file res://.godot/imported/...fontdata
```

完成 Godot 4.6 的资源导入后文件会生成。必须区分：

- 导入开始前的暂时缺失；
- 导入完成后的真实资源错误。

## 16. 第十五阶段：正式包真机验证

最终正式包包含：

```text
Godot 4.6 EH-free 微信引擎
+ Godot 4.6 重新导出的 game-odd-spot PCK
+ 微信登录和输入桥接
+ 微信分包加载器
```

正式包路径：

```text
build/wechat
```

最终验证顺序：

1. JSON 配置可解析；
2. AppID 正确；
3. 基础库为 3.17.0；
4. engine、project 分包入口存在；
5. `.wasm.br` 解压后不含 section 13；
6. `WebAssembly.validate` 通过；
7. `WebAssembly.compile` 通过；
8. PCK 由 Godot 4.6 导出；
9. Godot 4.6 能加载该 PCK；
10. 微信开发者工具启动；
11. 上传体验版；
12. iPhone 微信真机启动；
13. 微信登录进入游戏。

最终用户确认：

- 空项目手机端成功；
- 正式游戏微信包手机端成功；
- 无原有引擎错误。

## 17. 本次最重要的排障原则

### 17.1 先分层，再修复

建议始终按以下层次定位：

```text
微信工程配置
→ 分包下载
→ WASM 解析
→ Godot 引擎初始化
→ PCK 加载
→ 游戏场景
→ 平台 API
→ 登录和业务服务
```

如果 WASM 尚未实例化，就不应优先修改游戏登录或场景脚本。

### 17.2 必须做最小复现

空项目是本次最关键的证据。

没有空项目时，大量时间会消耗在：

- 登录；
- 音频；
- 场景信号；
- 资源大小；
- CDN；
- PCK；

这些与引擎初始化无关的方向上。

### 17.3 开发者工具不能代替真机

即使双方都显示基础库 3.17.0，桌面工具和手机微信仍可能使用不同的 WASM 实现和能力集。

完成标准必须包含：

```text
上传体验版 + iPhone 真机
```

### 17.4 不要根据表面日志直接归因

例如：

- `ObjectDB/add_instance` 是引擎内部连锁错误，不一定表示游戏对象重复创建；
- 负数 progress 是无效进度字段，不一定表示下载真的倒退；
- `-fno-exceptions` 不代表没有 Wasm EH；
- `Engine subpackage ready` 不代表 WASM 已完成实例化；
- 登录成功不代表游戏 session 服务配置正确。

### 17.5 验证最终产物，而不是中间文件

必须检查真正上传的：

```text
build/wechat/engine/*.wasm.br
build/wechat/subpackages/project/demo-pck.bin
build/wechat/project.config.json
build/wechat/game.json
```

不能只检查源码目录或未压缩 WASM。

## 18. 后续工程化建议

当前已验证的引擎源码和补丁工作区位于 `.tmp`。为避免未来无法复现，建议继续完成：

1. 将 `longjmp=emscripten` 变更制作成独立补丁；
2. 将引擎构建脚本放入版本控制；
3. 固定：

   ```text
   Godot commit
   godot-minigame commit
   Emscripten 版本
   SCons 参数
   Node/Brotli 参数
   ```

4. 增加 CI 校验：

   - WASM section 13 不存在；
   - `WebAssembly.validate` 成功；
   - PCK 与引擎版本一致；
   - 微信 JSON 合法；
   - 分包大小符合限制；

5. 保留最小空项目作为引擎升级回归用例；
6. 每次升级微信基础库、Emscripten 或 Godot 后重新做 iPhone 真机验证；
7. 将普通 Web 和微信构建产物完全分离，防止微信专用改动污染 Web。

## 19. 简明复盘

本次最初看到的是：

```text
Web 正常
开发者工具部分正常
手机体验版失败
```

过程中先后处理了：

```text
PCK 替换
→ 登录配置
→ 微信登录
→ 输入法
→ 音频回退
→ 合法域名
→ 分包进度
→ 4.7 空项目复现
→ 4.6 源码构建
→ Wasm Exception section
→ longjmp 实现切换
→ 4.6 正式 PCK 重导出
→ 真机通过
```

最终真正使源码构建的 WASM 能在手机微信加载的关键修复是：

```text
-sSUPPORT_LONGJMP='wasm'
                    ↓
-sSUPPORT_LONGJMP='emscripten'
```

而使整个正式项目可靠运行的完整方案是：

```text
EH-free 微信引擎
+ 同版本 Godot 4.6 PCK
+ 平台隔离的微信登录/输入/音频适配
+ 微信分包和配置校验
+ 真机验收
```

## 20. 后续运行期问题：离树节点仍被调度

引擎启动问题解决后，正式游戏真机运行阶段曾重复出现：

```text
Condition "!is_inside_tree()" is true. Returning: false
at: can_process (scene/main/node.cpp:902)
```

Godot 4.6 `SceneTree::_process_group()` 在遍历 process group 副本时，原代码先
调用 `can_process()`，再判断节点是否仍在 SceneTree。节点可能在同一帧的另一个
回调中离树，因此检查顺序会触发 `can_process()` 的前置条件断言。

修复为：

```cpp
if (!n->is_inside_tree() || !n->can_process()) {
    continue;
}
```

该修复属于引擎节点生命周期防御，不修改游戏业务行为。补丁保存在：

```text
client/tools/wechat/patches/godot-4.6-scene-tree-node-lifecycle.patch
```

同一轮还将微信振动切换到 `wx.vibrateShort()`，避免 Godot Web 振动 API 输出
“This browser does not support vibration”。
