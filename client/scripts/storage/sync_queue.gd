extends Node

const SAVE_PATH := "user://sync_queue.json"
const DEAD_LETTER_PATH := "user://sync_dead_letters.json"
const DEAD_LETTER_LIMIT := 100

signal item_resolved(item: Dictionary, result: Dictionary)

var _items: Array = []
var _dead_letters: Array = []
var _recent_results: Dictionary = {}
var _flushing := false


func _ready() -> void:
	_load()
	_load_dead_letters()


func submit(path: String, body: Dictionary) -> Dictionary:
	return await submit_with_key(path, body, ApiClient.new_request_id())


func submit_with_key(path: String, body: Dictionary, idempotency_key: String) -> Dictionary:
	var item := {
		"id": ApiClient.new_request_id(),
		"user_id": SessionStore.user_id,
		"path": path,
		"body": body,
		"idempotency_key": idempotency_key,
		"created_at": Time.get_unix_time_from_system(),
	}
	_items.append(item)
	_save()
	await flush()
	if _recent_results.has(item.id):
		var result: Dictionary = _recent_results[item.id]
		_recent_results.erase(item.id)
		return result
	for pending in _items:
		if pending.get("id") == item.id:
			return _sync_result(true, "queued", 0, "SYNC_QUEUED")
	return _sync_result(false, "rejected", 0, "SYNC_RESULT_MISSING")


func flush() -> void:
	if _flushing or not SessionStore.has_access_token():
		return
	_flushing = true
	while true:
		var item_index := -1
		for index in _items.size():
			if str((_items[index] as Dictionary).get("user_id", "")) == SessionStore.user_id:
				item_index = index
				break
		if item_index < 0:
			break
		var item: Dictionary = _items[item_index]
		var result := await ApiClient.write_level(str(item.path), item.body, str(item.idempotency_key))
		if result.ok:
			_items.remove_at(item_index)
			_save()
			var synced := _sync_result(true, "synced", int(result.get("status", 200)), "")
			synced["response"] = result.get("data", {})
			_recent_results[item.id] = synced
			item_resolved.emit(item.duplicate(true), synced.duplicate(true))
			continue
		var status := int(result.get("status", 0))
		if status >= 400 and status < 500 and status != 401 and status != 408 and status != 429:
			var rejected := _sync_result(false, "rejected", status, str(result.get("error", "unknown")))
			rejected["response"] = result.get("data", {})
			_record_dead_letter(item, rejected)
			_recent_results[item.id] = rejected
			_items.remove_at(item_index)
			_save()
			item_resolved.emit(item.duplicate(true), rejected.duplicate(true))
			continue
		break
	_flushing = false


func pending_count() -> int:
	var count := 0
	for item in _items:
		if item is Dictionary and str(item.get("user_id", "")) == SessionStore.user_id:
			count += 1
	return count


func dead_letter_count() -> int:
	return _dead_letters.size()


func get_dead_letters() -> Array:
	return _dead_letters.duplicate(true)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JsonUtils.parse_string(file.get_as_text())
	if parsed is Array:
		# Legacy queue entries had no user_id and cannot safely be submitted as another account.
		_items = (parsed as Array).filter(func(item): return item is Dictionary and not str(item.get("user_id", "")).is_empty())


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist sync queue")
		return
	file.store_string(JSON.stringify(_items))


func _sync_result(ok: bool, state: String, status: int, error: String) -> Dictionary:
	return {
		"ok": ok,
		"state": state,
		"queued": state == "queued",
		"status": status,
		"error": error,
	}


func _record_dead_letter(item: Dictionary, result: Dictionary) -> void:
	var letter := item.duplicate(true)
	letter["status"] = result.status
	letter["error"] = result.error
	letter["response"] = result.get("response", {})
	letter["failed_at"] = Time.get_unix_time_from_system()
	_dead_letters.append(letter)
	while _dead_letters.size() > DEAD_LETTER_LIMIT:
		_dead_letters.pop_front()
	var file := FileAccess.open(DEAD_LETTER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_dead_letters))


func _load_dead_letters() -> void:
	if not FileAccess.file_exists(DEAD_LETTER_PATH):
		return
	var parsed = JsonUtils.parse_string(FileAccess.get_file_as_string(DEAD_LETTER_PATH))
	if parsed is Array:
		_dead_letters = parsed
