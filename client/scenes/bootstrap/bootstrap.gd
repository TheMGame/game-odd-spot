extends Control

@onready var status_label: Label = $SafeArea/Content/Status
@onready var retry_button: Button = $SafeArea/Content/Retry
@onready var start_button: Button = $SafeArea/Content/Start


func _ready() -> void:
	retry_button.pressed.connect(_bootstrap)
	start_button.pressed.connect(_enter_game)
	_apply_style()
	_bootstrap()


func _bootstrap() -> void:
	retry_button.visible = false
	status_label.text = "正在准备旅程…"
	status_label.text = "一切就绪"
	await get_tree().create_timer(0.35).timeout
	_enter_game()


func _show_error() -> void:
	status_label.text = "暂时无法连接服务器\n你仍然可以继续本地游戏"
	retry_button.visible = true
	start_button.visible = true
	start_button.text = "继续离线游戏"


func _enter_game() -> void:
	get_tree().change_scene_to_file("res://scenes/login/login.tscn")


func _apply_style() -> void:
	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#a33b2b")
	primary.border_color = Color("#d8ae62")
	primary.set_border_width_all(2)
	primary.set_corner_radius_all(18)
	start_button.add_theme_stylebox_override("normal", primary)
