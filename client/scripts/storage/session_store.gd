extends Node

const SAVE_PATH := "user://session.json"

var installation_id: String = ""
var user_id: String = ""
var access_token: String = ""
var refresh_token: String = ""


func _ready() -> void:
	_load()
	if installation_id.is_empty():
		installation_id = _new_installation_id()
		_save()


func update_session(data: Dictionary) -> void:
	user_id = str(data.get("user_id", ""))
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	_save()


func clear_session() -> void:
	user_id = ""
	access_token = ""
	refresh_token = ""
	_save()


func has_access_token() -> bool:
	return not access_token.is_empty()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	installation_id = str(parsed.get("installation_id", ""))
	user_id = str(parsed.get("user_id", ""))
	access_token = str(parsed.get("access_token", ""))
	refresh_token = str(parsed.get("refresh_token", ""))


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not persist session")
		return
	file.store_string(JSON.stringify({
		"installation_id": installation_id,
		"user_id": user_id,
		"access_token": access_token,
		"refresh_token": refresh_token,
	}))


func _new_installation_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(32).hex_encode()
