extends Node

signal download_progress(locale: String, received: int, total: int)
signal pack_loaded(locale: String, version: int)
signal pack_failed(locale: String, error: String)

const CACHE_ROOT := "user://i18n"
const BUILTIN_LOCALES := ["zh-CN", "en-US"]

var _manifest: Dictionary = {}


func refresh_manifest() -> Dictionary:
	var result := await ApiClient.get_locales()
	if not result.ok:
		return result
	_manifest.clear()
	for item in result.data.get("data", {}).get("locales", []):
		if item is Dictionary:
			_manifest[str(item.get("locale", ""))] = item
	return result


func available_locales() -> Array:
	if _manifest.is_empty():
		await refresh_manifest()
	return _manifest.values()


func ensure_locale(locale: String) -> bool:
	if locale in BUILTIN_LOCALES:
		return true
	if _manifest.is_empty():
		var manifest_result := await refresh_manifest()
		if not manifest_result.ok:
			return false
	if not _manifest.has(locale):
		return false
	var item: Dictionary = _manifest[locale]
	var version := int(item.get("version", 0))
	var directory := "%s/%s/%s" % [CACHE_ROOT, locale, version]
	var pack_path := "%s/language.pck" % directory
	if FileAccess.file_exists(pack_path) and _verify_file(pack_path, item):
		return _load_pack(locale, version, pack_path, str(item.get("resource_path", "")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var temporary_path := pack_path + ".download"
	var downloaded := await _download_pack(locale, item, temporary_path)
	if not downloaded or not _verify_file(temporary_path, item):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		pack_failed.emit(locale, "LANGUAGE_PACK_INVALID")
		return false
	var absolute_temp := ProjectSettings.globalize_path(temporary_path)
	var absolute_pack := ProjectSettings.globalize_path(pack_path)
	if FileAccess.file_exists(pack_path):
		DirAccess.remove_absolute(absolute_pack)
	if DirAccess.rename_absolute(absolute_temp, absolute_pack) != OK:
		pack_failed.emit(locale, "LANGUAGE_PACK_STORE_FAILED")
		return false
	return _load_pack(locale, version, pack_path, str(item.get("resource_path", "")))


func _download_pack(locale: String, item: Dictionary, destination: String) -> bool:
	var request := HTTPRequest.new()
	request.download_file = destination
	request.timeout = 30.0
	add_child(request)
	request.request_progress.connect(func(downloaded: int, total: int) -> void:
		download_progress.emit(locale, downloaded, total)
	)
	var error := request.request(str(item.get("download_url", "")))
	if error != OK:
		request.queue_free()
		return false
	var response: Array = await request.request_completed
	request.queue_free()
	return int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) >= 200 and int(response[1]) < 300


func _verify_file(path: String, item: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var expected_size := int(item.get("size_bytes", 0))
	if expected_size > 0 and file.get_length() != expected_size:
		return false
	var expected_hash := str(item.get("sha256", "")).to_lower()
	return expected_hash.is_empty() or FileAccess.get_sha256(path).to_lower() == expected_hash


func _load_pack(locale: String, version: int, path: String, resource_path: String) -> bool:
	if not ProjectSettings.load_resource_pack(path, false):
		pack_failed.emit(locale, "LANGUAGE_PACK_LOAD_FAILED")
		return false
	if resource_path.is_empty():
		pack_failed.emit(locale, "LANGUAGE_RESOURCE_PATH_MISSING")
		return false
	var translation := ResourceLoader.load(resource_path, "Translation", ResourceLoader.CACHE_MODE_REPLACE)
	if not translation is Translation:
		pack_failed.emit(locale, "LANGUAGE_RESOURCE_LOAD_FAILED")
		return false
	TranslationServer.add_translation(translation)
	Preferences.set_value("localization", "locale_pack_version", version)
	pack_loaded.emit(locale, version)
	return true
