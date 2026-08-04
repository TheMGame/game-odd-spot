# game-odd-spot 微信小游戏发布：AI 执行任务书

> 目标：让代码 Agent 直接在 `game-odd-spot/client` 中完成 Godot 4.7 微信小游戏导出适配，产出可重复执行的安装脚本、导出配置、最小平台兼容改动、验证报告和人工操作清单。
>
> 执行原则：直接检查并修改代码，不要只输出方案；不要擅自实现微信登录、广告或支付；不要上传微信平台；不要写入真实 AppSecret。

---

## 1. 项目地址与工作范围

仓库：

```text
https://github.com/TheMGame/game-odd-spot
```

目标目录：

```text
game-odd-spot/client
```

本任务只允许修改：

```text
client/**
.gitignore
docs/**                 # 如果仓库已有 docs 目录
```

原则上不要修改服务端业务代码。可以只读搜索服务端配置、种子数据和关卡数据，用于整理图片/CDN 域名清单。

---

## 2. 已确认的项目基线

执行前重新验证，不要直接相信本文档：

1. `client/project.godot`
   - Godot feature 为 `4.7`
   - 主场景为 `res://scenes/bootstrap/bootstrap.tscn`
   - 分辨率为 `1080 × 1920`
   - 竖屏
   - 渲染器为 `gl_compatibility`
   - 生产 API 为：
     - `https://oddspot.guaguatu.com`
     - `https://api.guaguatu.com`

2. `client/export_presets.cfg`
   - 已有 `Windows Desktop`
   - 已有 `Web`
   - Web 导出关闭线程
   - Web 使用 `res://web/shell.html`
   - 当前没有“小游戏”导出项

3. `client/scripts/cache/asset_cache.gd`
   - 关卡图片通过 `HTTPRequest` 远程下载
   - 保存到 `user://asset_cache`
   - 支持 PNG、JPEG、WebP、SVG
   - 当前缓存上限为 300 MB
   - 单资源上限为 25 MB

4. `client/scripts/monetization/monetization.gd`
   - 激励广告是 Mock
   - 去广告购买是 Mock
   - 微信正式版不能暴露这些测试入口

5. Godot 微信小游戏适配插件：
   - 仓库：`godothub/godot-minigame`
   - 插件支持 Godot 4.4+
   - 当前版本索引包含 Godot 4.7.0：
     - tag：`4.7`
     - template：`minigame4.7.tpz`

如果实际代码与以上描述不同，以仓库当前内容为准，并在最终报告中说明差异。

---

## 3. 必须交付的文件

完成后至少应存在：

```text
client/
├── addons/
│   └── godot-minigame/              # 本地生成，可选择 gitignore
├── scripts/
│   └── platform/
│       └── platform.gd
├── tools/
│   └── wechat/
│       ├── install_plugin.sh
│       ├── install_plugin.ps1
│       ├── export_wechat.sh
│       ├── export_wechat.ps1
│       ├── godot-minigame.lock
│       ├── finalize_export.py
│       └── verify_export.py
├── docs/
│   ├── WECHAT_MINIGAME.md
│   ├── WECHAT_MANUAL_CHECKLIST.md
│   └── WECHAT_VALIDATION_REPORT.md
├── export_presets.cfg
└── project.godot
```

如果仓库规范要求文档放到根目录 `docs/`，可以调整文档位置，但需要在最终报告里写明。

---

## 3.1 禁止走错适配路线

`godot-minigame/skills/SKILL.md` 中包含一套修改 Godot 官方引擎源码的补丁流程，其主要支持基线是 Godot 4.6.2 附近的特定上游 commit。

本项目是普通 Godot 4.7 游戏工程，首选路线必须是：

```text
Godot 4.7 编辑器
→ godot-minigame 编辑器插件
→ minigame4.7.tpz 模板
→ 导出微信小游戏工程
```

禁止在本任务中：

- 克隆并修改 Godot 引擎源码；
- 将 4.6.2 patchset 套到 Godot 4.7；
- 编译自定义 Godot Web 引擎；
- 使用 `--allow-base-mismatch` 强行应用引擎补丁；
- 把“引擎源码移植”与“游戏项目导出”混为一谈。

只有在 4.7 模板被确认不可用，并且用户另行批准“自定义引擎移植”后，才能开启新的独立任务。

---

## 4. 阶段 A：创建分支并做预检

### 4.1 创建工作分支

```bash
git status --short
git branch --show-current
git rev-parse HEAD
```

如果工作区不干净：

- 不要覆盖已有改动；
- 记录已有改动；
- 仅修改本任务相关文件；
- 不要自动 `git reset --hard`；
- 不要自动删除用户文件。

不要自动执行 `git pull`，也不要擅自切换或创建分支。只有用户明确要求时才创建工作分支，并遵循当前执行环境的分支命名约定。

### 4.2 检查基础工具

执行并记录：

```bash
git --version
python3 --version
scons --version
godot --version
```

Windows 还要检查：

```powershell
git --version
python --version
scons --version
$env:GODOT_BIN
```

如果 `godot` 不在 PATH：

- 支持通过环境变量 `GODOT_BIN` 指定；
- 不要把本机绝对路径写死进仓库；
- 脚本应优先使用 `GODOT_BIN`，找不到时再尝试 `godot`、`godot4`。

### 4.3 检查 Godot 版本

优先使用 Godot 4.7 标准版。当前项目是 GDScript 项目，不需要 .NET/C# 功能。

脚本应验证：

```text
major = 4
minor = 7
```

如果版本不是 4.7：

- 停止自动导出；
- 允许继续生成代码和配置；
- 在报告中标为阻塞项；
- 不要自动降级项目。

如果检测到 Godot 4.7 .NET 版，不要仅凭版本名称直接判定失败；应实际执行插件加载、项目解析和导出验证。仅在出现可复现的不兼容时标记为阻塞，并建议改用标准版。

---

## 5. 阶段 B：实现可重复安装的小游戏插件

不要只手动复制一次。必须生成 Windows 和 macOS/Linux 安装脚本。

### 5.1 `godot-minigame.lock`

创建：

```text
client/tools/wechat/godot-minigame.lock
```

内容只保存经过核验的插件 Git commit SHA：

```text
GODOT_MINIGAME_COMMIT=67cde32e26b539518c845feea557dddaf84f19ec
```

该 commit 在修订本文档时同时对应上游 `main`、`4.7` tag，并且版本索引包含：

```text
Godot: 4.7.0
tag: 4.7
template: minigame4.7.tpz
```

安装脚本必须：

1. 只读取 lock 文件，不自动生成或改写 lock；
2. 克隆 `godothub/godot-minigame`；
3. 固定 checkout lock 中的 commit；
4. 校验 lock 值为完整的 40 位十六进制 Git SHA；
5. 不要每次无条件使用漂移的 `main`。

升级插件必须作为显式维护操作：先选择新的 commit，完成插件构建、Godot 解析、Web 回归和小游戏导出验证，再人工更新 lock 文件。不要把“选择版本”和“安装已锁版本”混在同一个脚本里。

如果无法访问 GitHub：

- 不要伪造 SHA；
- 保留清晰错误；
- 在验证报告中说明插件未下载。

### 5.2 安装脚本通用行为

两个脚本都必须：

1. 从脚本所在目录反推 `client` 根目录；
2. 使用：
   ```text
   client/.cache/godot-minigame
   ```
   作为插件源码缓存目录；
3. clone 时初始化子模块；
4. checkout lock 文件中的 commit；
5. 根据平台执行：
   - Windows：`build_win.bat`
   - macOS：`./build_osx.sh`
   - Linux：`./build_linux.sh`
6. 构建完成后复制：
   ```text
   demo/addons/godot-minigame/
   ```
   到：
   ```text
   client/addons/godot-minigame/
   ```
7. 不使用软链接，避免 Windows、CI 和压缩包环境出错；
8. 验证以下文件存在：
   ```text
   client/addons/godot-minigame/plugin.cfg
   client/addons/godot-minigame/plugin.gd
   client/addons/godot-minigame/*.gdextension
   client/addons/godot-minigame/bin/<platform>/*
   ```
9. 重复执行应保持幂等；
10. 出错立即返回非零退出码。

### 5.3 macOS 额外处理

安装结束后执行：

```bash
xattr -dr com.apple.quarantine client/addons/godot-minigame || true
```

仅处理该插件目录，不要对整个仓库执行 `xattr`。

### 5.4 `.gitignore`

增加：

```gitignore
client/.cache/godot-minigame/
client/addons/godot-minigame/
build/wechat/
```

如果项目决定提交插件二进制，则不要忽略 `client/addons/godot-minigame/`；但必须在最终报告中说明选择。默认建议不提交插件和二进制，只提交 lock 文件和安装脚本。

由于 `project.godot` 会启用一个默认被忽略、不会随 Git 克隆得到的插件，新的工作副本必须遵循以下顺序：

```text
克隆仓库
→ 执行 client/tools/wechat/install_plugin.ps1 或 install_plugin.sh
→ 打开 client/project.godot
```

CI 中执行 Godot 项目解析或导出前，也必须先运行插件安装脚本。

---

## 6. 阶段 C：启用 Godot 编辑器插件

修改 `client/project.godot`。

如果没有 `[editor_plugins]`，增加：

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot-minigame/plugin.cfg")
```

如果已经存在：

- 合并插件路径；
- 不要覆盖已有插件；
- 不要重复添加。

同时保持以下配置不变：

```ini
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
window/size/viewport_width=1080
window/size/viewport_height=1920
window/handheld/orientation=6
```

不要把渲染器改成 Forward+ 或 Mobile。

---

## 7. 阶段 D：增加微信小游戏导出配置

### 7.1 保留原有导出项

禁止删除或重写：

- Windows Desktop
- Web

现有 Web 自定义 Shell：

```text
res://web/shell.html
```

只服务普通浏览器版本，小游戏 preset 不得引用它。

### 7.2 修改 runnable presets

在 `client/export_presets.cfg` 的 `[runnable_presets]` 中加入：

```ini
"小游戏"="小游戏"
```

保留原来的 Windows 和 Web 条目。

### 7.3 新增小游戏 preset

使用下一个可用的 preset 编号。当前通常是 `preset.2`，但必须先读取文件，避免覆盖已有配置。

建议配置：

```ini
[preset.2]

name="小游戏"
platform="小游戏"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="wechat_minigame"
export_filter="all_resources"
include_filter=""
exclude_filter="tests/**,web/**,addons/**,tools/**,docs/**"
export_path="../build/wechat/oddspot-pck.bin"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.2.options]

"微信小游戏/游戏_AppID"="wx0000000000000000"
"微信小游戏/小游戏项目名"="错位大侦探"
"微信小游戏/游戏方向"="portrait"
"资源信息/启动封面背景图"=""
"资源信息/启动封面logo"=""
```

要求：

1. `wx0000000000000000` 只是占位符；
2. 不要把 AppSecret 写进任何客户端文件；
3. AppID 不是 AppSecret，但正式 AppID 仍由用户在导出前填写；
4. 如果插件实际生成的字段名称不同，以 Godot 编辑器生成结果为准；
5. 如果手写 preset 后 Godot 不识别，打开编辑器重新创建“小游戏” preset，并比较差异；
6. 不要修改 Windows/Web preset 的 `preset.N` 顺序。

注意：当前锁定的插件会把带扩展名的导出路径当作导出目录定位。上述 CLI 参数不会保证生成名为 `oddspot-pck.bin` 的最终文件；当前插件实际把主资源包写入：

```text
build/wechat/engine/demo-pck.bin
```

验证脚本和报告必须按实际产物检查，不得把 `oddspot-pck.bin` 当作必需文件名。若后续插件版本改变布局，以 lock 对应版本的真实输出为准。

---

## 8. 阶段 E：增加最小平台识别层

创建：

```text
client/scripts/platform/platform.gd
```

建议实现：

```gdscript
class_name Platform
extends RefCounted

const FEATURE_WECHAT_MINIGAME := "wechat_minigame"

static func is_wechat_minigame() -> bool:
	return OS.has_feature(FEATURE_WECHAT_MINIGAME)

static func is_web_like() -> bool:
	return OS.has_feature("web") or is_wechat_minigame()

static func is_native() -> bool:
	return not is_web_like()
```

要求：

- 不设为 Autoload；
- 使用 `class_name Platform` 即可；
- 不引入微信 SDK；
- 不实现 `wx.login`；
- 不实现广告；
- 不实现支付；
- 不重构整个项目。

### 8.1 替换 Web-like 判断

搜索：

```bash
rg 'OS\.has_feature\("web"\)' client
```

对网络、压缩和资源加载相关判断，改用：

```gdscript
Platform.is_web_like()
```

重点检查：

```text
client/scripts/api/api_client.gd
client/scripts/cache/asset_cache.gd
```

例如：

```gdscript
request.accept_gzip = not Platform.is_web_like()
```

不要机械替换所有地方。只有语义是“浏览器/WASM/小游戏共同受限”时才替换。

---

## 9. 阶段 F：禁用微信环境下的 Mock 付费能力

当前广告和购买接口是 Mock，正式小游戏不能显示成真实能力。

修改：

```text
client/scripts/monetization/monetization.gd
```

增加能力判断：

```gdscript
func rewarded_hint_available() -> bool:
	return not Platform.is_wechat_minigame()

func purchase_no_ads_available() -> bool:
	return not Platform.is_wechat_minigame()
```

在两个业务方法入口增加保护：

```gdscript
if Platform.is_wechat_minigame():
	return {
		"ok": false,
		"error": "FEATURE_NOT_AVAILABLE",
		"provider": "wechat_unconfigured",
	}
```

然后搜索调用位置：

```bash
rg "show_rewarded_hint|purchase_no_ads|claim_test_ad_reward|verify_test_purchase" client
```

对 UI 做以下处理：

- 微信小游戏环境隐藏“看广告得提示”按钮；
- 微信小游戏环境隐藏“购买去广告”按钮；
- 不要仅禁用按钮但仍显示诱导文案；
- Web 和 Windows 现有测试能力保持不变；
- 不删除 Mock 代码，因为其他平台仍可能用于测试。

本阶段不接入：

```text
wx.createRewardedVideoAd
微信虚拟支付
```

这些留到后续独立任务。

---

## 10. 阶段 G：检查网络和远程图片域名

### 10.1 固定域名

在文档中记录：

```text
https://oddspot.guaguatu.com
https://api.guaguatu.com
```

这两个域名需要由用户添加到微信小游戏后台的 request 合法域名。

### 10.2 动态图片/CDN 域名

关卡图片 URL 来自服务端，不能只检查客户端常量。

Agent 应执行：

```bash
rg -n 'https?://' .
```

重点检查：

- 关卡种子数据；
- Catalog 数据；
- 测试数据；
- 数据库 migration/seed；
- CDN 配置；
- 对象存储配置；
- README 和部署配置。

输出去重后的域名列表到：

```text
client/docs/WECHAT_MANUAL_CHECKLIST.md
```

如果静态搜索无法确定实际图片 host：

- 明确写“需要从生产 Catalog/关卡响应中采集”；
- 不要猜测域名；
- 在 Debug 模式下为 `asset_cache.gd` 增加一次性 host 日志；
- 日志不能包含 Token、Authorization Header 或完整敏感 query；
- 只打印 scheme + host。

建议格式：

```text
[WechatDomainAudit] asset host: https://example-cdn.com
```

---

## 11. 阶段 H：处理缓存与图片兼容性

当前资源缓存逻辑先保持功能不变，但必须做以下检查：

1. `user://asset_cache` 在小游戏模板下可写；
2. 写入后重新进入游戏仍可读取；
3. PNG、JPEG、WebP 解码正常；
4. SVG 不作为首发主要关卡格式；
5. 图片下载超过单资源上限时错误提示清晰；
6. 缓存失败不能导致永久黑屏；
7. 缓存损坏时能重新下载。

不要在没有真机数据的情况下擅自删除缓存或随意降低图片质量。

可以增加只读统计方法，用于 Debug 输出：

```text
当前缓存文件数
当前缓存总字节数
最近一次资源下载大小
资源解码后的宽高
```

Debug 日志必须受：

```gdscript
OS.is_debug_build()
```

控制。

---

## 12. 阶段 I：生成自动导出脚本

### 12.1 `export_wechat.sh`

行为：

1. 解析 `client` 根目录；
2. 查找 Godot：
   - `$GODOT_BIN`
   - `godot`
   - `godot4`
3. 检查插件目录存在；
4. 检查 `godot-minigame.lock` 存在；
5. 创建：
   ```text
   build/wechat
   ```
6. 首先执行一次项目导入和插件加载：
   ```bash
   "$GODOT_BIN" --headless --editor --path "$CLIENT_DIR" --quit
   ```
7. 执行：
   ```bash
   "$GODOT_BIN" \
     --headless \
     --path "$CLIENT_DIR" \
     --export-release "小游戏" \
     "$REPO_ROOT/build/wechat/oddspot-pck.bin"
   ```
8. 调用 `finalize_export.py`，确保加载项目 PCK 并清理模板演示资源；
9. 调用 `verify_export.py`；
10. 任一步失败返回非零退出码。

### 12.2 `export_wechat.ps1`

实现与 Shell 脚本相同的行为。

禁止：

- 写死 Godot 安装路径；
- 自动上传微信；
- 自动替换真实 AppID；
- 静默吞掉导出错误。

### 12.3 CLI 导出失败时

如果自定义导出平台在 Headless 下不能加载：

1. 记录完整错误；
2. 不要假装成功；
3. 保留 GUI 导出路径；
4. 在文档中说明：
   ```text
   Godot 编辑器 → 项目 → 导出 → 小游戏 → 导出项目
   ```
5. `verify_export.py` 仍然可用于检查 GUI 生成物。

---

## 13. 阶段 J：实现导出产物验证脚本

创建：

```text
client/tools/wechat/verify_export.py
```

参数：

```bash
python3 verify_export.py <wechat-output-dir>
```

至少检查：

```text
project.config.json
game.js
game.json
engine/                     # 或插件实际生成的引擎目录
至少一个 *.bin（当前锁定版本通常为 engine/demo-pck.bin）
至少一个 *.wasm 或 *.wasm.br
```

同时确认 `engine/game.js` 加载 `engine/demo-pck.bin`，不得继续加载模板演示包 `engine/empty-tips.bin`；模板演示原生音频清单不得引用不存在的文件。

同时检查：

1. 输出目录不是空目录；
2. 不包含 `tests/`；
3. 不包含 `addons/godot-minigame/`；
4. 不包含 `.env`；
5. 不包含 PEM、私钥或疑似真实 AppSecret 值；
6. `game.json` 的方向是 portrait；
7. `project.config.json` 可以被 JSON 解析；
8. 如果 AppID 仍为占位符，输出警告而不是假装可上传；
9. 检查单个文件异常大，并输出文件大小排行；
10. Secret 扫描必须区分“敏感字段名称”和“疑似真实值”：
    - PEM/私钥格式或明确的非空 AppSecret 赋值：失败；
    - 仅出现说明文字 `AppSecret`：不应单独判定失败；
    - 日志不得输出匹配到的完整 Secret 值；
11. 最终打印明确结果：

```text
VERIFY_EXPORT_OK
```

或者：

```text
VERIFY_EXPORT_FAILED
```

不要只依赖退出码。

---

## 14. 阶段 K：Godot 本地验证

### 14.1 项目解析

执行：

```bash
"$GODOT_BIN" --headless --editor --path client --quit
```

要求：

- 无脚本解析错误；
- 无缺失资源；
- 无插件加载错误；
- 无 GDExtension 加载错误。

### 14.2 运行现有测试

先搜索项目测试入口：

```bash
find client -maxdepth 4 -type f | grep -Ei 'test|spec'
rg -n "GUT|gdUnit|test_" client
```

存在测试框架则运行；不存在则不要编造测试结果。

### 14.3 普通 Web 回归

由于改动了平台判断，重新导出普通 Web：

```bash
"$GODOT_BIN" \
  --headless \
  --path client \
  --export-release "Web" \
  build/web/index.html
```

要求：

- Web 导出仍成功；
- 自定义 Shell 未被破坏；
- 登录和资源加载逻辑未被改坏。

### 14.4 微信小游戏导出

执行：

```bash
client/tools/wechat/export_wechat.sh
```

或 Windows：

```powershell
client\tools\wechat\export_wechat.ps1
```

保存完整输出到验证报告。

---

## 15. 阶段 L：生成用户必须手工执行的清单

创建：

```text
client/docs/WECHAT_MANUAL_CHECKLIST.md
```

内容必须明确区分“必须人工完成”。

### 15.1 微信后台

用户需要：

1. 创建微信小游戏；
2. 获取 AppID；
3. 不把 AppSecret 交给客户端；
4. 添加 request 合法域名：
   - `https://oddspot.guaguatu.com`
   - `https://api.guaguatu.com`
   - 所有实际图片/CDN host
5. 根据插件要求开启 iOS 高性能能力；
6. 配置隐私保护指引；
7. 配置用户协议和隐私政策；
8. 后续如接广告、支付，再申请对应能力。

### 15.2 Godot 编辑器

用户需要：

1. 打开 `client/project.godot`；
2. 确认插件已启用；
3. 打开底部 `Minigame` 面板；
4. 配置插件模板 Source/Owner/Repo/Tag；
5. 确认匹配：
   ```text
   Godot 4.7.0
   minigame4.7.tpz
   ```
6. 在“小游戏”导出项填写真实 AppID；
7. 导出到：
   ```text
   build/wechat/
   ```

### 15.3 微信开发者工具

用户需要：

1. 选择“小游戏”项目；
2. 导入包含 `project.config.json` 的目录；
3. 编译；
4. 检查控制台；
5. Android 真机预览；
6. iPhone 真机预览；
7. 测试前后台切换；
8. 测试杀进程后重新进入；
9. 上传体验版；
10. 通过体验版检查后再提交审核。

---

## 16. 真机验收用例

在 `WECHAT_MANUAL_CHECKLIST.md` 中加入下面的测试表。

### 16.1 启动

- [ ] 启动不黑屏
- [ ] Logo 和启动色正常
- [ ] 中文字体正常
- [ ] 竖屏方向正确
- [ ] 刘海、圆角和底部手势区不遮挡按钮
- [ ] 首次启动时间可接受

### 16.2 登录与会话

- [ ] 用户名密码登录成功
- [ ] 邮箱验证码流程正常
- [ ] Token 交换成功
- [ ] Token 刷新成功
- [ ] 退出登录成功
- [ ] 杀进程后 Session 可恢复
- [ ] 不在日志中打印 Token

### 16.3 网络

- [ ] bootstrap 成功
- [ ] home 成功
- [ ] catalog 成功
- [ ] level detail 成功
- [ ] start 成功
- [ ] progress 成功
- [ ] complete 成功
- [ ] 401 可刷新后重试
- [ ] 408/429/5xx 正确重试或入队
- [ ] 断网时有用户可理解的错误
- [ ] 恢复网络后队列能够重放

### 16.4 资源

- [ ] 两张关卡图可下载
- [ ] SHA-256 校验成功
- [ ] WebP 解码成功
- [ ] JPEG 解码成功
- [ ] 缓存命中成功
- [ ] 杀进程后缓存仍可用
- [ ] 缓存损坏后能重新下载
- [ ] 大图不会导致闪退
- [ ] 图片 host 全部已加入合法域名

### 16.5 游戏玩法

- [ ] 双图同步缩放
- [ ] 双图同步平移
- [ ] 点击坐标正确
- [ ] 圆形差异可命中
- [ ] 多边形差异可命中
- [ ] 重复点击不重复计数
- [ ] 提示功能正常
- [ ] 完成关卡正常
- [ ] 前后台切换后计时合理

### 16.6 商业化

- [ ] 微信环境不显示 Mock 广告按钮
- [ ] 微信环境不显示 Mock 购买按钮
- [ ] 不会调用 `provider=mock` 的正式奖励
- [ ] 不会调用 `platform=mock` 的正式购买验证

---

## 17. 不在本任务中实现的功能

明确标记为后续任务：

```text
微信一键登录 wx.login
微信分享
激励视频广告
微信虚拟支付
开放数据域排行榜
订阅消息
云开发
渠道统计
自动上传体验版
自动提交审核
```

不要因为这些功能未实现而阻塞“可运行测试版”的导出。

---

## 18. 最终验证报告格式

创建：

```text
client/docs/WECHAT_VALIDATION_REPORT.md
```

必须包含：

### 18.1 环境

```text
OS:
Godot:
Python:
SCons:
godot-minigame commit:
Godot template:
```

### 18.2 修改文件

逐个列出：

```text
文件路径
修改目的
关键改动
```

### 18.3 实际执行命令

记录真实执行过的命令，不要写计划命令冒充已执行。

### 18.4 测试结果

使用：

```text
PASS
FAIL
SKIPPED
BLOCKED
```

不要使用模糊的“应该可以”。

### 18.5 阻塞项

例如：

```text
BLOCKED：缺少正式微信小游戏 AppID
BLOCKED：当前环境未安装微信开发者工具
SKIPPED：无法进行 iPhone 真机测试
```

### 18.6 导出物

记录：

```text
输出目录
总大小
最大文件
是否存在 wasm.br
是否存在 pck/bin
是否仍为占位 AppID
```

### 18.7 人工下一步

只列出用户真正需要手动执行的操作。

---

## 19. AI 的完成标准

完成状态分为两级：

```text
IMPLEMENTED：代码、配置和脚本已经完成，但部分环境验证被明确阻塞。
VALIDATED：插件构建、Godot 项目解析、普通 Web 回归和微信小游戏导出验证全部成功。
```

只有同时满足以下条件，才可以声明“代码侧适配已实现（IMPLEMENTED）”：

- [ ] 安装脚本已生成
- [ ] 插件 commit 已锁定
- [ ] 插件能成功构建或已明确记录阻塞
- [ ] `project.godot` 已启用插件
- [ ] `export_presets.cfg` 已增加“小游戏”
- [ ] `wechat_minigame` feature 已配置
- [ ] 平台判断层已添加
- [ ] Mock 广告和购买在微信环境被隐藏/阻断
- [ ] 普通 Web 导出未被破坏
- [ ] 微信导出脚本已生成
- [ ] 导出验证脚本已生成
- [ ] 微信人工操作清单已生成
- [ ] 验证报告已生成
- [ ] 没有写入 AppSecret
- [ ] 没有上传、发布或提交审核

只有以下项目全部为 `PASS`，才可以声明“代码侧适配已验证（VALIDATED）”：

- [ ] 插件在当前平台成功构建并加载
- [ ] Godot 4.7 项目解析无错误
- [ ] 现有自动化测试通过
- [ ] 普通 Web 导出成功
- [ ] 微信小游戏导出成功
- [ ] `verify_export.py` 输出 `VERIFY_EXPORT_OK`

如果无法完成某项：

- 标记 `BLOCKED`；
- 说明实际原因；
- 给出用户下一条可执行命令；
- 不要声称已经完成。

---

## 20. 给代码 Agent 的最终执行指令

请直接执行以下任务，不要只给方案：

1. 检查 `game-odd-spot` 当前代码、工作区状态和 HEAD；不要自动 `git pull`。
2. 仅在 `client` 范围内完成 Godot 4.7 微信小游戏导出适配。
3. 按本文档创建可重复执行的插件安装脚本和导出脚本。
4. 使用 `godothub/godot-minigame`，锁定实际测试过的 commit。
5. 增加“小游戏” export preset，保留 Windows 和 Web preset。
6. 增加 `wechat_minigame` 自定义 feature。
7. 增加最小平台识别层。
8. 在微信环境隐藏并阻断 Mock 广告、Mock 购买入口。
9. 不实现微信登录、广告、支付，不修改服务端协议。
10. 运行能够运行的检查、测试和导出。
11. 生成 `WECHAT_MINIGAME.md`、人工清单和验证报告。
12. 对无法运行的 GUI、微信后台和真机步骤标记 `BLOCKED` 或 `SKIPPED`，不要伪造成功。
13. 最终回复必须包含：
    - 修改文件列表；
    - 实际执行命令；
    - 测试结果；
    - 导出目录；
    - 阻塞项；
    - 用户下一步手工操作。
