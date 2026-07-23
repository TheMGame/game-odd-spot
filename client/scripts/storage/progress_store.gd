extends Node

const SAVE_PATH := "user://progress.json"

var _levels: Dictionary = {}


func _ready() -> void:
	_load()


func get_or_create(level_id: String, level_version: int) -> Dictionary:
	var existing: Dictionary = _levels.get(level_id, {})
	if not existing.is_empty() and existing.get("state") != "completed" and int(existing.get("level_version", 0)) == level_version:
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
	_save()
	return created.duplicate(true)


func save_progress(level_id: String, attempt: Dictionary) -> void:
	_levels[level_id] = attempt.duplicate(true)
	_save()


func mark_completed(level_id: String, attempt: Dictionary) -> void:
	attempt["state"] = "completed"
	_levels[level_id] = attempt.duplicate(true)
	_save()


func clear_level(level_id: String) -> void:
	_levels.erase(level_id)
	_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_levels = parsed


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist local progress")
		return
	file.store_string(JSON.stringify(_levels))
