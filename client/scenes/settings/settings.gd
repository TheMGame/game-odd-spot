extends Control

const HOME_SCENE := preload("res://scenes/home/home.tscn")

const CARD_FILL := Color("#173a46")
const CARD_BORDER := Color("#5b7d87")
const GOLD := Color("#e6b95c")

@onready var analytics_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Analytics
@onready var vibration_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Vibration
@onready var music_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Music
@onready var effects_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Effects
@onready var large_markers_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/LargeMarkers
@onready var status_label: Label = $SafeArea/Layout/Scroll/Sections/Status
@onready var language_selector: OptionButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Language/Selector
@onready var privacy_dialog: Control = $PrivacyDialog
@onready var privacy_content: RichTextLabel = $PrivacyDialog/DialogMargin/Card/Content/PolicyContent
@onready var privacy_close: Button = $PrivacyDialog/DialogMargin/Card/Content/Close

var _locale_ids: Array[String] = []
var _changing_locale := false


func _ready() -> void:
	Platform.optimize_touch_scroll($SafeArea/Layout/Scroll)
	_load_settings()
	_apply_style()
	analytics_toggle.toggled.connect(_analytics_toggled)
	vibration_toggle.toggled.connect(_vibration_toggled)
	music_toggle.toggled.connect(_music_toggled)
	effects_toggle.toggled.connect(_effects_toggled)
	large_markers_toggle.toggled.connect(_large_markers_toggled)
	language_selector.item_selected.connect(_language_selected)
	$SafeArea/Layout/Header/Back.pressed.connect(_go_home)
	# 当前没有正式广告供应商；微信环境还必须阻断 Mock 购买能力。
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Purchase.visible = false
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy.pressed.connect(_show_privacy)
	privacy_close.pressed.connect(_hide_privacy)
	$PrivacyDialog/Backdrop.gui_input.connect(_privacy_backdrop_input)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Login.pressed.connect(_request_product_login)
	$SafeArea/Layout/Scroll/Sections/Logout.pressed.connect(_logout)
	var has_account := SessionStore.has_access_token()
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Login.visible = not has_account
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Identity.text = (
		SessionStore.username if has_account and not SessionStore.username.is_empty()
		else tr("已登录账号") if has_account
		else tr("尚未登录")
	)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Description.text = (
		tr("关卡进度与游戏权益正在通过正式账号服务同步。") if has_account
		else tr("登录正式账号后，可同步关卡进度与游戏权益。")
	)
	$SafeArea/Layout/Scroll/Sections/Version.text = tr("错位大侦探 · 版本 %s") % ProjectSettings.get_setting("application/config/version", "0.1.0")
	await _load_languages()


func _load_settings() -> void:
	analytics_toggle.button_pressed = Preferences.analytics_enabled
	vibration_toggle.button_pressed = Preferences.vibration_enabled
	music_toggle.button_pressed = Preferences.music_enabled
	effects_toggle.button_pressed = Preferences.effects_enabled
	large_markers_toggle.button_pressed = Preferences.large_markers
	Analytics.set_enabled(analytics_toggle.button_pressed)


func _apply_style() -> void:
	for card in [
		$SafeArea/Layout/Scroll/Sections/AccountCard,
		$SafeArea/Layout/Scroll/Sections/ExperienceCard,
		$SafeArea/Layout/Scroll/Sections/PrivacyCard,
	]:
		card.add_theme_stylebox_override("panel", _round_box(CARD_FILL, CARD_BORDER, 20, 1))
	var login: Button = $SafeArea/Layout/Scroll/Sections/AccountCard/Content/Login
	login.add_theme_stylebox_override("normal", _round_box(Color("#c84e38"), Color("#e6b95c"), 16, 2))
	login.add_theme_stylebox_override("hover", _round_box(Color("#dc624b"), GOLD, 16, 3))
	login.add_theme_stylebox_override("pressed", _round_box(Color("#862f24"), GOLD, 16, 2))
	for row in [
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Vibration,
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Music,
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Effects,
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/LargeMarkers,
		$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Analytics,
	]:
		row.add_theme_color_override("font_color", Color("#eee0c3"))
		row.add_theme_color_override("font_hover_color", Color("#f5d99b"))
	for secondary in [
		$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy,
		$SafeArea/Layout/Scroll/Sections/Logout,
	]:
		secondary.add_theme_stylebox_override("normal", _round_box(Color("#1b4350"), Color("#5b7d87"), 14, 1))
		secondary.add_theme_stylebox_override("hover", _round_box(Color("#255462"), GOLD, 14, 2))
	language_selector.add_theme_stylebox_override("normal", _selector_box(Color("#255462"), Color("#81a59f"), 1))
	language_selector.add_theme_stylebox_override("hover", _selector_box(Color("#306675"), GOLD, 2))
	language_selector.add_theme_stylebox_override("pressed", _selector_box(Color("#1b4350"), GOLD, 2))
	language_selector.add_theme_stylebox_override("focus", _selector_box(Color(0, 0, 0, 0), GOLD, 2))
	language_selector.add_theme_color_override("font_color", Color("#f3e8cf"))
	language_selector.add_theme_color_override("font_hover_color", Color("#fff3d6"))
	language_selector.add_theme_color_override("font_pressed_color", Color("#fff3d6"))
	language_selector.add_theme_color_override("font_focus_color", Color("#fff3d6"))
	language_selector.add_theme_color_override("icon_normal_color", GOLD)
	language_selector.add_theme_color_override("icon_hover_color", Color("#fff3d6"))
	var language_popup := language_selector.get_popup()
	language_popup.add_theme_font_size_override("font_size", 24)
	language_popup.add_theme_color_override("font_color", Color("#f3e8cf"))
	language_popup.add_theme_color_override("font_hover_color", Color("#102a35"))
	language_popup.add_theme_stylebox_override("panel", _selector_box(Color("#214b58"), Color("#81a59f"), 1))
	language_popup.add_theme_stylebox_override("hover", _selector_box(GOLD, Color("#f3e8cf"), 1))
	language_popup.add_theme_constant_override("item_start_padding", 18)
	language_popup.add_theme_constant_override("item_end_padding", 18)
	language_popup.add_theme_constant_override("v_separation", 10)
	$PrivacyDialog/DialogMargin/Card.add_theme_stylebox_override(
		"panel", _round_box(Color("#173a46"), GOLD, 24, 2)
	)
	privacy_close.add_theme_stylebox_override("normal", _round_box(Color("#c84e38"), GOLD, 14, 2))
	privacy_close.add_theme_stylebox_override("hover", _round_box(Color("#dc624b"), Color("#fff3d6"), 14, 2))
	privacy_close.add_theme_stylebox_override("pressed", _round_box(Color("#862f24"), GOLD, 14, 2))


func _analytics_toggled(enabled: bool) -> void:
	Preferences.set_value("privacy", "analytics", enabled)
	Analytics.set_enabled(enabled)


func _vibration_toggled(enabled: bool) -> void:
	Preferences.set_value("gameplay", "vibration", enabled)


func _music_toggled(enabled: bool) -> void:
	AudioManager.set_music_enabled(enabled)


func _effects_toggled(enabled: bool) -> void:
	AudioManager.set_effects_enabled(enabled)


func _large_markers_toggled(enabled: bool) -> void:
	Preferences.set_value("accessibility", "large_markers", enabled)


func _load_languages() -> void:
	language_selector.clear()
	_locale_ids.clear()
	var items: Array = await LanguagePackManager.available_locales()
	if items.is_empty():
		items = [
			{"locale": "zh-CN", "native_name": "简体中文"},
			{"locale": "en-US", "native_name": "English"},
		]
	for item in items:
		if not item is Dictionary:
			continue
		var locale := str(item.get("locale", ""))
		_locale_ids.append(locale)
		language_selector.add_item(str(item.get("native_name", locale)))
		if locale == LocaleManager.current_locale():
			language_selector.select(_locale_ids.size() - 1)


func _language_selected(index: int) -> void:
	if _changing_locale or index < 0 or index >= _locale_ids.size():
		return
	var previous := LocaleManager.current_locale()
	_changing_locale = true
	language_selector.disabled = true
	status_label.text = tr("SETTINGS_LANGUAGE_LOADING")
	var result := await LocaleManager.select_locale(_locale_ids[index])
	if result.ok:
		status_label.text = tr("SETTINGS_LANGUAGE_CHANGED")
		get_tree().reload_current_scene()
	else:
		status_label.text = tr("SETTINGS_LANGUAGE_FAILED")
		for item_index in _locale_ids.size():
			if _locale_ids[item_index] == previous:
				language_selector.select(item_index)
				break
	language_selector.disabled = false
	_changing_locale = false


func _purchase() -> void:
	status_label.text = tr("正在验证购买…")
	var result := await Monetization.purchase_no_ads()
	status_label.text = tr("已移除广告") if result.ok else tr("暂时无法完成购买，请稍后再试")


func _show_privacy() -> void:
	privacy_content.text = tr("PRIVACY_POLICY_CONTENT")
	privacy_content.scroll_to_line(0)
	privacy_dialog.visible = true
	privacy_close.grab_focus()


func _hide_privacy() -> void:
	privacy_dialog.visible = false
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy.grab_focus()


func _privacy_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_privacy()


func _unhandled_input(event: InputEvent) -> void:
	if privacy_dialog.visible and event.is_action_pressed("ui_cancel"):
		_hide_privacy()
		get_viewport().set_input_as_handled()


func _request_product_login() -> void:
	get_tree().change_scene_to_file("res://scenes/login/login.tscn")


func _logout() -> void:
	await ApiClient.logout()
	get_tree().change_scene_to_file("res://scenes/bootstrap/bootstrap.tscn")


func _go_home() -> void:
	get_tree().change_scene_to_packed(HOME_SCENE)


func _round_box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	return box


func _selector_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(14)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
