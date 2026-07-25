class_name LevelLoader
extends RefCounted

const LOCAL_DEMO := "res://assets/levels/global_demo_001/level.json"
const CONTENT_CATALOG := "res://config/content_catalog.json"
static var selected_level_path := ""
static var selected_level_id := ""


static func select_level(path: String) -> void:
	selected_level_path = path
	selected_level_id = ""


static func select_remote_level(level_id: String) -> void:
	selected_level_id = level_id
	selected_level_path = ""


static func clear_selection() -> void:
	selected_level_path = ""
	selected_level_id = ""


func load_first_level() -> Dictionary:
	if not selected_level_id.is_empty():
		var remote := await ApiClient.get_level(selected_level_id)
		if remote.ok:
			return _validate(remote.data.get("data", {}))
	if not selected_level_path.is_empty():
		return _load_local_level(selected_level_path)
	var configured_path := _configured_ready_level_path()
	if not configured_path.is_empty():
		return _load_local_level(configured_path)
	var home := await ApiClient.get_home()
	if home.ok:
		var items: Array = home.data.get("data", {}).get("items", [])
		if not items.is_empty():
			var remote := await ApiClient.get_level(str(items[0].get("level_id", "")))
			if remote.ok:
				var level_data: Dictionary = remote.data.get("data", {})
				if level_data.get("level_id") == "global_demo_001":
					# P0 demo images are bundled, so their geometry is sourced from the matching local fixture.
					return _load_local_level(LOCAL_DEMO)
				return _validate(level_data)
	return _load_configured_level()


func _load_configured_level() -> Dictionary:
	var configured_path := _configured_ready_level_path()
	if not configured_path.is_empty():
		return _load_local_level(configured_path)
	var catalog_result := _read_json(CONTENT_CATALOG)
	if not catalog_result.ok:
		return _load_local_level(LOCAL_DEMO)
	var catalog: Dictionary = catalog_result.data
	var fallback := str(catalog.get("fallback_level", LOCAL_DEMO))
	return _load_local_level(fallback)


func _configured_ready_level_path() -> String:
	var catalog_result := _read_json(CONTENT_CATALOG)
	if not catalog_result.ok:
		return ""
	var catalog: Dictionary = catalog_result.data
	var default_region := str(catalog.get("default_region", ""))
	var default_series := str(catalog.get("default_series", ""))
	for series_value in catalog.get("series", []):
		var series: Dictionary = series_value
		if not bool(series.get("enabled", false)):
			continue
		if str(series.get("id", "")) != default_series:
			continue
		if str(series.get("region", "")) != default_region:
			continue
		var first_ready_path := ""
		for level_value in series.get("levels", []):
			var level: Dictionary = level_value
			if bool(level.get("ready", false)):
				var path := str(level.get("path", ""))
				if first_ready_path.is_empty():
					first_ready_path = path
				if not ProgressStore.is_completed(str(level.get("id", "")), int(level.get("version", 1))):
					return path
		return first_ready_path
	return ""


func _load_local_level(path: String) -> Dictionary:
	var parsed_result := _read_json(path)
	if not parsed_result.ok:
		return parsed_result
	return _validate(parsed_result.data)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "LOCAL_LEVEL_MISSING"}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "LOCAL_LEVEL_INVALID"}
	return {"ok": true, "data": parsed}


func _validate(level_data: Dictionary) -> Dictionary:
	if int(level_data.get("schema_version", 0)) != 1:
		return {"ok": false, "error": "LEVEL_SCHEMA_UNSUPPORTED"}
	if not str(level_data.get("mode", "")) in ["spot_difference", "find_anachronism"]:
		return {"ok": false, "error": "LEVEL_MODE_UNSUPPORTED"}
	var differences: Array = level_data.get("differences", [])
	if differences.size() < 3 or differences.size() > 12:
		return {"ok": false, "error": "LEVEL_DIFFERENCES_INVALID"}
	return {"ok": true, "data": level_data}
