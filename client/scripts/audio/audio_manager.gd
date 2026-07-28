extends Node

var _music_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _correct_player: AudioStreamPlayer
var _complete_player: AudioStreamPlayer
var _click_stream: AudioStreamWAV
var _correct_stream: AudioStreamWAV
var _complete_stream: AudioStreamWAV
var _music_stream: AudioStreamWAV
var _web_audio: JavaScriptObject
var _last_button_sound_ms := -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_stream = _load_wav_resource("res://assets/audio/ui_click.wav")
	_correct_stream = _load_wav_resource("res://assets/audio/correct.wav")
	_complete_stream = _load_wav_resource("res://assets/audio/complete.wav")
	_music_stream = _load_wav_resource("res://assets/audio/quiet_search_loop.wav", true)
	if OS.has_feature("web"):
		_web_audio = JavaScriptBridge.get_interface("oddSpotAudio")
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.volume_db = -18.0
	add_child(_music_player)
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "Click"
	_click_player.stream = _click_stream
	_click_player.volume_db = -5.0
	_click_player.max_polyphony = 8
	add_child(_click_player)
	_correct_player = AudioStreamPlayer.new()
	_correct_player.name = "Correct"
	_correct_player.stream = _correct_stream
	_correct_player.volume_db = -4.0
	_correct_player.max_polyphony = 4
	add_child(_correct_player)
	_complete_player = AudioStreamPlayer.new()
	_complete_player.name = "Complete"
	_complete_player.stream = _complete_stream
	_complete_player.volume_db = -5.0
	_complete_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_complete_player)
	_music_player.stream = _music_stream
	_apply_preferences()
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons(get_tree().root)


func _apply_preferences() -> void:
	_music_player.stream_paused = not Preferences.music_enabled
	if Preferences.music_enabled and not _music_player.playing:
		_music_player.play()


func set_music_enabled(enabled: bool) -> void:
	Preferences.set_value("audio", "music", enabled)
	_apply_preferences()


func set_effects_enabled(enabled: bool) -> void:
	Preferences.set_value("audio", "effects", enabled)


func play_correct() -> void:
	if not Preferences.effects_enabled:
		return
	if OS.has_feature("web") and _web_audio != null:
		_web_audio.play("correct")
		return
	_correct_player.play()


func play_complete() -> void:
	if not Preferences.effects_enabled:
		return
	if OS.has_feature("web") and _web_audio != null:
		_web_audio.play("complete")
		return
	_complete_player.play()


func play_click() -> void:
	if not Preferences.effects_enabled:
		return
	if OS.has_feature("web") and _web_audio != null:
		_web_audio.play("click")
		return
	_click_player.play()


func _on_node_added(node: Node) -> void:
	if node is Button:
		_connect_button.call_deferred(node)


func _connect_buttons(root: Node) -> void:
	if root is Button:
		_connect_button(root)
	for child in root.get_children():
		_connect_buttons(child)


func _connect_button(button: Button) -> void:
	if not is_instance_valid(button) or button.has_meta("audio_click_connected"):
		return
	button.set_meta("audio_click_connected", true)
	button.gui_input.connect(_on_button_input)


func _on_button_input(event: InputEvent) -> void:
	var just_pressed: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	) or (
		event is InputEventScreenTouch
		and event.pressed
	)
	if not just_pressed:
		return
	var now := Time.get_ticks_msec()
	if now - _last_button_sound_ms < 50:
		return
	_last_button_sound_ms = now
	play_click()


func _load_wav_resource(path: String, loop := false) -> AudioStreamWAV:
	# ResourceLoader resolves the imported .sample file in exported builds.
	# Reading the source WAV with FileAccess only works inside the source tree.
	var imported := load(path) as AudioStreamWAV
	if imported == null:
		push_error("Could not load WAV resource: %s" % path)
		return AudioStreamWAV.new()
	var stream := imported.duplicate() as AudioStreamWAV
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
