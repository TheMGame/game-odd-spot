class_name WechatScrollDriver
extends Node

const DRAG_THRESHOLD := 4.0

var _scroll: ScrollContainer
var _pointer_down := false
var _dragging := false
var _using_touch := false
var _touch_index := -1
var _last_position := Vector2.ZERO
var _drag_distance := 0.0


func configure(scroll: ScrollContainer) -> void:
	_scroll = scroll
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll) or not _scroll.is_visible_in_tree():
		_reset_drag()
		return

	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_handle_wheel(mb.position, _wheel_step(true))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_handle_wheel(mb.position, _wheel_step(false))
		else:
			_handle_mouse_button(mb)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _pointer_down or not _can_start_at(event.position):
			return
		_using_touch = true
		_touch_index = event.index
		_begin_drag(event.position)
	elif _using_touch and event.index == _touch_index:
		_finish_drag()


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if not _pointer_down or not _using_touch or event.index != _touch_index:
		return
	_drag_to(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or _using_touch:
		return
	if event.pressed:
		if not _pointer_down and _can_start_at(event.position):
			_begin_drag(event.position)
	elif _pointer_down:
		_finish_drag()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pointer_down or _using_touch:
		return
	if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_finish_drag()
		return
	_drag_to(event.position)


func _can_start_at(position: Vector2) -> bool:
	if not _scroll.get_global_rect().has_point(position):
		return false
	var bar := _scroll.get_v_scroll_bar()
	return bar != null and bar.max_value > bar.page


func _begin_drag(position: Vector2) -> void:
	_pointer_down = true
	_dragging = false
	_last_position = position
	_drag_distance = 0.0


func _drag_to(position: Vector2) -> void:
	var delta := position - _last_position
	_last_position = position
	_drag_distance += delta.length()
	if not _dragging and _drag_distance >= DRAG_THRESHOLD:
		_dragging = true
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	if not _dragging:
		return
	_scroll.scroll_vertical -= roundi(delta.y)
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	if _dragging:
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_viewport().set_input_as_handled()
	_reset_drag()


func _wheel_step(up: bool) -> int:
	var bar := _scroll.get_v_scroll_bar()
	var step := 48
	if bar != null:
		var page_size := max(1.0, float(bar.page))
		step = max(24, int(page_size / 8.0))
	return -step if up else step


func _handle_wheel(position: Vector2, delta: int) -> void:
	if not _scroll.get_global_rect().has_point(position):
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= bar.page:
		return
	_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_scroll.scroll_vertical += delta
	_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	get_viewport().set_input_as_handled()


func _reset_drag() -> void:
	_pointer_down = false
	_dragging = false
	_using_touch = false
	_touch_index = -1
	_drag_distance = 0.0
