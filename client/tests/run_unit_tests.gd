extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	_test_level_validator(failures)
	if failures.is_empty():
		print("Godot unit checks passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_level_validator(failures: Array[String]) -> void:
	var valid := _valid_level()
	_expect(LevelValidator.validate(valid).ok, "valid level rejected", failures)
	var duplicate := valid.duplicate(true)
	duplicate.differences[1].id = duplicate.differences[0].id
	_expect(not LevelValidator.validate(duplicate).ok, "duplicate difference id accepted", failures)
	var outside := valid.duplicate(true)
	outside.differences[0].x = 1.5
	_expect(not LevelValidator.validate(outside).ok, "out-of-range circle accepted", failures)
	var missing_asset := valid.duplicate(true)
	missing_asset.assets.erase("target")
	_expect(not LevelValidator.validate(missing_asset).ok, "missing target asset accepted", failures)
	var bad_polygon := valid.duplicate(true)
	bad_polygon.differences[2] = {"id": "d3", "shape": "polygon", "points": [{"x": 0.1, "y": 0.1}, {"x": 0.2, "y": 0.2}]}
	_expect(not LevelValidator.validate(bad_polygon).ok, "short polygon accepted", failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _valid_level() -> Dictionary:
	var hash := "a".repeat(64)
	var asset := {"asset_id": "asset_0001", "url": "https://example.com/a.webp", "sha256": hash}
	return {
		"schema_version": 1,
		"level_id": "level_0001",
		"mode": "spot_difference",
		"assets": {"width": 1024, "height": 768, "base": asset.duplicate(), "target": asset.duplicate()},
		"differences": [
			{"id": "d1", "shape": "circle", "x": 0.2, "y": 0.2, "radius": 0.05},
			{"id": "d2", "shape": "circle", "x": 0.5, "y": 0.5, "radius": 0.05},
			{"id": "d3", "shape": "polygon", "points": [{"x": 0.1, "y": 0.1}, {"x": 0.2, "y": 0.1}, {"x": 0.2, "y": 0.2}]},
		],
	}
