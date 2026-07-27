class_name LevelLoader
extends RefCounted

static var selected_level_id := ""
static var selected_series_id := ""


static func select_series(series_id: String) -> void:
	selected_series_id = series_id


static func select_remote_level(level_id: String) -> void:
	selected_level_id = level_id


static func clear_selection() -> void:
	selected_level_id = ""


func select_next_level(current_level_id: String) -> bool:
	if not selected_series_id.is_empty():
		var remote := await CatalogRepository.get_catalog()
		if remote.ok:
			var response_data: Dictionary = remote.data.get("data", {})
			var remote_series := _array_or_empty(response_data.get("series"))
			for raw_series in remote_series:
				var series: Dictionary = raw_series
				if str(series.get("id", "")) != selected_series_id:
					continue
				var levels := _array_or_empty(series.get("levels"))
				for index in levels.size():
					var level: Dictionary = levels[index]
					if str(level.get("id", "")) == current_level_id and index + 1 < levels.size():
						select_remote_level(str((levels[index + 1] as Dictionary).get("id", "")))
						return not selected_level_id.is_empty()
				return false

	return false


func prefetch_next_level(owner: Node, current_level_id: String) -> void:
	if selected_series_id.is_empty() or not is_instance_valid(owner):
		return
	var remote := await CatalogRepository.get_catalog()
	if not remote.ok:
		return
	var next_level_id := ""
	var response_data: Dictionary = remote.data.get("data", {})
	for raw_series in _array_or_empty(response_data.get("series")):
		var series: Dictionary = raw_series
		if str(series.get("id", "")) != selected_series_id:
			continue
		var levels := _array_or_empty(series.get("levels"))
		for index in levels.size():
			var level: Dictionary = levels[index]
			if str(level.get("id", "")) == current_level_id and index + 1 < levels.size():
				next_level_id = str((levels[index + 1] as Dictionary).get("id", ""))
				break
		break
	if next_level_id.is_empty():
		return
	var level_result := await ApiClient.get_level(next_level_id)
	if not level_result.ok or not is_instance_valid(owner):
		return
	var image_asset: Dictionary = level_result.data.get("data", {}).get("assets", {}).get("image", {})
	await AssetCache.new().load_texture(owner, image_asset)


func load_first_level() -> Dictionary:
	if not selected_level_id.is_empty():
		var remote := await ApiClient.get_level(selected_level_id)
		if remote.ok:
			return _validate(remote.data.get("data", {}))
		return remote
	var home := await ApiClient.get_home()
	if home.ok:
		var items: Array = home.data.get("data", {}).get("items", [])
		if not items.is_empty():
			var remote := await ApiClient.get_level(str(items[0].get("level_id", "")))
			if remote.ok:
				return _validate(remote.data.get("data", {}))
			return remote
		return {"ok": false, "error": "NO_REMOTE_LEVEL"}
	return home


func _validate(level_data: Dictionary) -> Dictionary:
	return LevelValidator.validate(level_data)


func _array_or_empty(value: Variant) -> Array:
	return value if value is Array else []
