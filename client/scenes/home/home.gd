extends Control

const GOLD := Color("#d5a64e")
const PAPER := Color("#ead9b5")
const MUTED := Color("#aab8b5")

@onready var cards: VBoxContainer = $Layout/SeriesScroll/Cards
@onready var sync_status: Label = $Layout/Footer/SyncStatus

var series_items: Array = []
var series_images: Dictionary = {}
var series_image_quality: Dictionary = {}


func _ready() -> void:
	$Layout/TopBar/Settings.pressed.connect(_open_settings)
	$Layout/TopBar/Identity.pressed.connect(_open_settings)
	$Layout/Footer/Daily.pressed.connect(_open_daily)
	_apply_style()
	await ApiClient.refresh_user_profile()
	await _refresh_series()
	await _refresh_identity()
	_refresh_sync()
	Analytics.track("home_impression")


func _refresh_series() -> void:
	series_items.clear()
	var remote := await ApiClient.get_catalog()
	if not remote.ok:
		var error := str(remote.get("error", "CATALOG_LOAD_FAILED"))
		push_error("Catalog request failed: %s" % error)
		_show_catalog_message("系列加载失败：%s" % error)
		return
	var response_data: Dictionary = remote.data.get("data", {})
	for raw_series in _array_or_empty(response_data.get("series")):
		var series: Dictionary = raw_series
		if bool(series.get("enabled", true)):
			series_items.append(series)
	if series_items.is_empty():
		_show_catalog_message("暂无已发布的游戏系列")
		return
	for series in series_items:
		_add_series_card(series)


func _show_catalog_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 22)
	cards.add_child(label)


func _add_series_card(series: Dictionary) -> void:
	var series_id := str(series.get("id", ""))
	var levels := _array_or_empty(series.get("levels"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 430)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _card_box())
	cards.add_child(panel)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 0)
	panel.add_child(content)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(0, 300)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	content.add_child(image)
	series_images[series_id] = image
	series_image_quality[series_id] = 0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	content.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var title := Label.new()
	title.text = str(series.get("title", series.get("display_name", series_id)))
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 25)
	info.add_child(title)

	var description := str(series.get("description", series.get("period", "")))
	var details := Label.new()
	details.text = "%d 个关卡%s" % [levels.size(), (" · " + description) if not description.is_empty() else ""]
	details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_theme_color_override("font_color", MUTED)
	details.add_theme_font_size_override("font_size", 17)
	info.add_child(details)

	var enter := Button.new()
	enter.custom_minimum_size = Vector2(116, 72)
	enter.text = "进入"
	enter.add_theme_font_size_override("font_size", 20)
	enter.add_theme_stylebox_override("normal", _button_box(Color("#17352f"), Color("#547766"), 18, 2))
	enter.add_theme_stylebox_override("hover", _button_box(Color("#20483f"), GOLD, 18, 2))
	enter.pressed.connect(func(): _open_series(series_id))
	row.add_child(enter)

	if not levels.is_empty():
		var first_level: Dictionary = levels[0]
		var thumbnail_url := str(first_level.get("thumbnail_url", ""))
		if not thumbnail_url.is_empty():
			_load_series_thumbnail(thumbnail_url, series_id)
		var level_id := str(first_level.get("id", ""))
		if not level_id.is_empty():
			_load_series_full_image(level_id, series_id)
	elif not str(series.get("cover_url", "")).is_empty():
		_load_series_thumbnail(str(series.get("cover_url", "")), series_id)
	Analytics.track("series_impression", {"series_id": series_id})


func _open_series(series_id: String) -> void:
	LevelLoader.select_series(series_id)
	get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn")


func _load_series_thumbnail(url: String, series_id: String) -> void:
	var texture := await _download_texture(url)
	if texture != null and series_images.has(series_id) and int(series_image_quality.get(series_id, 0)) == 0:
		(series_images[series_id] as TextureRect).texture = texture


func _load_series_full_image(level_id: String, series_id: String) -> void:
	var result := await ApiClient.get_level(level_id)
	if not result.ok or not series_images.has(series_id):
		return
	var image_asset: Dictionary = result.data.get("data", {}).get("assets", {}).get("image", {})
	var texture_result := await AssetCache.new().load_texture(self, image_asset)
	if texture_result.ok and series_images.has(series_id):
		series_image_quality[series_id] = 1
		(series_images[series_id] as TextureRect).texture = texture_result.texture


func _download_texture(url: String) -> Texture2D:
	var request := HTTPRequest.new()
	request.accept_gzip = not OS.has_feature("web")
	request.timeout = 8.0
	add_child(request)
	if request.request(url) != OK:
		request.queue_free()
		return null
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300:
		return null
	var bytes: PackedByteArray = response[3]
	var image := AssetCache.decode_image(bytes)
	return ImageTexture.create_from_image(image) if image != null else null


func _refresh_sync() -> void:
	await SyncQueue.flush()
	var pending := SyncQueue.pending_count()
	sync_status.text = "进度已同步" if pending == 0 else "%d 条进度等待联网同步" % pending
	Analytics.flush()


func _apply_style() -> void:
	$Layout/TopBar/Identity.add_theme_stylebox_override("normal", _button_box(Color("#102431"), Color("#355061"), 18, 1))
	$Layout/TopBar/Identity.add_theme_stylebox_override("hover", _button_box(Color("#16303e"), GOLD, 18, 2))
	$Layout/Footer/Daily.add_theme_stylebox_override("normal", _button_box(Color("#17352f"), Color("#547766"), 18, 2))
	$Layout/Footer/Daily.add_theme_stylebox_override("hover", _button_box(Color("#20483f"), GOLD, 18, 2))


func _card_box() -> StyleBoxFlat:
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#102837")
	card.border_color = Color("#b88a43")
	card.set_border_width_all(3)
	card.set_corner_radius_all(22)
	return card


func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _refresh_identity() -> void:
	var short_id := SessionStore.user_id.right(6) if SessionStore.user_id.length() >= 6 else SessionStore.user_id
	$Layout/TopBar/Identity.text = SessionStore.username if not SessionStore.username.is_empty() else "玩家 · %s" % short_id
	if not SessionStore.avatar_url.is_empty():
		var avatar := await _download_texture(SessionStore.avatar_url)
		if avatar != null:
			$Layout/TopBar/Identity.icon = avatar


func _open_daily() -> void:
	LevelLoader.select_series("daily_task")
	var remote := await ApiClient.get_catalog()
	if remote.ok:
		var response_data: Dictionary = remote.data.get("data", {})
		for raw_series in _array_or_empty(response_data.get("series")):
			var series: Dictionary = raw_series
			if str(series.get("id", "")) != "daily_task":
				continue
			var levels := _array_or_empty(series.get("levels"))
			if not levels.is_empty():
				var latest: Dictionary = levels[0]
				var level_id := str(latest.get("id", ""))
				if not level_id.is_empty():
					LevelLoader.select_remote_level(level_id)
					Analytics.track("theme_click", {"source": "daily_challenge", "level_id": level_id, "fallback": false})
					get_tree().change_scene_to_file("res://scenes/game/game.tscn")
					return
			break
	Analytics.track("theme_click", {"source": "daily_challenge", "available": false})
	_show_daily_unavailable()


func _show_daily_unavailable() -> void:
	$Layout/Footer/Daily.text = "暂无每日挑战"
	$Layout/Footer/Daily.disabled = true
	sync_status.text = "每日挑战系列中还没有已发布关卡"


func _button_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	return box


func _array_or_empty(value: Variant) -> Array:
	return value if value is Array else []
