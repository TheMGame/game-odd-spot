extends Control

const CARD_FILL := Color("#173a46")
const CARD_BORDER := Color("#5b7d87")
const GOLD := Color("#e6b95c")

@onready var account_input: LineEdit = $SafeArea/Layout/Card/Content/AccountName
@onready var password_input: LineEdit = $SafeArea/Layout/Card/Content/Password
@onready var login_button: Button = $SafeArea/Layout/Card/Content/LoginButton
@onready var create_button: Button = $SafeArea/Layout/Card/Content/CreateButton
@onready var status_label: Label = $SafeArea/Layout/Card/Content/Status
@onready var code_input: LineEdit = $SafeArea/Layout/Card/Content/EmailCode
@onready var username_input: LineEdit = $SafeArea/Layout/Card/Content/Username
@onready var nickname_input: LineEdit = $SafeArea/Layout/Card/Content/Nickname
@onready var avatar_input: LineEdit = $SafeArea/Layout/Card/Content/Avatar
@onready var send_code_button: Button = $SafeArea/Layout/Card/Content/SendCodeButton
@onready var verify_code_button: Button = $SafeArea/Layout/Card/Content/VerifyCodeButton
@onready var complete_registration_button: Button = $SafeArea/Layout/Card/Content/CompleteRegistrationButton

var registration_ticket := ""


func _ready() -> void:
	login_button.pressed.connect(_login)
	create_button.pressed.connect(_create_account)
	send_code_button.pressed.connect(_send_email_code)
	verify_code_button.pressed.connect(_verify_email_code)
	complete_registration_button.pressed.connect(_complete_email_registration)
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
		await ApiClient.refresh_user_profile()
		get_tree().change_scene_to_file("res://scenes/home/home.tscn")
		return
	login_button.disabled = false
	create_button.disabled = false
	status_label.text = "登录已过期，请重新登录"


func _login() -> void:
	if login_button.disabled:
		return
	var account_name := account_input.text.strip_edges()
	if not account_name.contains("@"):
		status_label.text = "请输入有效邮箱"
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
	if send_code_button.visible:
		_show_login()
	else:
		_show_email_registration()


func _show_email_registration() -> void:
	$SafeArea/Layout/Card/Content/Title.text = "邮箱注册"
	$SafeArea/Layout/Card/Content/Description.text = "验证邮箱后设置用户名、昵称与头像。"
	account_input.placeholder_text = "邮箱"
	login_button.visible = false
	password_input.visible = false
	code_input.visible = true
	send_code_button.visible = true
	verify_code_button.visible = true
	create_button.text = "返回账号登录"
	status_label.text = ""
	account_input.grab_focus()


func _show_login() -> void:
	registration_ticket = ""
	$SafeArea/Layout/Card/Content/Title.text = "欢迎回来"
	$SafeArea/Layout/Card/Content/Description.text = "使用邮箱和密码登录，同步关卡进度与游戏权益。"
	login_button.visible = true
	password_input.visible = true
	code_input.visible = false
	username_input.visible = false
	nickname_input.visible = false
	avatar_input.visible = false
	send_code_button.visible = false
	verify_code_button.visible = false
	complete_registration_button.visible = false
	create_button.text = "使用邮箱创建账号"
	status_label.text = ""


func _send_email_code() -> void:
	var email := account_input.text.strip_edges().to_lower()
	if not email.contains("@"):
		status_label.text = "请输入有效邮箱"
		return
	send_code_button.disabled = true
	send_code_button.text = "正在发送…"
	var result := await ApiClient.send_email_code(email)
	send_code_button.disabled = false
	send_code_button.text = "重新发送验证码"
	status_label.text = "验证码已发送，请在 5 分钟内填写" if result.ok else "发送失败：%s" % result.error
	if result.ok:
		code_input.grab_focus()


func _verify_email_code() -> void:
	var code := code_input.text.strip_edges()
	if code.length() != 6:
		status_label.text = "请输入 6 位邮箱验证码"
		return
	verify_code_button.disabled = true
	var result := await ApiClient.verify_email_code(account_input.text, code)
	verify_code_button.disabled = false
	if not result.ok:
		status_label.text = "验证失败：%s" % result.error
		return
	if bool(result.get("logged_in", false)):
		get_tree().change_scene_to_file("res://scenes/home/home.tscn")
		return
	var verification: Dictionary = result.get("data", {})
	registration_ticket = str(verification.get("registration_ticket", ""))
	if registration_ticket.is_empty():
		status_label.text = "邮箱验证结果不完整，请重新发送验证码"
		return
	code_input.visible = false
	send_code_button.visible = false
	verify_code_button.visible = false
	username_input.visible = true
	nickname_input.visible = true
	avatar_input.visible = true
	password_input.visible = true
	complete_registration_button.visible = true
	status_label.text = "邮箱验证成功，请完善账号资料"
	username_input.grab_focus()


func _complete_email_registration() -> void:
	var username := username_input.text.strip_edges()
	var nickname := nickname_input.text.strip_edges()
	var password := password_input.text
	if username.length() < 3:
		status_label.text = "用户名需为 3-32 位字母、数字或下划线"
		return
	if nickname.is_empty():
		nickname = username
	if password.length() < 10:
		status_label.text = "密码至少需要 10 个字符"
		return
	complete_registration_button.disabled = true
	complete_registration_button.text = "正在注册…"
	var result := await ApiClient.complete_email_registration(registration_ticket, username, nickname, password)
	if not result.ok:
		complete_registration_button.disabled = false
		complete_registration_button.text = "完成注册并登录"
		status_label.text = "注册失败：%s" % result.error
		return
	if not avatar_input.text.strip_edges().is_empty() or not nickname.is_empty():
		await ApiClient.update_user_profile(nickname, avatar_input.text)
	await ApiClient.refresh_user_profile()
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


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
	primary.bg_color = Color("#c84e38")
	primary.border_color = GOLD
	primary.set_border_width_all(2)
	primary.set_corner_radius_all(16)
	login_button.add_theme_stylebox_override("normal", primary)

	var hover := primary.duplicate()
	hover.bg_color = Color("#dc624b")
	hover.set_border_width_all(3)
	login_button.add_theme_stylebox_override("hover", hover)
