extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	_check_scene("res://scenes/bootstrap/bootstrap.tscn", failures)
	_check_scene("res://scenes/login/login.tscn", failures)
	_check_scene("res://scenes/home/home.tscn", failures)
	_check_scene("res://scenes/settings/settings.tscn", failures)
	_check_scene("res://scenes/level_select/level_select.tscn", failures)
	_check_scene("res://scenes/game/game.tscn", failures)
	_check_texture("res://assets/levels/global_demo_001/base.svg", failures)
	_check_texture("res://assets/levels/global_demo_001/target.svg", failures)
	_check_level(failures)
	_check_song_level(failures)
	_check_content_catalog(failures)
	if failures.is_empty():
		print("Godot smoke checks passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_scene(path: String, failures: Array[String]) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		failures.append("Could not load scene: %s" % path)
		return
	var instance := packed.instantiate()
	if instance == null:
		failures.append("Could not instantiate scene: %s" % path)
		return
	if path == "res://scenes/bootstrap/bootstrap.tscn":
		var offline_button := instance.get_node_or_null("SafeArea/Content/Start") as Button
		if offline_button == null or not offline_button.visible:
			failures.append("Offline start button must be visible immediately")
	instance.free()


func _check_texture(path: String, failures: Array[String]) -> void:
	_check_texture_size(path, Vector2i(1000, 700), failures)


func _check_texture_size(path: String, expected_size: Vector2i, failures: Array[String]) -> void:
	var texture := load(path) as Texture2D
	if texture == null:
		failures.append("Could not load texture: %s" % path)
		return
	if texture.get_width() != expected_size.x or texture.get_height() != expected_size.y:
		failures.append("Unexpected texture size: %s" % path)


func _check_level(failures: Array[String]) -> void:
	var file := FileAccess.open("res://assets/levels/global_demo_001/level.json", FileAccess.READ)
	if file == null:
		failures.append("Could not open local level")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Local level is not a JSON object")
		return
	if parsed.get("level_id") != "global_demo_001":
		failures.append("Unexpected local level id")
	if parsed.get("differences", []).size() != 5:
		failures.append("Demo level must contain five differences")


func _check_song_level(failures: Array[String]) -> void:
	var file := FileAccess.open("res://assets/levels/cn_song_bianjing_001/level.json", FileAccess.READ)
	if file == null:
		failures.append("Could not open Song level")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Song level is not a JSON object")
		return
	if parsed.get("level_id") != "cn_song_bianjing_001":
		failures.append("Unexpected Song level id")
	if parsed.get("mode") != "find_anachronism":
		failures.append("Song level must use find_anachronism mode")
	if not parsed.get("assets", {}).has("image"):
		failures.append("Anachronism level must have one image")
	if parsed.get("assets", {}).has("base") or parsed.get("assets", {}).has("target"):
		failures.append("Anachronism level must not expose comparison images")
	if parsed.get("differences", []).size() != 5:
		failures.append("Song level must contain five anachronisms")
	for difference_value in parsed.get("differences", []):
		var difference: Dictionary = difference_value
		if str(difference.get("label", "")).is_empty():
			failures.append("Anachronism is missing its display label")
		if str(difference.get("era", "")).is_empty():
			failures.append("Anachronism is missing its era")
		if str(difference.get("explanation", "")).is_empty():
			failures.append("Anachronism is missing its explanation")


func _check_content_catalog(failures: Array[String]) -> void:
	var file := FileAccess.open("res://config/content_catalog.json", FileAccess.READ)
	if file == null:
		failures.append("Could not open content catalog")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Content catalog is not a JSON object")
		return
	if str(parsed.get("default_region", "")) != "china":
		failures.append("China must be the first-version default region")
	var found_history_series := false
	for series_value in parsed.get("series", []):
		var series: Dictionary = series_value
		if str(series.get("id", "")) == "china_history_pack_v1":
			found_history_series = true
			if str(series.get("region", "")) != "china":
				failures.append("History series must belong to China")
			var levels: Array = series.get("levels", [])
			if levels.size() != 10:
				failures.append("History series must contain ten levels")
			for level_value in levels:
				var level: Dictionary = level_value
				if not bool(level.get("ready", false)):
					failures.append("History level must be ready: %s" % level.get("id", ""))
					continue
				var level_path := str(level.get("path", ""))
				var level_file := FileAccess.open(level_path, FileAccess.READ)
				if level_file == null:
					failures.append("History level is missing: %s" % level_path)
					continue
				var level_data = JSON.parse_string(level_file.get_as_text())
				if not level_data is Dictionary:
					failures.append("History level JSON is invalid: %s" % level_path)
					continue
				var image_path := str(level_data.get("assets", {}).get("image", {}).get("local_path", ""))
				_check_texture_size(image_path, Vector2i(1024, 1536), failures)
	if not found_history_series:
		failures.append("History series is missing from content catalog")
