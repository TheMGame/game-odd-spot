# 微信小游戏内存诊断快速接入手册

## 1. 用途

当微信小游戏性能面板显示异常大的 `MemoryUsed`，或怀疑切换场景、加载远程图片后存在内存泄漏时，使用本文方法临时加入诊断日志。

诊断完成后应移除监控代码，避免正式版本每隔一段时间输出日志。本文保留完整接入方案，后续 AI 应先阅读本文，再按需恢复诊断。

## 2. 已确认的统计差异

2026-08-01 的实机排查中，微信性能浮层曾显示约 1～2GB，但 Godot 实际报告为：

- 渲染缓冲约 8MB；
- 纹理约 34MB；
- 总显存约 42MB；
- 孤立节点为 0；
- 1024×1536 主图解码后的理论 RGBA 内存约 6MB，创建纹理后显存也增加约 6MB。

实际 WASM 模块声明：

- 初始线性内存：32MB（512 页）；
- 最大可增长空间：2048MB（32768 页）。

因此，微信浮层的 `MemoryUsed` 不能直接当成游戏纹理或 Godot 实际工作集。它可能包含微信进程、调试环境或 WASM 地址空间统计。应使用下面的分项日志判断真实资源增长。

## 3. 新增诊断工具

临时新建 `client/scripts/platform/memory_diagnostics.gd`：

```gdscript
class_name MemoryDiagnostics
extends RefCounted

static func snapshot(label: String, extra := {}) -> void:
	if not Platform.is_wechat_minigame():
		return
	var values := {
		"label": label,
		"static_mb": _mb(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_max_mb": _mb(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"video_mb": _mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_mb": _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_mb": _mb(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"objects": roundi(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": roundi(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}
	values.merge(extra, true)
	print("[OddSpotMemory] %s" % JSON.stringify(values))

static func texture_stage(label: String, encoded_bytes: int, image: Image) -> void:
	if not Platform.is_wechat_minigame() or image == null:
		return
	var width := image.get_width()
	var height := image.get_height()
	snapshot(label, {
		"encoded_mb": _mb(encoded_bytes),
		"image_width": width,
		"image_height": height,
		"rgba_estimate_mb": _mb(width * height * 4),
		"image_format": image.get_format(),
	})

static func _mb(bytes: float) -> float:
	return snappedf(bytes / 1048576.0, 0.01)
```

`MEMORY_STATIC` 在 Godot Web/微信环境可能返回 0，这是平台监控项不可用，不代表 CPU 内存为 0。

## 4. 增加周期采样器

临时新建 `client/scripts/platform/wechat_memory_monitor.gd`：

```gdscript
extends Node

const SAMPLE_INTERVAL_SECONDS := 10.0
var _elapsed := 0.0

func _ready() -> void:
	if not Platform.is_wechat_minigame():
		set_process(false)
		return
	MemoryDiagnostics.snapshot("monitor_ready")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < SAMPLE_INTERVAL_SECONDS:
		return
	_elapsed = 0.0
	var scene := get_tree().current_scene
	var scene_name := scene.name if scene != null else "none"
	MemoryDiagnostics.snapshot("periodic:%s" % scene_name)
```

在 `client/project.godot` 的 `[autoload]` 中临时增加：

```ini
WechatMemoryMonitor="*res://scripts/platform/wechat_memory_monitor.gd"
```

## 5. 图片加载阶段打点

在 `client/scripts/cache/asset_cache.gd` 的 `_decode_texture()` 中加入：

```gdscript
var image := decode_image(bytes, content_type)
if image == null:
	return {"ok": false, "error": "ASSET_DECODE_FAILED"}
MemoryDiagnostics.texture_stage("image_decoded", bytes.size(), image)
```

图片缩放后加入：

```gdscript
MemoryDiagnostics.texture_stage("image_resized", bytes.size(), image)
```

创建纹理时改为：

```gdscript
var texture := ImageTexture.create_from_image(image)
MemoryDiagnostics.texture_stage("texture_created", bytes.size(), image)
return {"ok": true, "texture": texture}
```

## 6. 关卡生命周期打点

在 `client/scenes/game/game.gd` 中按以下位置调用：

```gdscript
func _ready() -> void:
	MemoryDiagnostics.snapshot("game_ready")
```

```gdscript
func _load_level() -> void:
	MemoryDiagnostics.snapshot("level_load_begin")
```

纹理赋给 `SpotImage` 后调用：

```gdscript
MemoryDiagnostics.snapshot("level_texture_assigned")
```

双图找茬模式可使用标签 `level_textures_assigned`。

## 7. 编译与实机采集

1. 将改动同步到 Godot 4.6 微信复现工程 `.tmp/client-wechat-46`。
2. 使用 Godot 4.6.2 导出新的 PCK。
3. 替换 `build/wechat/subpackages/project/demo-pck.bin`。
4. 执行：

```powershell
python client/tools/wechat/finalize_export.py build/wechat
python client/tools/wechat/verify_export.py build/wechat
```

5. 在微信开发者工具或实机清除缓存并重新编译。
6. 在 vConsole 中过滤 `OddSpotMemory`，导出完整日志。

至少采集以下顺序：

```text
monitor_ready
periodic:Home
periodic:LevelSelect
game_ready
level_load_begin
image_decoded
texture_created
level_texture_assigned
periodic:Game
```

## 8. 如何判断

### 图片占用是否合理

未压缩 RGBA 纹理理论占用：

```text
宽 × 高 × 4 字节
```

例如 1024×1536：

```text
1024 × 1536 × 4 = 6MB
```

若 `texture_created` 前后 `texture_mb` 增量约为理论值，说明纹理加载正常。

### 是否发生泄漏

连续执行至少 10 次：

```text
关卡列表 → 进入关卡 → 返回关卡列表
```

重点比较每次稳定后的 `periodic:LevelSelect` 和 `periodic:Game`：

- `texture_mb`、`video_mb` 回落或稳定：正常；
- `orphans` 始终为 0：正常；
- 对象、资源、节点数量随场景变化后回落：正常；
- 每轮稳定值持续增长且不回落：需要继续定位资源引用或节点未释放。

## 9. 排查完成后的清理

正式提交前移除：

- `memory_diagnostics.gd`；
- `wechat_memory_monitor.gd`；
- `project.godot` 中的 `WechatMemoryMonitor` autoload；
- `asset_cache.gd` 和 `game.gd` 中所有 `MemoryDiagnostics` 调用。

随后重新导出 PCK，并再次运行 `finalize_export.py` 和 `verify_export.py`。普通 Web 虽然不会执行这些微信条件日志，但正式版本仍应删除临时诊断代码。
