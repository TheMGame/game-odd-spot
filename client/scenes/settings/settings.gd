extends Control

@onready var analytics_toggle: CheckButton = $Layout/Analytics
@onready var vibration_toggle: CheckButton = $Layout/Vibration
@onready var large_markers_toggle: CheckButton = $Layout/LargeMarkers
@onready var status_label: Label = $Layout/Status


func _ready() -> void:
	_load_settings()
	analytics_toggle.toggled.connect(_analytics_toggled)
	vibration_toggle.toggled.connect(_vibration_toggled)
	large_markers_toggle.toggled.connect(_large_markers_toggled)
	$Layout/Purchase.pressed.connect(_purchase)
	$Layout/BindAccount.pressed.connect(_bind_account)
	$Layout/LoginAccount.pressed.connect(_login_account)
	$Layout/Logout.pressed.connect(_logout)
	$Layout/Back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))


func _load_settings() -> void:
	analytics_toggle.button_pressed = Preferences.analytics_enabled
	vibration_toggle.button_pressed = Preferences.vibration_enabled
	large_markers_toggle.button_pressed = Preferences.large_markers
	Analytics.set_enabled(analytics_toggle.button_pressed)


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
	status_label.text = "去广告权益已生效" if result.ok else "购买验证失败（需要开发服务）"


func _logout() -> void:
	await ApiClient.logout()
	ProgressStore.clear_level("global_demo_001")
	get_tree().change_scene_to_file("res://scenes/bootstrap/bootstrap.tscn")


func _bind_account() -> void:
	var name := str($Layout/AccountName.text).strip_edges()
	if name.length() < 3:
		status_label.text = "测试账号至少 3 个字符"
		return
	var result := await ApiClient.bind_test_account(name)
	status_label.text = "账号已绑定，可在另一台设备恢复" if result.ok else "绑定失败：%s" % result.error


func _login_account() -> void:
	var name := str($Layout/AccountName.text).strip_edges()
	if name.length() < 3:
		status_label.text = "测试账号至少 3 个字符"
		return
	var result := await ApiClient.login_test_account(name)
	status_label.text = "账号恢复成功" if result.ok else "恢复失败：%s" % result.error
