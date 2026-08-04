extends Node

const TTL_SECONDS := 300

signal request_finished

var _catalog: Dictionary = {}
var _loaded_at := 0
var _loading := false
var _last_result: Dictionary = {}


func _ready() -> void:
	_load_disk()


func get_catalog(force_refresh := false) -> Dictionary:
	if not force_refresh and not _catalog.is_empty():
		if Time.get_unix_time_from_system() - _loaded_at >= TTL_SECONDS and not _loading:
			_refresh_catalog()
		return {"ok": true, "data": _catalog.duplicate(true), "source": "cache"}
	return await _refresh_catalog()


func _refresh_catalog() -> Dictionary:
	if _loading:
		await request_finished
		return _last_result.duplicate(true)
	_loading = true
	var remote := await ApiClient.get_catalog()
	if remote.ok:
		_catalog = remote.data.duplicate(true)
		_loaded_at = int(Time.get_unix_time_from_system())
		_save_disk()
		_last_result = remote
	elif not _catalog.is_empty():
		_last_result = {"ok": true, "data": _catalog.duplicate(true), "source": "stale_cache"}
	else:
		_last_result = remote
	_loading = false
	request_finished.emit()
	return _last_result.duplicate(true)


func get_cached_catalog() -> Dictionary:
	return _catalog.duplicate(true)


func clear_cache() -> void:
	_catalog.clear()
	_loaded_at = 0


func _load_disk() -> void:
	var cache_path := _cache_path()
	if not FileAccess.file_exists(cache_path):
		return
	var parsed = JsonUtils.parse_string(FileAccess.get_file_as_string(cache_path))
	if parsed is Dictionary and parsed.get("catalog") is Dictionary:
		_catalog = parsed.catalog
		_loaded_at = int(parsed.get("loaded_at", 0))


func _save_disk() -> void:
	var file := FileAccess.open(_cache_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"loaded_at": _loaded_at, "catalog": _catalog}))


func _cache_path() -> String:
	var locale := TranslationServer.get_locale().replace("_", "-")
	return "user://catalog_%s.json" % locale.validate_filename()
