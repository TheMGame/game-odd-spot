extends Control

@onready var status_label: Label = $SafeArea/Content/Status
@onready var retry_button: Button = $SafeArea/Content/Retry
@onready var start_button: Button = $SafeArea/Content/Start


func _ready() -> void:
	retry_button.pressed.connect(_bootstrap)
	start_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home/home.tscn"))
	_bootstrap()


func _bootstrap() -> void:
	retry_button.visible = false
	status_label.text = "正在创建会话…"
	var session_result := await ApiClient.ensure_session()
	if not session_result.ok:
		_show_error(session_result.error)
		return

	status_label.text = "正在加载配置…"
	var bootstrap_result := await ApiClient.get_bootstrap()
	if not bootstrap_result.ok:
		_show_error(bootstrap_result.error)
		return

	var data: Dictionary = bootstrap_result.data.get("data", {})
	status_label.text = "连接成功\n市场：%s　语言：%s" % [data.get("market", "unknown"), data.get("locale", "unknown")]
	SyncQueue.flush()
	Analytics.track("bootstrap_result", {"success": true, "market": data.get("market", "global"), "config_version": data.get("config_version", 0)})
	Analytics.flush()
	start_button.visible = true


func _show_error(message: String) -> void:
	status_label.text = "连接失败：%s" % message
	retry_button.visible = true
	# P0 支持本地测试关卡，即使服务不可用也允许进入。
	start_button.visible = true
