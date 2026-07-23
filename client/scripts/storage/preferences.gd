extends Node

const PATH := "user://settings.cfg"

var analytics_enabled := true
var vibration_enabled := true
var large_markers := false


func _ready() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	analytics_enabled = bool(config.get_value("privacy", "analytics", true))
	vibration_enabled = bool(config.get_value("gameplay", "vibration", true))
	large_markers = bool(config.get_value("accessibility", "large_markers", false))


func set_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(section, key, value)
	config.save(PATH)
	match "%s/%s" % [section, key]:
		"privacy/analytics": analytics_enabled = bool(value)
		"gameplay/vibration": vibration_enabled = bool(value)
		"accessibility/large_markers": large_markers = bool(value)
