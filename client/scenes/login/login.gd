extends Control

const CARD_FILL := Color("#102633")
const CARD_BORDER := Color("#365060")
const GOLD := Color("#d5a64e")

@onready var account_input: LineEdit = $SafeArea/Layout/Card/Content/AccountName
@onready var password_input: LineEdit = $SafeArea/Layout/Card/Content/Password
@onready var login_button: Button = $SafeArea/Layout/Card/Content/LoginButton
@onready var create_button: Button = $SafeArea/Layout/Card/Content/CreateButton
@onready var status_label: Label = $SafeArea/Layout/Card/Content/Status


func _ready() -> void:
	login_button.pressed.connect(_login)
	create_button.pressed.connect(_create_account)
	account_input.text_submitted.connect(func(_value: String): _login())
	_apply_style()
	account_input.grab_focus()
	_restore_session()


func _restore_session() -> void:
	if SessionStore.access_token.is_empty() and SessionStore.refresh_token.is_empty():
		return
	login_button.disabled = true
	create_button.disabled = true
	status_label.text = "正在恢复登录状态…"
	var result: Dictionary
	if not SessionStore.has_valid_access_token():
		result = await ApiClient.refresh_session()
	else:
		result = await ApiClient.get_bootstrap()
	if result.ok:
		get_tree().change_scene_to_file("res://scenes/home/home.tscn")
		return
	login_button.disabled = false
	create_button.disabled = false
	status_label.text = "登录已过期，请重新登录"


func _login() -> void:
	if login_button.disabled:
		return
	var account_name := account_input.text.strip_edges()
	if account_name.length() < 3:
		status_label.text = "请输入至少 3 个字符的账号"
		account_input.grab_focus()
		return
	var password := password_input.text
	if password.length() < 10:
		status_label.text = "密码至少需要 10 个字符"
		password_input.grab_focus()
		return

	login_button.disabled = true
	login_button.text = "正在登录…"
	status_label.text = ""
	var result := await ApiClient.login_user(account_name, password)
	if result.ok:
		get_tree().change_scene_to_file("res://scenes/home/home.tscn")
		return
	login_button.disabled = false
	login_button.text = "登录"
	status_label.text = _login_error_message(str(result.get("error", "LOGIN_FAILED")))


func _create_account() -> void:
	if login_button.disabled:
		return
	var account_name := account_input.text.strip_edges()
	if account_name.length() < 3:
		status_label.text = "请输入至少 3 个字符的账号"
		account_input.grab_focus()
		return
	var password := password_input.text
	if password.length() < 10:
		status_label.text = "密码至少需要 10 个字符"
		password_input.grab_focus()
		return

	login_button.disabled = true
	create_button.disabled = true
	create_button.text = "正在创建…"
	status_label.text = ""
	var result := await ApiClient.register_user(account_name, password)
	if result.ok:
		get_tree().change_scene_to_file("res://scenes/home/home.tscn")
		return
	login_button.disabled = false
	create_button.disabled = false
	create_button.text = "创建账号并开始"
	status_label.text = "账号已存在，请直接登录"


func _login_error_message(error: String) -> String:
	match error:
		"HTTP_404":
			return "游戏登录服务尚未更新，请联系管理员"
		"USER_LOGIN_INVALID":
			return "用户凭证验证失败"
		"IDENTITY_UNAVAILABLE", "USER_SERVER_UNAVAILABLE":
			return "用户服务暂时不可用"
		"USER_TOKEN_MISSING":
			return "用户服务返回的登录凭证不完整"
		_:
			return error if not error.is_empty() else "登录失败，请稍后再试"


func _apply_style() -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = CARD_FILL
	card.border_color = CARD_BORDER
	card.set_border_width_all(1)
	card.set_corner_radius_all(24)
	card.content_margin_left = 30
	card.content_margin_right = 30
	card.content_margin_top = 32
	card.content_margin_bottom = 30
	$SafeArea/Layout/Card.add_theme_stylebox_override("panel", card)

	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#a33b2b")
	primary.border_color = GOLD
	primary.set_border_width_all(2)
	primary.set_corner_radius_all(16)
	login_button.add_theme_stylebox_override("normal", primary)

	var hover := primary.duplicate()
	hover.bg_color = Color("#bd4834")
	hover.set_border_width_all(3)
	login_button.add_theme_stylebox_override("hover", hover)
