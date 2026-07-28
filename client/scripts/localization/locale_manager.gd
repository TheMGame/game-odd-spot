extends Node

signal locale_changed(locale: String)

const BUILTIN_LOCALES := ["zh-CN", "en-US"]

var _initialized := false


func _ready() -> void:
	initialize()


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var selected := Preferences.locale
	if selected.is_empty():
		selected = normalize_locale(TranslationServer.get_locale())
	set_locale_local(selected, false)


func initialize_web_default() -> void:
	initialize()
	if not OS.has_feature("web") or Preferences.locale_mode == "manual":
		return
	var result := await ApiClient.get_default_locale()
	if not result.ok:
		return
	var data: Dictionary = result.data.get("data", {})
	var target := normalize_locale(str(data.get("locale", "en-US")))
	if bool(data.get("requires_download", false)):
		var loaded := await LanguagePackManager.ensure_locale(target)
		if not loaded:
			target = "en-US"
	set_locale_local(target, false)


func apply_bootstrap(data: Dictionary) -> void:
	var supported: Array = data.get("supported_locales", [])
	var target := normalize_locale(str(data.get("locale", current_locale())))
	if not supported.is_empty() and target not in supported:
		target = "en-US"
	set_locale_local(target, false)


func select_locale(locale: String) -> Dictionary:
	var target := normalize_locale(locale)
	if target not in BUILTIN_LOCALES:
		var loaded := await LanguagePackManager.ensure_locale(target)
		if not loaded:
			return {"ok": false, "error": "LANGUAGE_PACK_DOWNLOAD_FAILED"}
	# UI language is a local preference and must switch even when an older server
	# does not yet expose the optional session-locale synchronization endpoint.
	set_locale_local(target, true)
	CatalogRepository.clear_cache()
	call_deferred("_sync_locale", target)
	return {
		"ok": true,
		"locale": target,
		"server_synced": false,
	}


func _sync_locale(locale: String) -> void:
	await ApiClient.update_locale(locale)


func set_locale_local(locale: String, manual: bool) -> void:
	var normalized := normalize_locale(locale)
	TranslationServer.set_locale(normalized)
	Preferences.set_value("localization", "locale", normalized)
	if manual:
		Preferences.set_value("localization", "locale_mode", "manual")
	locale_changed.emit(normalized)


func current_locale() -> String:
	return normalize_locale(TranslationServer.get_locale())


func normalize_locale(locale: String) -> String:
	var value := locale.strip_edges().replace("_", "-").to_lower()
	if value in ["zh", "zh-cn", "zh-hans", "zh-hans-cn"]:
		return "zh-CN"
	if value in ["en", "en-us"]:
		return "en-US"
	if value.length() == 5 and value.substr(2, 1) == "-":
		return "%s-%s" % [value.substr(0, 2), value.substr(3, 2).to_upper()]
	return "en-US" if value.is_empty() else locale.replace("_", "-")
