class_name SpotImage
extends Control

signal normalized_pressed(point: Vector2)
signal view_changed(zoom: float, offset: Vector2)

var texture: Texture2D
var zoom := 1.0
var view_offset := Vector2.ZERO
var markers: Array[Vector2] = []
var _dragging := false
var _drag_distance := 0.0
var _last_pointer := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_texture(value: Texture2D) -> void:
	texture = value
	queue_redraw()


func set_view(new_zoom: float, new_offset: Vector2) -> void:
	zoom = clampf(new_zoom, 1.0, 4.0)
	view_offset = new_offset
	_clamp_offset()
	queue_redraw()


func add_marker(point: Vector2) -> void:
	markers.append(point)
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var draw_rect := _texture_rect()
	draw_texture_rect(texture, draw_rect, false)
	for point in markers:
		var center := draw_rect.position + point * draw_rect.size
		var marker_radius := 38.0 if Preferences.large_markers else 28.0
		draw_circle(center, marker_radius, Color(1.0, 0.82, 0.15, 0.22))
		draw_arc(center, marker_radius, 0.0, TAU, 48, Color(1.0, 0.78, 0.08), 5.0, true)


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
		if event.pressed: _start_drag(event.position)
		else: _finish_pointer(event.position)
	elif event is InputEventScreenDrag and _dragging:
		_drag_pointer(event.position)


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
	zoom = clampf(new_zoom, 1.0, 4.0)
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
	if zoom <= 1.0:
		view_offset = Vector2.ZERO
		return
	var rect := _texture_rect()
	var limit := (rect.size - size) * 0.5
	view_offset.x = clampf(view_offset.x, -limit.x, limit.x)
	view_offset.y = clampf(view_offset.y, -limit.y, limit.y)
