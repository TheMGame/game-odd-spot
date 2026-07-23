class_name LevelLoader
extends RefCounted

const LOCAL_DEMO := "res://assets/levels/global_demo_001/level.json"


func load_first_level() -> Dictionary:
	var home := await ApiClient.get_home()
	if home.ok:
		var items: Array = home.data.get("data", {}).get("items", [])
		if not items.is_empty():
			var remote := await ApiClient.get_level(str(items[0].get("level_id", "")))
			if remote.ok:
				var level_data: Dictionary = remote.data.get("data", {})
				if level_data.get("level_id") == "global_demo_001":
					# P0 demo images are bundled, so their geometry is sourced from the matching local fixture.
					return _load_local_demo()
				return _validate(level_data)
	return _load_local_demo()


func _load_local_demo() -> Dictionary:
	var file := FileAccess.open(LOCAL_DEMO, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "LOCAL_LEVEL_MISSING"}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "LOCAL_LEVEL_INVALID"}
	return _validate(parsed)


func _validate(level_data: Dictionary) -> Dictionary:
	if int(level_data.get("schema_version", 0)) != 1:
		return {"ok": false, "error": "LEVEL_SCHEMA_UNSUPPORTED"}
	if str(level_data.get("mode", "")) != "spot_difference":
		return {"ok": false, "error": "LEVEL_MODE_UNSUPPORTED"}
	var differences: Array = level_data.get("differences", [])
	if differences.size() < 3 or differences.size() > 12:
		return {"ok": false, "error": "LEVEL_DIFFERENCES_INVALID"}
	return {"ok": true, "data": level_data}
