extends Control

const CATALOG := "res://config/content_catalog.json"
const INK := Color("#0b1b29")
const PAPER := Color("#ead9b5")
const GOLD := Color("#d5a64e")
const CINNABAR := Color("#a33b2b")
const JADE := Color("#516f62")
const DYNASTIES := ["汉", "唐", "宋", "元", "明", "清"]

@onready var cards: VBoxContainer = $Layout/Scroll/Cards


func _ready() -> void:
	$Layout/Header/Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
	$Layout/Header/Settings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings/settings.tscn"))
	_build_timeline()
	await _build_cards()


func _build_timeline() -> void:
	for dynasty in DYNASTIES:
		var seal := Label.new()
		seal.text = dynasty
		seal.custom_minimum_size = Vector2(48, 48)
		seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seal.add_theme_font_size_override("font_size", 21)
		seal.add_theme_color_override("font_color", PAPER)
		seal.add_theme_stylebox_override("normal", _round_box(Color(CINNABAR, 0.72), GOLD, 24, 2))
		$Layout/Timeline.add_child(seal)


func _build_cards() -> void:
	var remote := await ApiClient.get_catalog()
	if remote.ok:
		var remote_series: Array = remote.data.get("data", {}).get("series", [])
		if not remote_series.is_empty():
			await _build_remote_cards(remote_series)
			return
	var catalog := _read_json(CATALOG)
	if catalog.is_empty():
		return
	var series_id := str(catalog.get("default_series", ""))
	var levels: Array = []
	for raw_series in catalog.get("series", []):
		var series: Dictionary = raw_series
		if str(series.get("id", "")) == series_id:
			levels = series.get("levels", [])
			break
	var first_incomplete := levels.size()
	for i in levels.size():
		var entry: Dictionary = levels[i]
		if not ProgressStore.is_completed(str(entry.get("id", "")), int(entry.get("version", 1))):
			first_incomplete = i
			break
	for i in levels.size():
		await _add_level_card(i, levels[i], i > first_incomplete)


func _build_remote_cards(series_items: Array) -> void:
	var levels: Array = []
	for raw_series in series_items:
		var series: Dictionary = raw_series
		if bool(series.get("enabled", true)):
			levels.append_array(series.get("levels", []))
	var first_incomplete := levels.size()
	for i in levels.size():
		var entry: Dictionary = levels[i]
		if not ProgressStore.is_completed(str(entry.get("id", "")), int(entry.get("version", 1))):
			first_incomplete = i
			break
	for i in levels.size():
		var entry: Dictionary = levels[i]
		var result := await ApiClient.get_level(str(entry.get("id", "")))
		if result.ok:
			await _add_level_card(i, entry, i > first_incomplete, result.data.get("data", {}), true)


func _add_level_card(index: int, entry: Dictionary, locked: bool, remote_data := {}, remote := false) -> void:
	var data: Dictionary = remote_data if remote else _read_json(str(entry.get("path", "")))
	if data.is_empty():
		return
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 220)
	button.disabled = locked
	button.text = ""
	button.add_theme_stylebox_override("normal", _round_box(Color("#122b3a"), Color(GOLD, 0.55), 18, 2))
	button.add_theme_stylebox_override("hover", _round_box(Color("#183847"), GOLD, 18, 3))
	button.add_theme_stylebox_override("pressed", _round_box(Color("#0f2532"), CINNABAR, 18, 3))
	button.add_theme_stylebox_override("disabled", _round_box(Color("#101c24"), Color("#34434a"), 18, 1))
	button.pressed.connect(func():
		if remote:
			LevelLoader.select_remote_level(str(entry.get("id", "")))
		else:
			LevelLoader.select_level(str(entry.get("path", "")))
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")
	)
	cards.add_child(button)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(230, 190)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var image_asset: Dictionary = data.get("assets", {}).get("image", {})
	if remote:
		var texture_result := await AssetCache.new().load_texture(self, image_asset)
		if texture_result.ok:
			image.texture = texture_result.texture
	else:
		image.texture = load(str(image_asset.get("local_path", "")))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(image)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var number := Label.new()
	number.text = "第 %02d 关" % (index + 1)
	number.add_theme_color_override("font_color", Color(GOLD, 0.85))
	number.add_theme_font_size_override("font_size", 18)
	info.add_child(number)
	var title := Label.new()
	title.text = str(data.get("title", entry.get("id", "")))
	title.add_theme_color_override("font_color", PAPER if not locked else Color(PAPER, 0.38))
	title.add_theme_font_size_override("font_size", 28)
	info.add_child(title)
	var count: int = data.get("differences", []).size()
	var detail := Label.new()
	detail.text = "%d 个时代错误" % count
	detail.add_theme_color_override("font_color", Color("#aab8b5"))
	detail.add_theme_font_size_override("font_size", 18)
	info.add_child(detail)
	var seals := Label.new()
	var total := int(data.get("difficulty", {}).get("total", 1))
	seals.text = ("印 ".repeat(total)).strip_edges()
	seals.add_theme_color_override("font_color", CINNABAR if not locked else Color("#4d4d4d"))
	seals.add_theme_font_size_override("font_size", 18)
	info.add_child(seals)
	var state := Label.new()
	var completed := ProgressStore.is_completed(str(entry.get("id", "")), int(entry.get("version", 1)))
	state.text = "✓ 已完成" if completed else ("🔒 尚未解锁" if locked else "◆ 当前关卡")
	state.add_theme_color_override("font_color", JADE if completed else GOLD)
	state.add_theme_font_size_override("font_size", 18)
	info.add_child(state)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


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
