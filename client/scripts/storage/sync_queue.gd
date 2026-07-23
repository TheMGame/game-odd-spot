extends Node

const SAVE_PATH := "user://sync_queue.json"

var _items: Array = []
var _flushing := false


func _ready() -> void:
	_load()


func submit(path: String, body: Dictionary) -> Dictionary:
	return await submit_with_key(path, body, ApiClient.new_request_id())


func submit_with_key(path: String, body: Dictionary, idempotency_key: String) -> Dictionary:
	var item := {
		"id": ApiClient.new_request_id(),
		"path": path,
		"body": body,
		"idempotency_key": idempotency_key,
		"created_at": Time.get_unix_time_from_system(),
	}
	_items.append(item)
	_save()
	await flush()
	for pending in _items:
		if pending.get("id") == item.id:
			return {"ok": true, "queued": true}
	return {"ok": true, "queued": false}


func flush() -> void:
	if _flushing or not SessionStore.has_access_token():
		return
	_flushing = true
	while not _items.is_empty():
		var item: Dictionary = _items[0]
		var result := await ApiClient.write_level(str(item.path), item.body, str(item.idempotency_key))
		if result.ok:
			_items.pop_front()
			_save()
			continue
		var status := int(result.get("status", 0))
		if status >= 400 and status < 500 and status != 401 and status != 408 and status != 429:
			push_warning("Discarding permanent sync failure: %s" % result.get("error", "unknown"))
			_items.pop_front()
			_save()
			continue
		break
	_flushing = false


func pending_count() -> int:
	return _items.size()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_items = parsed


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist sync queue")
		return
	file.store_string(JSON.stringify(_items))
