extends Node

const SAVE_PATH := "user://session.json"

var installation_id: String = ""
var user_id: String = ""
var access_token: String = ""
var refresh_token: String = ""
var access_expires_at: int = 0
var username: String = ""
var avatar_url: String = ""
var user_server_token: String = ""
var user_server_refresh_token: String = ""


func _ready() -> void:
	_load()
	if installation_id.is_empty():
		installation_id = _new_installation_id()
		_save()


func update_session(data: Dictionary) -> void:
	user_id = str(data.get("user_id", ""))
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	if data.has("expires_in"):
		var expires_in := int(data.get("expires_in", 0))
		access_expires_at = int(Time.get_unix_time_from_system()) + expires_in if expires_in > 0 else access_expires_at
	username = str(data.get("username", data.get("nickname", username)))
	avatar_url = str(data.get("avatar_url", data.get("avatar", avatar_url)))
	user_server_token = str(data.get("user_server_token", user_server_token))
	user_server_refresh_token = str(data.get("user_server_refresh_token", user_server_refresh_token))
	_save()


func clear_session() -> void:
	user_id = ""
	access_token = ""
	refresh_token = ""
	access_expires_at = 0
	username = ""
	avatar_url = ""
	user_server_token = ""
	user_server_refresh_token = ""
	_save()


func has_access_token() -> bool:
	return not access_token.is_empty()


func has_valid_access_token() -> bool:
	if access_token.is_empty() or access_expires_at <= 0:
		return false
	return int(Time.get_unix_time_from_system()) + 30 < access_expires_at


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
	access_expires_at = int(parsed.get("access_expires_at", 0))
	username = str(parsed.get("username", ""))
	avatar_url = str(parsed.get("avatar_url", ""))
	user_server_token = str(parsed.get("user_server_token", ""))
	user_server_refresh_token = str(parsed.get("user_server_refresh_token", ""))


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
		"access_expires_at": access_expires_at,
		"username": username,
		"avatar_url": avatar_url,
		"user_server_token": user_server_token,
		"user_server_refresh_token": user_server_refresh_token,
	}))


func _new_installation_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(32).hex_encode()
