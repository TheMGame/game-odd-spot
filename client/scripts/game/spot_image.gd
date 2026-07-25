class_name SpotImage
extends Control

signal normalized_pressed(point: Vector2)
signal view_changed(zoom: float, offset: Vector2)

var texture: Texture2D
var zoom := 1.0
var minimum_zoom := 1.0
var view_offset := Vector2.ZERO
var markers: Array[Dictionary] = []
var _dragging := false
var _drag_distance := 0.0
var _last_pointer := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)


func set_texture(value: Texture2D) -> void:
	texture = value
	queue_redraw()


func set_view(new_zoom: float, new_offset: Vector2) -> void:
	zoom = clampf(new_zoom, minimum_zoom, 4.0)
	view_offset = new_offset
	_clamp_offset()
	queue_redraw()


func configure_fit_view() -> void:
	minimum_zoom = 1.0
	zoom = 1.0
	view_offset = Vector2.ZERO
	queue_redraw()


func add_marker(point: Vector2) -> void:
	markers.append({"point": point, "age": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	var animating := false
	for marker in markers:
		if float(marker.get("age", 0.0)) < 1.0:
			marker["age"] = float(marker.get("age", 0.0)) + delta
			animating = true
	if animating:
		queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var draw_rect := _texture_rect()
	draw_texture_rect(texture, draw_rect, false)
	for marker in markers:
		var point: Vector2 = marker.get("point", Vector2.ZERO)
		var center := draw_rect.position + point * draw_rect.size
		var marker_radius := 38.0 if Preferences.large_markers else 28.0
		var age := float(marker.get("age", 1.0))
		if age < 0.65:
			var burst := marker_radius + age * 75.0
			draw_arc(center, burst, 0.0, TAU, 48, Color(0.96, 0.68, 0.22, 0.75 - age), 4.0, true)
			for i in 8:
				var angle := i * TAU / 8.0 + age
				var from := center + Vector2.from_angle(angle) * (marker_radius + 7.0)
				var to := center + Vector2.from_angle(angle) * (marker_radius + 18.0 + age * 28.0)
				draw_line(from, to, Color(0.98, 0.73, 0.28, 0.85 - age), 3.0, true)
		var pulse := 1.0 + sin(age * 9.0) * 0.08 if age < 1.0 else 1.0
		draw_circle(center, marker_radius * pulse, Color(0.66, 0.14, 0.08, 0.20))
		draw_arc(center, marker_radius * pulse, 0.0, TAU, 48, Color("#c64b2f"), 5.0, true)
		draw_arc(center, marker_radius * pulse + 4.0, 0.0, TAU, 48, Color(0.95, 0.67, 0.25, 0.72), 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, zoom * 1.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, zoom / 1.2)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_finish_pointer(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_pointer(event.position)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_start_drag(event.position)
		elif _touches.size() == 2:
			_dragging = false
			_begin_pinch()
	else:
		var was_single := _touches.size() == 1
		_touches.erase(event.index)
		if was_single:
			_finish_pointer(event.position)
		elif _touches.size() == 1:
			_start_drag(_touches.values()[0])
		else:
			_dragging = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var positions := _touches.values()
		var current_distance: float = positions[0].distance_to(positions[1])
		if _pinch_start_distance > 1.0:
			var center: Vector2 = (positions[0] + positions[1]) * 0.5
			_zoom_at(center, _pinch_start_zoom * current_distance / _pinch_start_distance)
	elif _dragging:
		_drag_pointer(event.position)


func _begin_pinch() -> void:
	var positions := _touches.values()
	_pinch_start_distance = positions[0].distance_to(positions[1])
	_pinch_start_zoom = zoom


func _start_drag(position: Vector2) -> void:
	_dragging = true
	_drag_distance = 0.0
	_last_pointer = position


func _drag_pointer(position: Vector2) -> void:
	var delta := position - _last_pointer
	_last_pointer = position
	_drag_distance += delta.length()
	if zoom > 1.0:
		view_offset += delta
		_clamp_offset()
		view_changed.emit(zoom, view_offset)
		queue_redraw()


func _finish_pointer(position: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if _drag_distance <= 12.0:
		var rect := _texture_rect()
		if rect.has_point(position):
			normalized_pressed.emit((position - rect.position) / rect.size)


func _zoom_at(pointer: Vector2, new_zoom: float) -> void:
	var before := _texture_rect()
	var normalized := (pointer - before.position) / before.size
	zoom = clampf(new_zoom, minimum_zoom, 4.0)
	var after := _texture_rect()
	view_offset += pointer - (after.position + normalized * after.size)
	_clamp_offset()
	view_changed.emit(zoom, view_offset)
	queue_redraw()


func _texture_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var source := texture.get_size()
	var fit_scale := minf(size.x / source.x, size.y / source.y)
	var draw_size := source * fit_scale * zoom
	return Rect2((size - draw_size) * 0.5 + view_offset, draw_size)


func _clamp_offset() -> void:
	if zoom <= 1.001:
		view_offset = Vector2.ZERO
		return
	var rect := _texture_rect()
	var limit := (rect.size - size) * 0.5
	view_offset.x = clampf(view_offset.x, -limit.x, limit.x)
	view_offset.y = clampf(view_offset.y, -limit.y, limit.y)
