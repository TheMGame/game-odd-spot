class_name AssetCache
extends RefCounted

const CACHE_DIR := "user://asset_cache"
const CACHE_LIMIT_BYTES := 300 * 1024 * 1024


func load_texture(owner: Node, asset: Dictionary) -> Dictionary:
	var local_path := str(asset.get("local_path", ""))
	if not local_path.is_empty():
		var texture := load(local_path) as Texture2D
		if texture == null:
			return {"ok": false, "error": "LOCAL_ASSET_INVALID"}
		return {"ok": true, "texture": texture}

	var asset_id := str(asset.get("asset_id", ""))
	var expected_hash := str(asset.get("sha256", ""))
	var url := str(asset.get("url", ""))
	if asset_id.is_empty() or expected_hash.length() != 64 or url.is_empty():
		return {"ok": false, "error": "ASSET_DESCRIPTOR_INVALID"}
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var cache_path := "%s/%s.bin" % [CACHE_DIR, asset_id]
	if FileAccess.file_exists(cache_path):
		var cached := FileAccess.get_file_as_bytes(cache_path)
		if _sha256(cached) == expected_hash:
			return _decode_texture(cached, str(asset.get("content_type", "")))

	var request := HTTPRequest.new()
	owner.add_child(request)
	var start_error := request.request(url)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "ASSET_DOWNLOAD_START_FAILED"}
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300:
		return {"ok": false, "error": "ASSET_DOWNLOAD_FAILED"}
	var bytes: PackedByteArray = response[3]
	if _sha256(bytes) != expected_hash:
		return {"ok": false, "error": "ASSET_HASH_MISMATCH"}
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
	_prune_cache()
	return _decode_texture(bytes, str(asset.get("content_type", "")))


func _decode_texture(bytes: PackedByteArray, content_type: String) -> Dictionary:
	var image := Image.new()
	var error := ERR_INVALID_DATA
	match content_type:
		"image/webp": error = image.load_webp_from_buffer(bytes)
		"image/png": error = image.load_png_from_buffer(bytes)
		"image/svg+xml": error = image.load_svg_from_buffer(bytes)
	if error != OK:
		return {"ok": false, "error": "ASSET_DECODE_FAILED"}
	return {"ok": true, "texture": ImageTexture.create_from_image(image)}


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _prune_cache() -> void:
	var entries: Array[Dictionary] = []
	var total := 0
	for filename in DirAccess.get_files_at(CACHE_DIR):
		var path := "%s/%s" % [CACHE_DIR, filename]
		var size := FileAccess.get_file_as_bytes(path).size()
		total += size
		entries.append({"path": path, "size": size, "modified": FileAccess.get_modified_time(path)})
	if total <= CACHE_LIMIT_BYTES:
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.modified) < int(b.modified))
	for entry in entries:
		if total <= CACHE_LIMIT_BYTES:
			break
		var absolute := ProjectSettings.globalize_path(str(entry.path))
		if DirAccess.remove_absolute(absolute) == OK:
			total -= int(entry.size)
