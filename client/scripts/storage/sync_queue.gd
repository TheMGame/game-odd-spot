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
		"user_id": SessionStore.user_id,
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
			continue
		var status := int(result.get("status", 0))
		if status >= 400 and status < 500 and status != 401 and status != 408 and status != 429:
			push_warning("Discarding permanent sync failure: %s" % result.get("error", "unknown"))
			_items.remove_at(item_index)
			_save()
			continue
		break
	_flushing = false


func pending_count() -> int:
	var count := 0
	for item in _items:
		if item is Dictionary and str(item.get("user_id", "")) == SessionStore.user_id:
			count += 1
	return count


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		# Legacy queue entries had no user_id and cannot safely be submitted as another account.
		_items = (parsed as Array).filter(func(item): return item is Dictionary and not str(item.get("user_id", "")).is_empty())


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist sync queue")
		return
	file.store_string(JSON.stringify(_items))
