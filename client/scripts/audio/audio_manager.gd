extends Node

var _music_player: AudioStreamPlayer
var _effects_player: AudioStreamPlayer
var _effects_playback: AudioStreamGeneratorPlayback
var _effect_voices: Array[Dictionary] = []
var _click_player: AudioStreamPlayer
var _complete_player: AudioStreamPlayer
var _click_stream: AudioStreamWAV
var _correct_stream: AudioStreamWAV
var _complete_stream: AudioStreamWAV
var _music_stream: AudioStreamWAV
var _web_audio: JavaScriptObject
var _last_button_sound_ms := -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_stream = _load_pcm_wav("res://assets/audio/ui_click.wav")
	_correct_stream = _load_pcm_wav("res://assets/audio/correct.wav")
	_complete_stream = _load_pcm_wav("res://assets/audio/complete.wav")
	_music_stream = _load_pcm_wav("res://assets/audio/quiet_search_loop.wav", true)
	if OS.has_feature("web"):
		_web_audio = JavaScriptBridge.get_interface("oddSpotAudio")
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.volume_db = -18.0
	add_child(_music_player)
	_effects_player = AudioStreamPlayer.new()
	_effects_player.name = "Effects"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.03
	_effects_player.stream = generator
	add_child(_effects_player)
	_effects_player.play()
	_effects_playback = _effects_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "Click"
	_click_player.stream = _click_stream
	_click_player.volume_db = -5.0
	_click_player.max_polyphony = 8
	_click_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_click_player)
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


func _process(_delta: float) -> void:
	if _effects_playback == null:
		return
	var frame_count := _effects_playback.get_frames_available()
	if frame_count <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for frame_index in frame_count:
		var mixed := Vector2.ZERO
		for voice in _effect_voices:
			var source: AudioStreamWAV = voice.stream
			var source_frame := int(voice.frame)
			var channel_count := 2 if source.stereo else 1
			var byte_offset := source_frame * channel_count * 2
			if byte_offset + channel_count * 2 > source.data.size():
				continue
			var left := float(source.data.decode_s16(byte_offset)) / 32768.0
			var right := float(source.data.decode_s16(byte_offset + 2)) / 32768.0 if source.stereo else left
			mixed += Vector2(left, right) * float(voice.gain)
			voice.frame = source_frame + 1
		frames[frame_index] = mixed.limit_length(1.0)
		for voice_index in range(_effect_voices.size() - 1, -1, -1):
			var voice: Dictionary = _effect_voices[voice_index]
			var source: AudioStreamWAV = voice.stream
			var channel_count := 2 if source.stereo else 1
			if int(voice.frame) * channel_count * 2 >= source.data.size():
				_effect_voices.remove_at(voice_index)
	_effects_playback.push_buffer(frames)


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
	_play_effect(_correct_stream, -4.0, "correct")


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


func _play_effect(stream: AudioStream, volume_db := -5.0, web_name := "") -> void:
	if not Preferences.effects_enabled:
		return
	if OS.has_feature("web") and _web_audio != null and not web_name.is_empty():
		_web_audio.play(web_name)
		return
	if _effects_playback == null:
		return
	_effect_voices.append({
		"stream": stream,
		"frame": 0,
		"gain": db_to_linear(volume_db),
	})


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


func _load_pcm_wav(path: String, loop := false) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_error("Invalid PCM WAV: %s" % path)
		return AudioStreamWAV.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = bytes.decode_u32(24)
	stream.stereo = bytes.decode_u16(22) == 2
	stream.data = bytes.slice(44)
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
