class_name Platform
extends RefCounted

const FEATURE_WECHAT_MINIGAME := "wechat_minigame"


static func is_wechat_minigame() -> bool:
	return OS.has_feature(FEATURE_WECHAT_MINIGAME)


static func is_web_like() -> bool:
	return OS.has_feature("web") or is_wechat_minigame()


static func is_native() -> bool:
	return not is_web_like()
