class_name LevelValidator
extends RefCounted

const MODES := ["spot_difference", "find_anachronism"]


static func validate(level: Dictionary) -> Dictionary:
	if str(level.get("level_id", "")).is_empty():
		return _failure("LEVEL_ID_MISSING")
	if int(level.get("schema_version", 0)) != 1:
		return _failure("LEVEL_SCHEMA_UNSUPPORTED")
	var mode := str(level.get("mode", ""))
	if mode not in MODES:
		return _failure("LEVEL_MODE_UNSUPPORTED")
	var assets = level.get("assets")
	if not assets is Dictionary:
		return _failure("LEVEL_ASSETS_INVALID")
	if int(assets.get("width", 0)) < 1 or int(assets.get("width", 0)) > 8192 or int(assets.get("height", 0)) < 1 or int(assets.get("height", 0)) > 8192:
		return _failure("LEVEL_DIMENSIONS_INVALID")
	var required_assets := ["image"] if mode == "find_anachronism" else ["base", "target"]
	for key in required_assets:
		var asset = assets.get(key)
		if not asset is Dictionary or not _valid_asset(asset):
			return _failure("LEVEL_ASSET_INVALID_%s" % key.to_upper())
	var differences = level.get("differences")
	if not differences is Array or differences.size() < 3 or differences.size() > 12:
		return _failure("LEVEL_DIFFERENCES_INVALID")
	var ids := {}
	for raw in differences:
		if not raw is Dictionary:
			return _failure("LEVEL_DIFFERENCE_INVALID")
		var difference: Dictionary = raw
		var id := str(difference.get("id", ""))
		if id.is_empty() or ids.has(id):
			return _failure("LEVEL_DIFFERENCE_ID_INVALID")
		ids[id] = true
		var shape := str(difference.get("shape", ""))
		if shape == "circle":
			if not _unit_number(difference.get("x")) or not _unit_number(difference.get("y")):
				return _failure("LEVEL_CIRCLE_COORDINATES_INVALID")
			var radius = difference.get("radius")
			if not _finite_number(radius) or float(radius) <= 0.0 or float(radius) > 0.25:
				return _failure("LEVEL_CIRCLE_RADIUS_INVALID")
		elif shape == "polygon":
			var points = difference.get("points")
			if not points is Array or points.size() < 3 or points.size() > 64:
				return _failure("LEVEL_POLYGON_INVALID")
			for point in points:
				if not point is Dictionary or not _unit_number(point.get("x")) or not _unit_number(point.get("y")):
					return _failure("LEVEL_POLYGON_COORDINATES_INVALID")
		else:
			return _failure("LEVEL_SHAPE_UNSUPPORTED")
	return {"ok": true, "data": level}


static func _valid_asset(asset: Dictionary) -> bool:
	var url := str(asset.get("url", ""))
	var hash := str(asset.get("sha256", ""))
	return not str(asset.get("asset_id", "")).is_empty() and url.begins_with("https://") and hash.length() == 64 and hash.is_valid_hex_number()


static func _unit_number(value: Variant) -> bool:
	return _finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
