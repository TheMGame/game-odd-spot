extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	for path in [
		"res://scenes/bootstrap/bootstrap.tscn",
		"res://scenes/login/login.tscn",
		"res://scenes/home/home.tscn",
		"res://scenes/settings/settings.tscn",
		"res://scenes/level_select/level_select.tscn",
		"res://scenes/game/game.tscn",
	]:
		_check_scene(path, failures)
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
