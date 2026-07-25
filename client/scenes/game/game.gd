extends Control

@onready var base_panel: SpotImage = $Layout/BasePanel
@onready var target_panel: SpotImage = $Layout/ImageFrame/Margin/TargetPanel
@onready var counter: Label = $Layout/TopBar/Heading/Counter
@onready var hint_button: Button = $Layout/TopBar/Hint
@onready var status_label: Label = $Layout/Status
@onready var complete_panel: PanelContainer = $CompletePanel
@onready var found_info: PanelContainer = $Layout/FoundInfo
@onready var found_title: Label = $Layout/FoundInfo/Margin/Content/Title
@onready var found_era: Label = $Layout/FoundInfo/Margin/Content/Era
@onready var found_reason: Label = $Layout/FoundInfo/Margin/Content/Reason

var level_data: Dictionary
var differences: Array = []
var found: Dictionary = {}
var attempt_id := ""
var started_at_ms := 0
var hints_used := 0
var _syncing_view := false
var attempt_state: Dictionary = {}
var elapsed_before_session := 0
var is_anachronism_mode := false


func _ready() -> void:
	base_panel.normalized_pressed.connect(_on_image_pressed)
	target_panel.normalized_pressed.connect(_on_image_pressed)
	base_panel.view_changed.connect(_sync_target_view)
	target_panel.view_changed.connect(_sync_base_view)
	hint_button.pressed.connect(_use_hint)
	$Layout/TopBar/Report.pressed.connect(_report_level)
	$Layout/TopBar/Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn"))
	$CompletePanel/Margin/Content/Actions/Next.pressed.connect(_next_level)
	$CompletePanel/Margin/Content/Actions/Map.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn"))
	$CompletePanel/Margin/Content/Actions/Replay.pressed.connect(_replay_level)
	resized.connect(_apply_responsive_layout)
	_apply_visual_style()
	_apply_responsive_layout()
	_load_level()


func _load_level() -> void:
	var loaded := await LevelLoader.new().load_first_level()
	if not loaded.ok:
		status_label.text = "关卡加载失败：%s" % loaded.error
		return
	level_data = loaded.data
	differences = level_data.get("differences", [])
	$Layout/TopBar/Heading/Title.text = str(level_data.get("title", "时代寻错"))
	$Layout/EraRibbon.text = str(level_data.get("instruction", "圈出不属于这个年代的物件"))
	is_anachronism_mode = str(level_data.get("mode", "")) == "find_anachronism"
	var assets: Dictionary = level_data.get("assets", {})
	var cache := AssetCache.new()
	if is_anachronism_mode:
		base_panel.visible = false
		var image_result := await cache.load_texture(self, assets.get("image", {}))
		if not image_result.ok:
			status_label.text = "图片加载失败"
			return
		target_panel.set_texture(image_result.texture)
		await get_tree().process_frame
		target_panel.configure_fit_view()
	else:
		var base_result := await cache.load_texture(self, assets.get("base", {}))
		var target_result := await cache.load_texture(self, assets.get("target", {}))
		if not base_result.ok or not target_result.ok:
			status_label.text = "图片加载失败"
			return
		base_panel.set_texture(base_result.texture)
		target_panel.set_texture(target_result.texture)
	attempt_state = ProgressStore.get_or_create(str(level_data.level_id), int(level_data.level_version))
	attempt_id = str(attempt_state.attempt_id)
	hints_used = int(attempt_state.get("hints_used", 0))
	elapsed_before_session = int(attempt_state.get("elapsed_ms", 0))
	started_at_ms = Time.get_ticks_msec()
	for difference_id in attempt_state.get("found", []):
		for difference in differences:
			if str(difference.id) == str(difference_id):
				_restore_found(difference)
	if not is_anachronism_mode:
		var restored_zoom := float(attempt_state.get("zoom", 1.0))
		var restored_offset := Vector2(float(attempt_state.get("view_offset_x", 0.0)), float(attempt_state.get("view_offset_y", 0.0)))
		base_panel.set_view(restored_zoom, restored_offset)
		target_panel.set_view(restored_zoom, restored_offset)
	_update_counter()
	status_label.text = "滚轮或双指缩放 · 放大后拖动查看" if is_anachronism_mode else "找出所有不同之处；滚轮缩放，拖动查看"
	var start_result := await SyncQueue.submit_with_key("/v1/levels/%s/start" % str(level_data.level_id).uri_encode(), {
		"attempt_id": attempt_id,
		"level_version": int(level_data.level_version),
	}, str(attempt_state.start_idempotency_key))
	if start_result.get("queued", false):
		status_label.text = "离线模式：进度将在后续同步"
	Analytics.track("level_start", {"level_id": level_data.level_id, "level_version": level_data.level_version})


func _on_image_pressed(point: Vector2) -> void:
	if complete_panel.visible:
		return
	for difference in differences:
		var id := str(difference.get("id", ""))
		if found.has(id):
			continue
		if _contains(difference, point):
			_mark_found(difference)
			return
	status_label.text = "这里没有不同"
	Analytics.track("wrong_tap", {"level_id": level_data.level_id, "x": point.x, "y": point.y})


func _report_level() -> void:
	if level_data.is_empty():
		return
	$Layout/TopBar/Report.disabled = true
	var result := await ApiClient.report_level(str(level_data.level_id), "other", "玩家从游戏内提交的关卡问题")
	status_label.text = "举报已提交，我们会进行审核" if result.ok else "举报提交失败：%s" % result.error
	$Layout/TopBar/Report.disabled = false


func _contains(difference: Dictionary, point: Vector2) -> bool:
	if difference.get("shape") == "circle":
		var center := Vector2(float(difference.get("x", 0)), float(difference.get("y", 0)))
		return point.distance_to(center) <= float(difference.get("radius", 0)) + 0.012
	if difference.get("shape") == "polygon":
		var polygon := PackedVector2Array()
		for raw_point in difference.get("points", []):
			polygon.append(Vector2(float(raw_point.get("x", 0)), float(raw_point.get("y", 0))))
		return Geometry2D.is_point_in_polygon(point, polygon)
	return false


func _mark_found(difference: Dictionary) -> void:
	var id := str(difference.id)
	found[id] = true
	var center := _difference_center(difference)
	if not is_anachronism_mode:
		base_panel.add_marker(center)
	target_panel.add_marker(center)
	_save_attempt()
	_update_counter()
	status_label.text = "找到了！"
	_show_found_info(difference)
	if Preferences.vibration_enabled:
		Input.vibrate_handheld(35)
	Analytics.track("difference_found", {"level_id": level_data.level_id, "difference_id": id, "found_at_ms": _elapsed_ms()})
	_sync_progress(id)
	if found.size() == differences.size():
		_finish_after_feedback()


func _show_found_info(difference: Dictionary) -> void:
	found_title.text = "✓ 找到：%s" % str(difference.get("label", difference.get("id", "时代错误")))
	found_era.text = "出现年代：%s" % str(difference.get("era", "北宋以后"))
	found_reason.text = str(difference.get("explanation", "这个物件不属于当前历史年代。"))
	found_info.visible = true


func _finish_after_feedback() -> void:
	hint_button.disabled = true
	await get_tree().create_timer(1.8).timeout
	_finish_level()


func _use_hint() -> void:
	if hints_used >= 3:
		status_label.text = "正在加载激励广告…"
		var reward := await Monetization.show_rewarded_hint()
		if not reward.ok:
			status_label.text = "暂时无法获得广告提示"
			return
	for difference in differences:
		if not found.has(str(difference.id)):
			hints_used += 1
			Analytics.track("hint_request", {"level_id": level_data.level_id, "source": "free" if hints_used <= 3 else "rewarded_ad"})
			_mark_found(difference)
			return


func _sync_progress(difference_id: String) -> void:
	var elapsed := _elapsed_ms()
	await SyncQueue.submit("/v1/levels/%s/progress" % str(level_data.level_id).uri_encode(), {
		"attempt_id": attempt_id,
		"found": [{"difference_id": difference_id, "found_at_ms": elapsed}],
		"hints_used": hints_used,
		"duration_ms": elapsed,
	})


func _finish_level() -> void:
	var elapsed := _elapsed_ms()
	var ids: Array = found.keys()
	var result := await SyncQueue.submit("/v1/levels/%s/complete" % str(level_data.level_id).uri_encode(), {
		"attempt_id": attempt_id,
		"difference_ids": ids,
		"hints_used": hints_used,
		"duration_ms": elapsed,
	})
	complete_panel.visible = true
	$CompleteDim.visible = true
	attempt_state["elapsed_ms"] = elapsed
	ProgressStore.mark_completed(str(level_data.level_id), attempt_state)
	if not result.get("queued", false):
		$CompletePanel/Margin/Content/Message.text = "全部找到了"
	else:
		$CompletePanel/Margin/Content/Message.text = "本地完成 · 等待同步"
	var seconds := int(elapsed / 1000)
	$CompletePanel/Margin/Content/Stats.text = "发现 %d/%d  ·  提示 %d  ·  用时 %02d:%02d" % [found.size(), differences.size(), hints_used, int(seconds / 60), seconds % 60]
	Analytics.track("level_complete", {"level_id": level_data.level_id, "duration_ms": elapsed, "hints_used": hints_used, "queued": result.get("queued", false)})
	Analytics.flush()


func _difference_center(difference: Dictionary) -> Vector2:
	if difference.get("shape") == "circle":
		return Vector2(float(difference.x), float(difference.y))
	var total := Vector2.ZERO
	var points: Array = difference.get("points", [])
	for point in points:
		total += Vector2(float(point.x), float(point.y))
	return total / maxf(points.size(), 1)


func _update_counter() -> void:
	counter.text = "%d / %d" % [found.size(), differences.size()]
	$Layout/Progress.max_value = maxf(differences.size(), 1)
	$Layout/Progress.value = found.size()
	var names: Array[String] = []
	for difference in differences:
		if found.has(str(difference.get("id", ""))):
			names.append("◆ %s" % str(difference.get("label", "时代错误")))
	$Layout/Journal/Margin/Content/Items.text = "尚未发现时代错误\n仔细观察画面中的人物、器物与建筑" if names.is_empty() else "\n".join(names)
	$Layout/Journal/Margin/Content/Remaining.text = "全部发现" if found.size() == differences.size() else "还剩 %d 个" % (differences.size() - found.size())
	hint_button.disabled = found.size() == differences.size()


func _next_level() -> void:
	LevelLoader.clear_selection()
	get_tree().reload_current_scene()


func _replay_level() -> void:
	ProgressStore.clear_level(str(level_data.get("level_id", "")))
	complete_panel.visible = false
	$CompleteDim.visible = false
	get_tree().reload_current_scene()


func _apply_visual_style() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#102837")
	frame.border_color = Color("#b88a43")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(14)
	$Layout/ImageFrame.add_theme_stylebox_override("panel", frame)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#eadbbd")
	paper.border_color = Color("#a53b2b")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(14)
	$Layout/FoundInfo.add_theme_stylebox_override("panel", paper)
	var journal := StyleBoxFlat.new()
	journal.bg_color = Color("#102431")
	journal.border_color = Color(0.72, 0.54, 0.27, 0.55)
	journal.set_border_width_all(2)
	journal.set_corner_radius_all(14)
	$Layout/Journal.add_theme_stylebox_override("panel", journal)
	var result := StyleBoxFlat.new()
	result.bg_color = Color("#eadbbd")
	result.border_color = Color("#d0a04c")
	result.set_border_width_all(4)
	result.set_corner_radius_all(24)
	complete_panel.add_theme_stylebox_override("panel", result)


func _apply_responsive_layout() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var landscape := size.x > size.y
	$Layout/ImageFrame.custom_minimum_size.y = 260.0
	$Layout/ImageFrame/Margin/TargetPanel.custom_minimum_size.y = 0.0
	$Layout/Journal.visible = landscape
	$Layout/Journal.custom_minimum_size.y = 92.0
	$Layout.offset_left = 12.0 if landscape else 8.0
	$Layout.offset_right = -12.0 if landscape else -8.0
	$Layout.offset_top = 8.0 if landscape else 10.0
	$Layout.offset_bottom = -8.0 if landscape else -10.0
	$Layout/TopBar.custom_minimum_size.y = 60.0 if landscape else 56.0
	for button_path in ["Back", "Hint", "Report"]:
		var button := $Layout/TopBar.get_node(button_path) as Control
		button.custom_minimum_size = Vector2(54.0, 54.0) if landscape else Vector2(50.0, 50.0)
	if target_panel.texture != null:
		target_panel.configure_fit_view()


func _sync_target_view(zoom: float, offset: Vector2) -> void:
	if _syncing_view: return
	_syncing_view = true
	target_panel.set_view(zoom, offset)
	_save_view(zoom, offset)
	_syncing_view = false


func _sync_base_view(zoom: float, offset: Vector2) -> void:
	if _syncing_view: return
	_syncing_view = true
	base_panel.set_view(zoom, offset)
	_save_view(zoom, offset)
	_syncing_view = false


func _restore_found(difference: Dictionary) -> void:
	var id := str(difference.id)
	found[id] = true
	var center := _difference_center(difference)
	if not is_anachronism_mode:
		base_panel.add_marker(center)
	target_panel.add_marker(center)


func _save_attempt() -> void:
	attempt_state["found"] = found.keys()
	attempt_state["hints_used"] = hints_used
	attempt_state["elapsed_ms"] = _elapsed_ms()
	ProgressStore.save_progress(str(level_data.level_id), attempt_state)


func _save_view(zoom: float, offset: Vector2) -> void:
	if attempt_state.is_empty(): return
	attempt_state["zoom"] = zoom
	attempt_state["view_offset_x"] = offset.x
	attempt_state["view_offset_y"] = offset.y
	_save_attempt()


func _elapsed_ms() -> int:
	return elapsed_before_session + Time.get_ticks_msec() - started_at_ms
