extends Control

@onready var base_panel: SpotImage = $Layout/BasePanel
@onready var target_panel: SpotImage = $Layout/TargetPanel
@onready var counter: Label = $Layout/TopBar/Counter
@onready var hint_button: Button = $Layout/TopBar/Hint
@onready var status_label: Label = $Layout/Status
@onready var complete_panel: PanelContainer = $CompletePanel

var level_data: Dictionary
var differences: Array = []
var found: Dictionary = {}
var attempt_id := ""
var started_at_ms := 0
var hints_used := 0
var _syncing_view := false
var attempt_state: Dictionary = {}
var elapsed_before_session := 0


func _ready() -> void:
	base_panel.normalized_pressed.connect(_on_image_pressed)
	target_panel.normalized_pressed.connect(_on_image_pressed)
	base_panel.view_changed.connect(_sync_target_view)
	target_panel.view_changed.connect(_sync_base_view)
	hint_button.pressed.connect(_use_hint)
	$Layout/TopBar/Report.pressed.connect(_report_level)
	$Layout/TopBar/Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
	_load_level()


func _load_level() -> void:
	var loaded := await LevelLoader.new().load_first_level()
	if not loaded.ok:
		status_label.text = "关卡加载失败：%s" % loaded.error
		return
	level_data = loaded.data
	differences = level_data.get("differences", [])
	var assets: Dictionary = level_data.get("assets", {})
	var cache := AssetCache.new()
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
	var restored_zoom := float(attempt_state.get("zoom", 1.0))
	var restored_offset := Vector2(float(attempt_state.get("view_offset_x", 0.0)), float(attempt_state.get("view_offset_y", 0.0)))
	base_panel.set_view(restored_zoom, restored_offset)
	target_panel.set_view(restored_zoom, restored_offset)
	_update_counter()
	status_label.text = "找出所有不同之处；滚轮缩放，拖动查看"
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
	base_panel.add_marker(center)
	target_panel.add_marker(center)
	_save_attempt()
	_update_counter()
	status_label.text = "找到了！"
	if Preferences.vibration_enabled:
		Input.vibrate_handheld(35)
	Analytics.track("difference_found", {"level_id": level_data.level_id, "difference_id": id, "found_at_ms": _elapsed_ms()})
	_sync_progress(id)
	if found.size() == differences.size():
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
	attempt_state["elapsed_ms"] = elapsed
	ProgressStore.mark_completed(str(level_data.level_id), attempt_state)
	if not result.get("queued", false):
		$CompletePanel/Message.text = "完成！\n获得 1 次提示"
	else:
		$CompletePanel/Message.text = "本地完成\n等待联网同步"
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
	hint_button.disabled = found.size() == differences.size()


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
