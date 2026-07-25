extends Control

@onready var play_button: Button = $Layout/Actions/Play
@onready var sync_status: Label = $Layout/SyncStatus


func _ready() -> void:
	play_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn"))
	$Layout/TopBar/Settings.pressed.connect(_open_settings)
	$Layout/TopBar/Identity.pressed.connect(_open_settings)
	$Layout/Actions/Daily.pressed.connect(_open_daily)
	_apply_style()
	_refresh_identity()
	_refresh_sync()
	Analytics.track("home_impression")


func _refresh_sync() -> void:
	await SyncQueue.flush()
	var pending := SyncQueue.pending_count()
	sync_status.text = "进度已同步" if pending == 0 else "%d 条进度等待联网同步" % pending
	Analytics.flush()


func _apply_style() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = Color("#102837")
	card.border_color = Color("#b88a43")
	card.set_border_width_all(3)
	card.set_corner_radius_all(22)
	$Layout/Hero.add_theme_stylebox_override("panel", card)
	$Layout/TopBar/Identity.add_theme_stylebox_override("normal", _button_box(Color("#102431"), Color("#355061"), 18, 1))
	$Layout/TopBar/Identity.add_theme_stylebox_override("hover", _button_box(Color("#16303e"), Color("#d5a64e"), 18, 2))
	$Layout/Actions/Daily.add_theme_stylebox_override("normal", _button_box(Color("#17352f"), Color("#547766"), 22, 2))
	$Layout/Actions/Daily.add_theme_stylebox_override("hover", _button_box(Color("#20483f"), Color("#d5a64e"), 22, 2))


func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _refresh_identity() -> void:
	var short_id := SessionStore.user_id.right(6) if SessionStore.user_id.length() >= 6 else SessionStore.user_id
	$Layout/TopBar/Identity.text = "已登录  ·  %s" % short_id


func _open_daily() -> void:
	var result := await ApiClient.get_daily_challenge()
	Analytics.track("theme_click", {"source": "daily_challenge", "online": result.ok})
	get_tree().change_scene_to_file("res://scenes/level_select/level_select.tscn")


func _button_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	return box
