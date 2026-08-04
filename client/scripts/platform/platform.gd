class_name Platform
extends RefCounted

const FEATURE_WECHAT_MINIGAME := "wechat_minigame"


static func is_wechat_minigame() -> bool:
	return OS.has_feature(FEATURE_WECHAT_MINIGAME)


static func is_web_like() -> bool:
	return OS.has_feature("web") or is_wechat_minigame()


static func is_native() -> bool:
	return not is_web_like()


static func vibrate_handheld(duration_ms := 35) -> void:
	if is_wechat_minigame():
		var wechat = JavaScriptBridge.get_interface("wx")
		if wechat != null:
			wechat.vibrateShort({"type": "light"})
		return
	Input.vibrate_handheld(duration_ms)


## Let a ScrollContainer keep receiving a drag that starts on a button.
##
## WeChat delivers touch input through the Web mouse-emulation path. A button
## using MOUSE_FILTER_STOP can otherwise consume the press before its parent
## ScrollContainer sees enough motion to begin touch scrolling.
static func optimize_touch_scroll(scroll: ScrollContainer) -> void:
	if not is_wechat_minigame() or scroll == null:
		return
	scroll.scroll_deadzone = 4
	_set_scroll_buttons_to_pass(scroll)
	if not scroll.has_node("WechatScrollDriver"):
		# Build the path at runtime so the Web exporter can omit this
		# WeChat-only script without recording it as a pack dependency.
		var driver_script := load("res://scripts/platform/" + "wechat_scroll_driver.gd") as Script
		if driver_script == null:
			return
		var driver = driver_script.new()
		driver.name = "WechatScrollDriver"
		scroll.add_child(driver)
		driver.configure(scroll)


static func _set_scroll_buttons_to_pass(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			(child as BaseButton).mouse_filter = Control.MOUSE_FILTER_PASS
		_set_scroll_buttons_to_pass(child)
