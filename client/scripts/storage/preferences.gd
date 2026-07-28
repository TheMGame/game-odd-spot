extends Node

const PATH := "user://settings.cfg"

var analytics_enabled := true
var vibration_enabled := true
var music_enabled := true
var effects_enabled := true
var large_markers := false
var locale := ""
var locale_mode := "automatic"
var locale_pack_version := 0


func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	analytics_enabled = bool(config.get_value("privacy", "analytics", true))
	vibration_enabled = bool(config.get_value("gameplay", "vibration", true))
	music_enabled = bool(config.get_value("audio", "music", true))
	effects_enabled = bool(config.get_value("audio", "effects", true))
	large_markers = bool(config.get_value("accessibility", "large_markers", false))
	locale = str(config.get_value("localization", "locale", ""))
	locale_mode = str(config.get_value("localization", "locale_mode", "automatic"))
	locale_pack_version = int(config.get_value("localization", "locale_pack_version", 0))


func set_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(section, key, value)
	config.save(PATH)
	match "%s/%s" % [section, key]:
		"privacy/analytics": analytics_enabled = bool(value)
		"gameplay/vibration": vibration_enabled = bool(value)
		"audio/music": music_enabled = bool(value)
		"audio/effects": effects_enabled = bool(value)
		"accessibility/large_markers": large_markers = bool(value)
		"localization/locale": locale = str(value)
		"localization/locale_mode": locale_mode = str(value)
		"localization/locale_pack_version": locale_pack_version = int(value)
