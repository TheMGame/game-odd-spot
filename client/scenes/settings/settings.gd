extends Control

const CARD_FILL := Color("#102633")
const CARD_BORDER := Color("#294454")
const GOLD := Color("#d5a64e")

@onready var analytics_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Analytics
@onready var vibration_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Vibration
@onready var large_markers_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/LargeMarkers
@onready var status_label: Label = $SafeArea/Layout/Scroll/Sections/Status
@onready var developer_account: VBoxContainer = $SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount
@onready var language_selector: OptionButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Language/Selector

var _locale_ids: Array[String] = []
var _changing_locale := false


func _ready() -> void:
	_load_settings()
	_apply_style()
	analytics_toggle.toggled.connect(_analytics_toggled)
	vibration_toggle.toggled.connect(_vibration_toggled)
	large_markers_toggle.toggled.connect(_large_markers_toggled)
	language_selector.item_selected.connect(_language_selected)
	$SafeArea/Layout/Header/Back.pressed.connect(_go_home)
	# 当前没有广告，先隐藏“移除广告”；后续接入广告平台时恢复按钮和购买回调。
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Purchase.visible = false
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy.pressed.connect(_show_privacy)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Login.pressed.connect(_request_product_login)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/Actions/BindAccount.pressed.connect(_bind_account)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/Actions/LoginAccount.pressed.connect(_login_account)
	$SafeArea/Layout/Scroll/Sections/Logout.pressed.connect(_logout)
	developer_account.visible = OS.is_debug_build()
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Identity.text = tr("已登录账号")
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Description.text = tr("关卡进度与游戏权益将跟随当前账号同步。")
	$SafeArea/Layout/Scroll/Sections/Version.text = tr("火眼金睛 · 版本 %s") % ProjectSettings.get_setting("application/config/version", "0.1.0")
	await _load_languages()


func _load_settings() -> void:
	analytics_toggle.button_pressed = Preferences.analytics_enabled
	vibration_toggle.button_pressed = Preferences.vibration_enabled
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
	login.add_theme_stylebox_override("normal", _round_box(Color("#a33b2b"), Color("#d8ae62"), 16, 2))
	login.add_theme_stylebox_override("hover", _round_box(Color("#bd4834"), GOLD, 16, 3))
	login.add_theme_stylebox_override("pressed", _round_box(Color("#862f24"), GOLD, 16, 2))
	for row in [
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Vibration,
		$SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/LargeMarkers,
		$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Analytics,
	]:
		row.add_theme_color_override("font_color", Color("#eee0c3"))
		row.add_theme_color_override("font_hover_color", Color("#f5d99b"))
	for secondary in [
		$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy,
		$SafeArea/Layout/Scroll/Sections/Logout,
	]:
		secondary.add_theme_stylebox_override("normal", _round_box(Color("#0c202c"), Color("#294454"), 14, 1))
		secondary.add_theme_stylebox_override("hover", _round_box(Color("#132f3d"), GOLD, 14, 2))


func _analytics_toggled(enabled: bool) -> void:
	Preferences.set_value("privacy", "analytics", enabled)
	Analytics.set_enabled(enabled)


func _vibration_toggled(enabled: bool) -> void:
	Preferences.set_value("gameplay", "vibration", enabled)


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
	status_label.text = tr("匿名分析可随时关闭；安装标识与访问令牌仅以不可逆摘要保存。")


func _request_product_login() -> void:
	status_label.text = tr("正式账号服务尚未配置。接入后将在这里完成登录与进度合并。")
	if OS.is_debug_build():
		developer_account.visible = true


func _logout() -> void:
	await ApiClient.logout()
	get_tree().change_scene_to_file("res://scenes/bootstrap/bootstrap.tscn")


func _bind_account() -> void:
	var name := str($SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/AccountName.text).strip_edges()
	if name.length() < 3:
		status_label.text = "Debug 测试账号至少需要 3 个字符"
		return
	var result := await ApiClient.bind_test_account(name)
	status_label.text = "测试账号已绑定" if result.ok else "绑定失败：%s" % result.error


func _login_account() -> void:
	var name := str($SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/AccountName.text).strip_edges()
	if name.length() < 3:
		status_label.text = "Debug 测试账号至少需要 3 个字符"
		return
	var result := await ApiClient.login_test_account(name)
	status_label.text = "测试账号恢复成功" if result.ok else "恢复失败：%s" % result.error


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


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
