extends Control

const HOME_SCENE := preload("res://scenes/home/home.tscn")

const INK := Color("#0b1b29")
const PAPER := Color("#f3e8cf")
const GOLD := Color("#e6b95c")
const CINNABAR := Color("#c84e38")
const JADE := Color("#72a58f")

@onready var cards: VBoxContainer = $Layout/Scroll/Cards

var locked_overlay: ColorRect
var locked_card: PanelContainer


func _ready() -> void:
	_create_locked_dialog()
	$Layout/Header/Back.pressed.connect(func(): get_tree().change_scene_to_packed(HOME_SCENE))
	$Layout/Header/Settings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings/settings.tscn"))
	await _build_cards()
	Platform.optimize_touch_scroll($Layout/Scroll)


func _create_locked_dialog() -> void:
	locked_overlay = ColorRect.new()
	locked_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locked_overlay.color = Color(INK, 0.82)
	locked_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	locked_overlay.z_index = 100
	locked_overlay.visible = false
	add_child(locked_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locked_overlay.add_child(center)
	locked_card = PanelContainer.new()
	locked_card.custom_minimum_size = Vector2(720, 610)
	locked_card.add_theme_stylebox_override("panel", _round_box(Color("#f3e8cf"), GOLD, 24, 4))
	center.add_child(locked_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	locked_card.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "· 案件锁定 ·"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", CINNABAR)
	eyebrow.add_theme_font_size_override("font_size", 27)
	content.add_child(eyebrow)

	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(104, 104)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seal.add_theme_stylebox_override("panel", _round_box(Color("#8f352c"), GOLD, 52, 4))
	content.add_child(seal)
	var seal_text := Label.new()
	seal_text.text = "锁"
	seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_text.add_theme_color_override("font_color", PAPER)
	seal_text.add_theme_font_size_override("font_size", 40)
	seal.add_child(seal_text)

	var progress := Label.new()
	progress.text = "解锁条件"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_color_override("font_color", CINNABAR)
	progress.add_theme_font_size_override("font_size", 27)
	content.add_child(progress)
	var heading := Label.new()
	heading.text = "前一案件尚未完成"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_font_size_override("font_size", 40)
	content.add_child(heading)
	var message := Label.new()
	message.text = "完成上一案件后，本关将自动解锁。\n循序追查，真相就在下一程。"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color("#725c45"))
	message.add_theme_font_size_override("font_size", 27)
	message.add_theme_constant_override("line_spacing", 8)
	content.add_child(message)

	var close := Button.new()
	close.text = "继续探索"
	close.custom_minimum_size = Vector2(0, 82)
	close.add_theme_font_size_override("font_size", 30)
	close.add_theme_color_override("font_color", PAPER)
	close.add_theme_stylebox_override("normal", _round_box(Color("#ad3f30"), GOLD, 10, 2))
	close.add_theme_stylebox_override("hover", _round_box(Color("#c4513f"), Color("#f0cf82"), 10, 3))
	close.add_theme_stylebox_override("pressed", _round_box(Color("#8f3028"), GOLD, 10, 2))
	close.pressed.connect(_hide_locked_dialog)
	content.add_child(close)


func _build_cards() -> void:
	var remote := await CatalogRepository.get_catalog()
	if not remote.ok:
		var error := str(remote.get("error", "CATALOG_LOAD_FAILED"))
		push_error("Catalog request failed: %s" % error)
		_show_catalog_message("关卡加载失败：%s" % error)
		return
	var response_data: Dictionary = remote.data.get("data", {})
	var remote_series := _array_or_empty(response_data.get("series"))
	if not remote_series.is_empty():
		await _build_remote_cards(remote_series)
		return
	_show_catalog_message("该系列暂无已发布关卡")


func _show_catalog_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_font_size_override("font_size", 25)
	cards.add_child(label)


func _build_remote_cards(series_items: Array) -> void:
	var levels: Array = []
	var is_daily_task := false
	for raw_series in series_items:
		var series: Dictionary = raw_series
		var is_selected := LevelLoader.selected_series_id.is_empty() or str(series.get("id", "")) == LevelLoader.selected_series_id
		if bool(series.get("enabled", true)) and is_selected:
			is_daily_task = str(series.get("id", "")) == "daily_task"
			if levels.is_empty():
				_apply_series_header(series)
			levels.append_array(_array_or_empty(series.get("levels")))
	var first_unfinished := levels.size()
	for i in levels.size():
		var entry: Dictionary = levels[i]
		if not _is_completed(entry):
			first_unfinished = i
			break
	for i in levels.size():
		var entry: Dictionary = levels[i]
		var completed := _is_completed(entry)
		var locked := false if is_daily_task else (not completed and i > first_unfinished)
		_add_level_card(i, entry, locked)


func _apply_series_header(series: Dictionary) -> void:
	$Layout/Header/Titles/Title.text = str(series.get("title", series.get("display_name", series.get("id", "系列关卡"))))
	var description := str(series.get("description", series.get("period", "")))
	$Layout/Header/Titles/Subtitle.text = description
	$Layout/Header/Titles/Subtitle.visible = not description.is_empty()


func _add_level_card(index: int, entry: Dictionary, locked: bool) -> void:
	var data: Dictionary = {
		"title": entry.get("title", entry.get("id", "")),
	}
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size = Vector2(0, 250)
	button.text = ""
	button.add_theme_stylebox_override("normal", _round_box(Color("#183039") if locked else Color("#173a46"), Color("#52666b") if locked else Color(GOLD, 0.72), 18, 2))
	button.add_theme_stylebox_override("hover", _round_box(Color("#203941") if locked else Color("#22505d"), Color("#6d8084") if locked else GOLD, 18, 3))
	button.add_theme_stylebox_override("pressed", _round_box(Color("#12323d"), CINNABAR, 18, 3))
	button.add_theme_stylebox_override("disabled", _round_box(Color("#183039"), Color("#52666b"), 18, 1))
	button.pressed.connect(func():
		if locked:
			_show_locked_dialog()
			return
		LevelLoader.select_remote_level(str(entry.get("id", "")))
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")
	)
	cards.add_child(button)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(250, 218)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_load_preview(image, str(entry.get("thumbnail_url", "")), str(entry.get("image_url", "")))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var number := Label.new()
	number.text = "第 %02d 关" % (index + 1)
	number.add_theme_color_override("font_color", Color(GOLD, 0.85))
	number.add_theme_font_size_override("font_size", 26)
	info.add_child(number)
	var title := Label.new()
	title.text = str(data.get("title", entry.get("id", "")))
	title.add_theme_color_override("font_color", PAPER if not locked else Color(PAPER, 0.38))
	title.add_theme_font_size_override("font_size", 36)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	var count := int(entry.get("difference_count", 0))
	var detail := Label.new()
	detail.text = "%d 个找茬目标" % count
	detail.add_theme_color_override("font_color", Color("#b8c9c5"))
	detail.add_theme_font_size_override("font_size", 26)
	info.add_child(detail)
	var seals := Label.new()
	var total := int(entry.get("difficulty", 1))
	seals.text = "难度 %s" % "◆".repeat(clampi(total, 1, 5))
	seals.add_theme_color_override("font_color", CINNABAR if not locked else Color("#4d4d4d"))
	seals.add_theme_font_size_override("font_size", 26)
	info.add_child(seals)
	var state := Label.new()
	var completed := _is_completed(entry)
	state.text = "已完成" if completed else ("尚未解锁" if locked else "当前关卡")
	state.add_theme_color_override("font_color", JADE if completed else GOLD)
	state.add_theme_font_size_override("font_size", 26)
	info.add_child(state)


func _show_locked_dialog() -> void:
	locked_overlay.visible = true
	locked_overlay.modulate.a = 0.0
	locked_card.scale = Vector2(0.82, 0.82)
	await get_tree().process_frame
	locked_card.pivot_offset = locked_card.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(locked_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(locked_card, "scale", Vector2.ONE, 0.32)


func _hide_locked_dialog() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(locked_overlay, "modulate:a", 0.0, 0.14)
	tween.tween_property(locked_card, "scale", Vector2(0.92, 0.92), 0.14)
	await tween.finished
	locked_overlay.visible = false


func _is_completed(entry: Dictionary) -> bool:
	return bool(entry.get("completed", false)) or ProgressStore.is_completed(
		str(entry.get("id", "")),
		int(entry.get("version", 1))
	)


func _load_preview(target: TextureRect, thumbnail_url: String, image_url: String) -> void:
	# Show the small asset as soon as possible, then replace it in-place when the
	# full image finishes downloading. Each card runs independently.
	if not thumbnail_url.is_empty():
		var thumbnail := await AssetCache.new().load_texture_url(self, thumbnail_url, "level_thumbnail")
		if is_instance_valid(target) and thumbnail.ok:
			target.texture = thumbnail.texture
	if image_url.is_empty() or image_url == thumbnail_url or not is_instance_valid(target):
		return
	var full_image := await AssetCache.new().load_texture_url(self, image_url, "level_preview_full")
	if is_instance_valid(target) and full_image.ok:
		target.texture = full_image.texture


func _round_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _array_or_empty(value: Variant) -> Array:
	return value if value is Array else []
