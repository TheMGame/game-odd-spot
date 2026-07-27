extends Node

const SAVE_PATH := "user://progress.json"

var _users: Dictionary = {}


func _ready() -> void:
	_load()
	if not SyncQueue.item_resolved.is_connected(_on_sync_item_resolved):
		SyncQueue.item_resolved.connect(_on_sync_item_resolved)


func get_or_create(level_id: String, level_version: int) -> Dictionary:
	var _levels := _current_levels()
	var existing: Dictionary = _levels.get(level_id, {})
	if not existing.is_empty() and not str(existing.get("state", "")) in ["synced", "completed"] and int(existing.get("level_version", 0)) == level_version:
		return existing.duplicate(true)
	var created := {
		"attempt_id": ApiClient.new_request_id(),
		"start_idempotency_key": ApiClient.new_request_id(),
		"level_version": level_version,
		"state": "in_progress",
		"found": [],
		"hints_used": 0,
		"elapsed_ms": 0,
		"zoom": 1.0,
		"view_offset_x": 0.0,
		"view_offset_y": 0.0,
	}
	_levels[level_id] = created
	_save_levels(_levels)
	return created.duplicate(true)


func save_progress(level_id: String, attempt: Dictionary) -> void:
	var _levels := _current_levels()
	_levels[level_id] = attempt.duplicate(true)
	_save_levels(_levels)


func mark_completed(level_id: String, attempt: Dictionary, sync_state := "local_completed") -> void:
	var _levels := _current_levels()
	attempt["state"] = sync_state
	_levels[level_id] = attempt.duplicate(true)
	_save_levels(_levels)


func clear_level(level_id: String) -> void:
	var _levels := _current_levels()
	_levels.erase(level_id)
	_save_levels(_levels)


func is_completed(level_id: String, level_version: int) -> bool:
	var _levels := _current_levels()
	var saved: Dictionary = _levels.get(level_id, {})
	return str(saved.get("state", "")) in ["local_completed", "sync_queued", "synced", "completed"] and int(saved.get("level_version", 0)) == level_version


func update_sync_state(level_id: String, sync_state: String) -> void:
	var levels := _current_levels()
	var saved: Dictionary = levels.get(level_id, {})
	if saved.is_empty():
		return
	saved["state"] = sync_state
	levels[level_id] = saved
	_save_levels(levels)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("users") is Dictionary:
		_users = parsed.users


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist local progress")
		return
	file.store_string(JSON.stringify({"users": _users}))


func _current_levels() -> Dictionary:
	var user_id := SessionStore.user_id
	if user_id.is_empty():
		return {}
	var levels: Dictionary = _users.get(user_id, {})
	return levels.duplicate(true)


func _save_levels(levels: Dictionary) -> void:
	if SessionStore.user_id.is_empty():
		return
	_users[SessionStore.user_id] = levels.duplicate(true)
	_save()


func _on_sync_item_resolved(item: Dictionary, result: Dictionary) -> void:
	var path := str(item.get("path", ""))
	if not path.ends_with("/complete"):
		return
	var parts := path.split("/")
	if parts.size() < 4:
		return
	var level_id := str(parts[3]).uri_decode()
	if str(result.get("state", "")) == "synced":
		update_sync_state(level_id, "synced")
	elif str(result.get("state", "")) == "rejected":
		update_sync_state(level_id, "rejected")
