# 2026-07-30：game-odd-spot 微信小游戏导出适配变更记录

> 变更日期：2026-07-29 ～ 2026-07-30  
> 目标：保留普通 Web 版本，同时增加可在微信开发者工具及 iPhone 微信体验版运行的微信小游戏版本。  
> 最终状态：微信空项目和正式游戏均已通过 iPhone 真机启动验证。

## 1. 变更摘要

本次工作覆盖了五个方面：

1. 为 Godot 客户端增加微信小游戏平台识别与平台隔离；
2. 增加微信登录、输入、音频和分包启动适配；
3. 增加微信小游戏导出、后处理和静态校验工具；
4. 优化移动端 WebAssembly 资源内存和缓存行为；
5. 修复服务端 session 创建时暴露出的日志不足和 MySQL locale 幂等更新问题。

最终真机通过的微信包使用：

```text
Godot 4.6.2-rc 源码引擎
Emscripten 4.0.10
threads=no
wasm_simd=no
SUPPORT_LONGJMP=emscripten
微信基础库 3.17.0
AppID wx80a481e147abda26
```

最终微信开发者工具工程位于：

```text
build/wechat
```

该目录属于构建产物，已由 `.gitignore` 忽略，不提交到代码仓库。

## 2. 当前仓库变更规模

截至本文编写时，本次微信适配相关 Git 暂存区包含：

```text
30 个文件
约 3909 行新增
约 22 行删除
```

其中包括：

- 13 个已有客户端文件修改；
- 11 个新增客户端平台、工具和说明文件；
- 2 个服务端文件修改；
- 3 个问题/计划文档；
- `.gitignore`。

## 3. 项目配置变更

### 3.1 `client/export_presets.cfg`

新增“小游戏”导出 preset：

```text
name="小游戏"
platform="小游戏"
custom_features="wechat_minigame"
export_path="../build/wechat/oddspot-pck.bin"
```

关键配置：

```text
AppID：wx80a481e147abda26
项目名：火眼金睛
方向：portrait
```

微信导出排除：

```text
tests/**
web/**
addons/**
tools/**
docs/**
```

同时调整普通 Web preset 的排除规则，避免把以下开发内容放入 Web 导出：

```text
addons/godot-minigame/**
tools/**
docs/**
```

### 3.2 `client/project.godot`

启用 Godot 微信小游戏编辑器插件：

```text
res://addons/godot-minigame/plugin.cfg
```

插件实际目录不提交，由安装脚本按锁定 commit 获取。

### 3.3 `.gitignore`

新增忽略规则：

```text
client/.cache/godot-minigame/
client/addons/godot-minigame/
.tmp/
diagnostics/wechat-empty-47/
diagnostics/wechat-empty-46-source/
__pycache__/
*.pyc
```

用途：

- 不提交第三方插件工作副本；
- 不提交 Godot、Emscripten 和临时导出环境；
- 保留本地诊断项目，方便后续继续排查；
- 不污染准备上传的 Git 变更。

`build/` 原本已整体忽略，因此：

```text
build/wechat
build/wechat-empty-47
build/wechat-empty-46-source
```

均不会进入 Git。

## 4. 平台抽象

### 4.1 新增 `client/scripts/platform/platform.gd`

新增统一的平台判断：

```gdscript
Platform.is_wechat_minigame()
Platform.is_web_like()
Platform.is_native()
```

微信小游戏由导出 custom feature 判断：

```text
wechat_minigame
```

目的：

- 避免在各业务模块中散落 `OS.has_feature()`；
- 将微信小游戏视为 Web-like 环境；
- 保持普通 Web、微信和原生平台行为可分别控制。

同时新增对应 UID：

```text
client/scripts/platform/platform.gd.uid
```

## 5. 微信登录适配

### 5.1 `client/scenes/login/login.tscn`

新增默认隐藏的：

```text
WechatLoginButton
```

### 5.2 `client/scenes/login/login.gd`

新增微信平台登录模式：

- 微信环境隐藏账号输入框；
- 微信环境隐藏密码输入框；
- 微信环境隐藏普通登录按钮；
- 微信环境隐藏注册入口；
- 微信环境只显示“微信登录”；
- 非微信环境保持原有账号密码和邮箱注册流程；
- 微信环境不主动聚焦普通输入框，避免弹出错误键盘；
- 增加微信登录中、超时、失败和缺少 code 的提示。

平台隔离原则：

```text
微信小游戏 -> 微信登录
普通 Web   -> 原账号密码登录
原生客户端 -> 原账号密码登录
```

### 5.3 `client/scripts/api/api_client.gd`

新增：

```gdscript
login_wechat()
_request_wechat_login_code()
```

调用流程：

```text
GDScript
→ JavaScriptBridge
→ GameGlobal.oddSpotWechatAuth
→ wx.login()
→ 微信临时 code
→ POST /api/v1/user/login
→ login_type=2
→ 换取 user_server token
→ 换取 game session
```

微信 code 获取增加约 12 秒轮询超时，避免 JS 回调丢失后无限等待。

普通登录接口没有被改成微信登录，原逻辑继续保留。

### 5.4 HTTP gzip 平台兼容

以下请求由：

```gdscript
request.accept_gzip = not OS.has_feature("web")
```

调整为：

```gdscript
request.accept_gzip = not Platform.is_web_like()
```

覆盖：

- 普通 API 请求；
- user_server 登录；
- user_server profile；
- 用户资料更新。

这样微信小游戏不会错误地走原生 gzip 路径。

## 6. 微信启动器和 JS 桥接

主要由：

```text
client/tools/wechat/finalize_export.py
```

在导出后生成或修正。

### 6.1 微信 API 暴露

根入口中增加：

```javascript
GameGlobal.wx = wx
```

使 Godot 的 `JavaScriptBridge.get_interface("wx")` 能获取微信接口。

### 6.2 微信登录桥接

新增：

```javascript
GameGlobal.oddSpotWechatAuth
```

提供：

```text
begin()
getResult()
```

内部调用 `wx.login()`，将异步结果保存为：

```text
idle
pending
success
failed
```

供 GDScript 轮询读取。

### 6.3 正式 PCK 分包

将游戏 PCK 放到独立 project 分包：

```text
subpackages/project/demo-pck.bin
```

引擎启动器加载：

```javascript
GODOTSDK.startGame(exe, pack)
```

前先调用：

```javascript
wx.loadSubpackage({ name: "project" })
```

增加：

- project 分包加载失败日志；
- 失败提示框；
- 加载状态文字；
- 进度回调注销；
- success 后再启动 Godot。

### 6.4 分包进度保护

微信真机曾返回：

```text
totalBytesExpectedToWrite = 4294967295
progress = 负数
```

后处理器增加：

- `0..1` 进度识别；
- `0..100` 百分比识别；
- `4294967295` 哨兵值过滤；
- written/total 合法性检查；
- 最终进度 clamp；
- 无效进度直接忽略。

避免进度达到 100% 后变成负数并持续刷日志。

### 6.5 引擎文件规范化

微信引擎 basename 统一为：

```text
godot-wechat-clean
```

后处理还负责：

- engine/project 分包结构整理；
- native audio manifest 复制；
- `game.json` 分包更新；
- `project.config.json` 基础库更新；
- 将基础库固定为 `3.17.0`；
- 清理模板演示 PCK；
- 避免重复后处理导致 PCK 丢失。

## 7. 导出和安装工具

### 7.1 新增插件锁文件

文件：

```text
client/tools/wechat/godot-minigame.lock
```

锁定插件 commit：

```text
67cde32e26b539518c845feea557dddaf84f19ec
```

### 7.2 新增插件安装脚本

文件：

```text
client/tools/wechat/install_plugin.ps1
client/tools/wechat/install_plugin.sh
```

功能：

- 克隆 `https://github.com/godothub/godot-minigame.git`；
- checkout 锁定 commit；
- 初始化子模块；
- 校验实际 commit；
- 构建/安装插件；
- 将插件放入 `client/addons/godot-minigame`。

### 7.3 新增微信导出脚本

文件：

```text
client/tools/wechat/export_wechat.ps1
client/tools/wechat/export_wechat.sh
```

功能：

- 查找 Godot；
- 检查 Godot 版本；
- 检查插件是否安装；
- 使用“小游戏” preset 导出；
- 执行 `finalize_export.py`；
- 执行 `verify_export.py`。

### 7.4 新增后处理器

文件：

```text
client/tools/wechat/finalize_export.py
```

负责模板导出后的确定性修正，包括：

- 微信登录桥接；
- 分包；
- 引擎名称；
- PCK 路径；
- 进度回调；
- 基础库版本；
- native audio manifest；
- 微信入口和启动逻辑。

### 7.5 新增静态校验器

文件：

```text
client/tools/wechat/verify_export.py
```

检查：

- 必需文件；
- AppID 是否为占位符；
- JSON 可解析；
- 分包声明；
- 引擎和 PCK 引用；
- 微信登录桥接；
- 进度日志是否过量；
- native audio manifest；
- 文件大小；
- 私钥和疑似 AppSecret；
- 不应上传的源码/工具文件。

### 7.6 新增 WASM 内存诊断工具

文件：

```text
client/tools/wechat/patch_wasm_memory.js
```

该工具是在排查 iPhone 启动时 2～3 GB 内存占用过程中增加的，用于检查和限制 WASM memory 最大页数。

重要说明：

- 它属于诊断/兼容尝试；
- 最终真机成功的根因修复不是内存 section 修改；
- 最终根因修复是将 `SUPPORT_LONGJMP` 从 `wasm` 改成 `emscripten`；
- 当前 `finalize_export.py` 不应依赖二进制内存 patch 才能得到正确包。

## 8. 音频兼容变更

### 8.1 `client/scripts/audio/audio_manager.gd`

普通 Web 页面通过 `web/shell.html` 注册：

```text
oddSpotAudio
```

微信小游戏不加载该 HTML shell，因此调整为：

```gdscript
if OS.has_feature("web") and not Platform.is_wechat_minigame():
    _web_audio = JavaScriptBridge.get_interface("oddSpotAudio")
```

播放时只判断接口是否存在：

```gdscript
if _web_audio != null:
```

行为：

- 普通 Web 继续使用现有 `oddSpotAudio`；
- 微信使用引擎/插件音频桥接；
- 接口不存在时回退 Godot AudioStreamPlayer；
- 不再因查询未注册接口产生阻塞性错误。

## 9. 移动端内存和资源缓存优化

### 9.1 `client/scripts/cache/asset_cache.gd`

缓存上限由：

```text
2 GB
```

调整为：

```text
256 MB
```

新增纹理尺寸限制：

```text
系列缩略图：最大 1024
头像：最大 256
```

图片解码后按最长边等比缩放，减少：

- WebAssembly linear memory 高水位；
- 大 JPEG 同时解码；
- 手机纹理内存；
- 首页峰值内存。

缓存扫描由读取整个文件：

```gdscript
FileAccess.get_file_as_bytes(path).size()
```

改为只读取文件长度：

```gdscript
cache_file.get_length()
```

避免缓存清理本身把所有缓存文件读入内存。

资源 HTTP 请求也改为使用：

```gdscript
Platform.is_web_like()
```

判断 gzip 行为。

### 9.2 资源域名审计日志

Debug 构建中新增资源 host 去重日志：

```text
[WechatDomainAudit] asset host: ...
```

用于整理微信公众平台需要配置的：

- request 合法域名；
- downloadFile 合法域名。

日志只在 debug build 输出，每个 host 只输出一次。

### 9.3 `client/scenes/home/home.gd`

系列封面从并发异步加载改成队列串行加载：

```text
先生成卡片
→ 收集缩略图任务
→ 每次 await 一张图片
```

目的：

- 避免多个大图同时解码；
- 降低真机 WASM heap 峰值；
- 避免内存增长后无法归还给系统。

## 10. 微信商业化功能隔离

### 10.1 `client/scripts/monetization/monetization.gd`

新增：

```gdscript
rewarded_hint_available()
purchase_no_ads_available()
```

微信环境中：

- Mock 激励广告不可用；
- Mock 去广告购买不可用；
- 调用时返回 `FEATURE_NOT_AVAILABLE`；
- provider 标记为 `wechat_unconfigured`。

避免体验版暴露未接入真实微信广告/支付的测试能力。

### 10.2 `client/scenes/game/game.gd`

微信环境的提示次数用完文案不再提及“观看广告增加次数”。

普通 Web 保留原文案，不受影响。

### 10.3 `client/scenes/settings/settings.gd`

更新注释，明确：

- 当前没有正式广告供应商；
- 微信环境必须阻断 Mock 购买能力。

去广告入口仍保持隐藏。

## 11. 服务端变更

### 11.1 `server/internal/httpapi/router.go`

在创建 user-server game session 失败时增加结构化错误日志：

```text
error
user_id
market
locale
```

此前接口只返回：

```text
could not create game session
```

systemd journal 中只有请求日志，没有底层错误，导致无法判断是用户、locale、数据库还是 session 服务失败。

### 11.2 `server/internal/session/mysql_service.go`

修复 `UpdateLocale()` 的幂等行为。

MySQL 的 affected rows 为 0 可能表示：

1. 用户不存在；
2. locale 原本就等于目标值。

原逻辑把两种情况都当作：

```text
ErrUserNotFound
```

新逻辑在 affected rows 为 0 时查询用户是否存在：

- 用户不存在：返回 `ErrUserNotFound`；
- 用户存在且 locale 未变化：视为成功；
- 查询失败：返回明确数据库错误。

该修改解决微信登录后重复写入相同 locale 时 game session 创建失败的问题，同时也改善普通登录的幂等性。

### 11.3 不在本仓库中的 user_server 配置

排障过程中还完成了外部 `tutu-server-go/user_server` 的微信小程序登录配置，包括：

- provider 启用；
- AppID；
- AppSecret；
- 微信小程序登录模式；
- 非 OAuth redirect 模式。

这些配置或代码不属于当前 `game-odd-spot` 仓库 diff，因此不计入本文列出的 30 个 Git 文件。

## 12. 文档变更

### 12.1 客户端使用文档

新增：

```text
client/docs/WECHAT_MINIGAME.md
client/docs/WECHAT_MANUAL_CHECKLIST.md
client/docs/WECHAT_VALIDATION_REPORT.md
```

内容覆盖：

- 插件安装；
- 微信导出；
- 手工配置；
- 域名；
- AppID；
- 静态校验；
- 上传前检查；
- 已验证项和待真机项。

### 12.2 执行任务书

新增并修订：

```text
docs/plan/game-odd-spot_微信小游戏_AI执行任务书.md
```

记录最初范围、交付要求、平台兼容原则和验收标准。

其中早期优先 4.7 插件模板的判断已被后续真机排障更新：最终稳定基线是可复现的 4.6 EH-free 源码引擎。

### 12.3 问题复盘文档

新增：

```text
docs/issues/export_to_wx-mini/01-root-cause-and-solution.md
docs/issues/export_to_wx-mini/02-investigation-process-and-pitfalls.md
```

分别记录：

- 根因、编译机制和最终解决方案；
- 从登录、输入、音频、分包到 Wasm EH 的完整排障流程。

## 13. 最终引擎和正式包

最终真机验证通过的引擎不是原 4.7 预编译模板，而是：

```text
Godot 官方源码：
a16e481cf424f8e39dc2cdea1a6bdc1e309acdc1

微信适配来源：
https://github.com/godothub/godot-minigame

Emscripten：
4.0.10
```

关键编译参数：

```text
platform=web
target=template_release
threads=no
wasm_simd=no
SUPPORT_LONGJMP=emscripten
```

关键修复：

```text
-sSUPPORT_LONGJMP='wasm'
                    ↓
-sSUPPORT_LONGJMP='emscripten'
```

最终 WASM 不含 section 13（Tag/Exception），因此手机微信基础库可以完成实例化。

### 13.1 最终引擎产物

```text
build/wechat/engine/godot-wechat-clean.wasm.br
```

本次验证构建：

```text
SHA-256：
3ad60b741a22063dd4e1ac95cf48e489c31996309c097fa8093ff32a82e4c983

压缩大小：
6,454,986 bytes

解压大小：
36,998,239 bytes
```

### 13.2 正式游戏 PCK

正式 PCK 使用 Godot 4.6 重新导出，避免 4.7 PCK 与 4.6 引擎混用：

```text
build/wechat/subpackages/project/demo-pck.bin
```

本次验证构建：

```text
SHA-256：
13306416ad2433bfae48392c541220c8080525ecae2adfaa1128faad1699ad0b

大小：
10,958,396 bytes
```

## 14. Web 兼容性

本次改动没有把普通 Web 登录替换成微信登录。

普通 Web 保持：

- 原账号密码登录；
- 原邮箱注册；
- 原 `web/shell.html` 音频桥接；
- 原 Web export preset；
- 原 API 服务地址。

微信专用行为由：

```text
wechat_minigame
```

feature 隔离。

同时，以下优化会作用于 Web-like 平台，但属于兼容性增强：

- HTTP gzip 判断；
- 图片尺寸限制；
- 缓存上限；
- 缩略图串行解码。

## 15. 重要的可复现性边界

### 15.1 当前一键导出脚本仍以 4.7 插件路线为基础

当前：

```text
client/tools/wechat/export_wechat.ps1
client/tools/wechat/export_wechat.sh
```

仍检查 Godot 4.7，并调用插件的“小游戏” preset。

而本次最终真机通过的正式包，是在排障后使用以下流程手工组装：

```text
公开 4.6 源码补丁
→ 修改 longjmp
→ Emscripten 4.0.10 全量编译
→ godot_process.js 后处理
→ Brotli 压缩
→ Godot 4.6 重导正式 PCK
→ 替换 build/wechat 引擎和 project 分包
```

因此：

> 重新运行当前 4.7 一键导出脚本，可能覆盖已经真机验证通过的 EH-free 4.6 引擎。

在将 4.6 源码引擎构建流程正式纳入版本控制前，不应把当前脚本描述为“可以从零复现最终真机包”。

### 15.2 本地调试环境被保留但不提交

本次源码、工具链和诊断项目保留在：

```text
.tmp/
diagnostics/wechat-empty-47/
diagnostics/wechat-empty-46-source/
```

它们已加入 `.gitignore`，方便后续继续排查，但不会上传。

### 15.3 `build/wechat` 不提交

正式微信开发者工具工程也被 `build/` 规则忽略。

代码上传后，其他开发者不会自动获得已验证的 WASM 和 PCK。后续若需要团队或 CI 从零构建，应继续补充：

- 4.6 Godot commit 锁定；
- 微信 patchset；
- `longjmp=emscripten` 独立补丁；
- Emscripten 4.0.10 安装脚本；
- 引擎构建脚本；
- 4.6 PCK 导出脚本；
- WASM section 自动校验；
- 产物发布或缓存机制。

## 16. 验证结果

已完成：

- 微信开发者工具加载；
- 微信分包加载；
- WASM section 检查；
- `WebAssembly.validate()`；
- `WebAssembly.compile()`；
- Godot 4.6 正式 PCK 加载 smoke test；
- 空项目 iPhone 体验版启动；
- 正式游戏 iPhone 体验版启动；
- 微信登录；
- 普通 Web 登录隔离；
- 正式首页进入。

真机成功日志：

```text
[OddSpot] production source engine:
Godot 4.6,
threads=no,
wasm_simd=no,
longjmp=emscripten,
build=20260730-eh-free

Engine has started!
```

## 17. 上传代码前注意事项

提交前应确认：

1. `.tmp` 和 `diagnostics/wechat-empty-*` 未出现在 Git 状态；
2. `build/wechat` 未被提交；
3. 未提交真实 AppSecret；
4. AppID 可以提交，但 AppSecret 只能保存在服务端安全配置；
5. `client/addons/godot-minigame` 由安装脚本生成，不直接提交；
6. 当前暂存区内包含服务端两处修复，需要与客户端改动一起审查；
7. 若只上传源码，必须说明正式微信二进制产物没有随仓库上传；
8. 后续重新导出前先阅读本文第 15 节，避免用旧 4.7 流程覆盖已验证引擎。
