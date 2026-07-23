extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	_check_scene("res://scenes/bootstrap/bootstrap.tscn", failures)
	_check_scene("res://scenes/home/home.tscn", failures)
	_check_scene("res://scenes/settings/settings.tscn", failures)
	_check_scene("res://scenes/game/game.tscn", failures)
	_check_texture("res://assets/levels/global_demo_001/base.svg", failures)
	_check_texture("res://assets/levels/global_demo_001/target.svg", failures)
	_check_level(failures)
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
	instance.free()


func _check_texture(path: String, failures: Array[String]) -> void:
	var texture := load(path) as Texture2D
	if texture == null:
		failures.append("Could not load texture: %s" % path)
		return
	if texture.get_width() != 1000 or texture.get_height() != 700:
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
