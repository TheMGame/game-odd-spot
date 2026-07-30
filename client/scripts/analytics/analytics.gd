extends Node

const SAVE_PATH := "user://analytics_queue.json"
const MAX_QUEUE := 1000

var _events: Array = []
var _session_id := ""
var _flushing := false
var _enabled := true


func _ready() -> void:
	_enabled = Preferences.analytics_enabled
	_session_id = ApiClient.new_request_id()
	_load()
	track("app_open")


func track(event_type: String, payload := {}) -> void:
	if not _enabled:
		return
	_events.append({
		"event_id": ApiClient.new_request_id(),
		"session_id": _session_id,
		"event_type": event_type,
		"market": "global",
		"locale": TranslationServer.get_locale(),
		"app_version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"occurred_at": Time.get_datetime_string_from_system(true) + "Z",
		"payload": payload,
	})
	if _events.size() > MAX_QUEUE:
		_events.pop_front()
	_save()
	if _events.size() >= 20:
		flush()


func flush() -> void:
	if _flushing or _events.is_empty() or not SessionStore.has_access_token():
		return
	_flushing = true
	while not _events.is_empty():
		var batch := _events.slice(0, mini(100, _events.size()))
		var result := await ApiClient.send_events(batch)
		if not result.ok:
			break
		_events = _events.slice(batch.size())
		_save()
	_flushing = false


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_events.clear()
		_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parsed = JsonUtils.parse_string(file.get_as_text())
	if parsed is Array: _events = parsed


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(_events))
