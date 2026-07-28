extends Control

@onready var status_label: Label = $SafeArea/Content/Status
@onready var retry_button: Button = $SafeArea/Content/Retry
@onready var start_button: Button = $SafeArea/Content/Start
@onready var loading_progress: ProgressBar = $SafeArea/Content/LoadingProgress


func _ready() -> void:
	retry_button.pressed.connect(_bootstrap)
	start_button.pressed.connect(_enter_game)
	_apply_style()
	_bootstrap()


func _bootstrap() -> void:
	retry_button.visible = false
	start_button.visible = false
	status_label.text = tr("正在准备旅程…")
	loading_progress.value = 15
	await LocaleManager.initialize_web_default()
	if not SessionStore.has_access_token():
		_enter_login()
		return
	if not SessionStore.has_valid_access_token():
		status_label.text = tr("正在恢复登录状态…")
		var refresh := await ApiClient.refresh_session()
		if not refresh.ok:
			if SessionStore.has_access_token():
				_show_error(str(refresh.get("error", "SESSION_REFRESH_FAILED")))
			else:
				_enter_login()
			return
	loading_progress.value = 55
	status_label.text = tr("正在加载启动配置…")
	var bootstrap := await ApiClient.get_bootstrap()
	if not bootstrap.ok:
		_show_error(str(bootstrap.get("error", "BOOTSTRAP_FAILED")))
		return
	LocaleManager.apply_bootstrap(bootstrap.data.get("data", {}))
	loading_progress.value = 82
	status_label.text = tr("正在同步本地进度…")
	await SyncQueue.flush()
	loading_progress.value = 100
	status_label.text = tr("一切就绪")
	_enter_home()


func _show_error(error: String) -> void:
	status_label.text = tr("暂时无法完成启动：%s\n请检查网络后重试") % error
	retry_button.visible = true


func _enter_game() -> void:
	_enter_login()


func _enter_login() -> void:
	get_tree().change_scene_to_file("res://scenes/login/login.tscn")


func _enter_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home/home.tscn")


func _apply_style() -> void:
	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#c84e38")
	primary.border_color = Color("#e6b95c")
	primary.set_border_width_all(2)
	primary.set_corner_radius_all(18)
	start_button.add_theme_stylebox_override("normal", primary)
