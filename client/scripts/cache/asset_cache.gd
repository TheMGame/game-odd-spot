class_name AssetCache
extends RefCounted

const CACHE_DIR := "user://asset_cache"
# Images are versioned by asset hash (or URL for legacy thumbnails) and change
# infrequently. Keep a generous on-device cache so normal navigation does not
# repeatedly consume CDN bandwidth.
const CACHE_LIMIT_BYTES := 256 * 1024 * 1024
const MAX_ASSET_BYTES := 25 * 1024 * 1024
const SERIES_TEXTURE_MAX_DIMENSION := 1024
const AVATAR_TEXTURE_MAX_DIMENSION := 256
const DOWNLOAD_TIMEOUT_SECONDS := 30.0
static var _audited_hosts: Dictionary = {}


func load_texture(owner: Node, asset: Dictionary) -> Dictionary:
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
	_audit_asset_host(url)
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = DOWNLOAD_TIMEOUT_SECONDS
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
	if bytes.size() > MAX_ASSET_BYTES:
		return {"ok": false, "error": "ASSET_TOO_LARGE"}
	if _sha256(bytes) != expected_hash:
		return {"ok": false, "error": "ASSET_HASH_MISMATCH"}
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
	_prune_cache()
	return _decode_texture(bytes, str(asset.get("content_type", "")))


func load_texture_url(owner: Node, url: String, variant := "remote") -> Dictionary:
	if url.is_empty():
		return {"ok": false, "error": "ASSET_URL_MISSING"}
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var cache_path := "%s/url_%s_%s.bin" % [CACHE_DIR, variant.validate_filename(), url.md5_text()]
	var max_dimension := _max_dimension_for_variant(variant)
	if FileAccess.file_exists(cache_path):
		var cached := FileAccess.get_file_as_bytes(cache_path)
		var cached_texture := _decode_texture(cached, "", max_dimension)
		if cached_texture.ok:
			return cached_texture
	var request := HTTPRequest.new()
	_audit_asset_host(url)
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = DOWNLOAD_TIMEOUT_SECONDS
	owner.add_child(request)
	if request.request(url) != OK:
		request.queue_free()
		return {"ok": false, "error": "ASSET_DOWNLOAD_START_FAILED"}
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300:
		return {"ok": false, "error": "ASSET_DOWNLOAD_FAILED"}
	var bytes: PackedByteArray = response[3]
	if bytes.size() > MAX_ASSET_BYTES:
		return {"ok": false, "error": "ASSET_TOO_LARGE"}
	var decoded := _decode_texture(bytes, "", max_dimension)
	if not decoded.ok:
		return decoded
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
	_prune_cache()
	return decoded


func _decode_texture(bytes: PackedByteArray, content_type: String, max_dimension := 0) -> Dictionary:
	var image := decode_image(bytes, content_type)
	if image == null:
		return {"ok": false, "error": "ASSET_DECODE_FAILED"}
	if max_dimension > 0:
		var longest_side := maxi(image.get_width(), image.get_height())
		if longest_side > max_dimension:
			var scale := float(max_dimension) / float(longest_side)
			image.resize(
				maxi(1, roundi(image.get_width() * scale)),
				maxi(1, roundi(image.get_height() * scale)),
				Image.INTERPOLATE_LANCZOS
			)
	return {"ok": true, "texture": ImageTexture.create_from_image(image)}


func _max_dimension_for_variant(variant: String) -> int:
	match variant:
		"series":
			return SERIES_TEXTURE_MAX_DIMENSION
		"avatar":
			return AVATAR_TEXTURE_MAX_DIMENSION
		_:
			return 0


static func decode_image(bytes: PackedByteArray, content_type := "") -> Image:
	var image := Image.new()
	var error := ERR_INVALID_DATA
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4e and bytes[3] == 0x47:
		error = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 0xff and bytes[1] == 0xd8 and bytes[2] == 0xff:
		error = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		error = image.load_webp_from_buffer(bytes)
	elif content_type == "image/svg+xml":
		error = image.load_svg_from_buffer(bytes)
	return image if error == OK else null


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
		var cache_file := FileAccess.open(path, FileAccess.READ)
		if cache_file == null:
			continue
		var size := cache_file.get_length()
		cache_file.close()
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


static func _audit_asset_host(url: String) -> void:
	if not OS.is_debug_build():
		return
	var scheme_separator := url.find("://")
	if scheme_separator <= 0:
		return
	var host_end := url.length()
	for separator in ["/", "?", "#"]:
		var separator_index := url.find(separator, scheme_separator + 3)
		if separator_index >= 0:
			host_end = mini(host_end, separator_index)
	var host := url.left(host_end)
	if _audited_hosts.has(host):
		return
	_audited_hosts[host] = true
	print("[WechatDomainAudit] asset host: %s" % host)
