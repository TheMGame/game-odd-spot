extends Control

@onready var details: Label = $Layout/LevelCard/Content/Details
@onready var play_button: Button = $Layout/LevelCard/Content/Play
@onready var sync_status: Label = $Layout/SyncStatus


func _ready() -> void:
	play_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
	$Layout/Refresh.pressed.connect(_refresh)
	$Layout/Daily.pressed.connect(_open_daily)
	$Layout/Settings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings/settings.tscn"))
	_refresh()
	Analytics.track("home_impression")


func _refresh() -> void:
	await SyncQueue.flush()
	var home := await ApiClient.get_home()
	if home.ok:
		var items: Array = home.data.get("data", {}).get("items", [])
		if not items.is_empty():
			var item: Dictionary = items[0]
			details.text = "%d 个不同之处 · 难度 %d" % [int(item.get("difference_count", 5)), int(item.get("difficulty", 2))]
	else:
		details.text = "5 个不同之处 · 本地模式"
	var activities := await ApiClient.get_activities()
	if activities.ok:
		var activity_items: Array = activities.data.get("data", {}).get("items", [])
		if not activity_items.is_empty():
			$Layout/Subtitle.text = str(activity_items[0].get("name", "今日找茬"))
	var experiment := await ApiClient.get_experiment("home_layout")
	if experiment.ok:
		Analytics.track("experiment_exposure", experiment.data.get("data", {}))
	_update_sync_status()
	Analytics.flush()


func _update_sync_status() -> void:
	var pending := SyncQueue.pending_count()
	sync_status.text = "进度已同步" if pending == 0 else "%d 条进度等待联网同步" % pending


func _open_daily() -> void:
	var result := await ApiClient.get_daily_challenge()
	Analytics.track("theme_click", {"source": "daily_challenge", "online": result.ok})
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
