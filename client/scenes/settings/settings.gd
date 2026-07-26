extends Control

const CARD_FILL := Color("#102633")
const CARD_BORDER := Color("#294454")
const GOLD := Color("#d5a64e")

@onready var analytics_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Analytics
@onready var vibration_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/Vibration
@onready var large_markers_toggle: CheckButton = $SafeArea/Layout/Scroll/Sections/ExperienceCard/Rows/LargeMarkers
@onready var status_label: Label = $SafeArea/Layout/Scroll/Sections/Status
@onready var developer_account: VBoxContainer = $SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount


func _ready() -> void:
	_load_settings()
	_apply_style()
	analytics_toggle.toggled.connect(_analytics_toggled)
	vibration_toggle.toggled.connect(_vibration_toggled)
	large_markers_toggle.toggled.connect(_large_markers_toggled)
	$SafeArea/Layout/Header/Back.pressed.connect(_go_home)
	# 当前没有广告，先隐藏“移除广告”；后续接入广告平台时恢复按钮和购买回调。
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/Purchase.visible = false
	$SafeArea/Layout/Scroll/Sections/PrivacyCard/Rows/PrivacyPolicy.pressed.connect(_show_privacy)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Login.pressed.connect(_request_product_login)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/Actions/BindAccount.pressed.connect(_bind_account)
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/DeveloperAccount/Actions/LoginAccount.pressed.connect(_login_account)
	$SafeArea/Layout/Scroll/Sections/Logout.pressed.connect(_logout)
	developer_account.visible = OS.is_debug_build()
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Identity.text = "已登录账号"
	$SafeArea/Layout/Scroll/Sections/AccountCard/Content/Description.text = "关卡进度与游戏权益将跟随当前账号同步。"
	$SafeArea/Layout/Scroll/Sections/Version.text = "火眼金睛 · 版本 %s" % ProjectSettings.get_setting("application/config/version", "0.1.0")


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


func _analytics_toggled(enabled: bool) -> void:
	Preferences.set_value("privacy", "analytics", enabled)
	Analytics.set_enabled(enabled)


func _vibration_toggled(enabled: bool) -> void:
	Preferences.set_value("gameplay", "vibration", enabled)


func _large_markers_toggled(enabled: bool) -> void:
	Preferences.set_value("accessibility", "large_markers", enabled)


func _purchase() -> void:
	status_label.text = "正在验证购买…"
	var result := await Monetization.purchase_no_ads()
	status_label.text = "已移除广告" if result.ok else "暂时无法完成购买，请稍后再试"


func _show_privacy() -> void:
	status_label.text = "匿名分析可随时关闭；安装标识与访问令牌仅以不可逆摘要保存。"


func _request_product_login() -> void:
	status_label.text = "正式账号服务尚未配置。接入后将在这里完成登录与进度合并。"
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
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box
