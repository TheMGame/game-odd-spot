extends Node

signal entitlement_changed(key: String, active: bool)

var no_ads := false


func rewarded_hint_available() -> bool:
	return not Platform.is_wechat_minigame()


func purchase_no_ads_available() -> bool:
	return not Platform.is_wechat_minigame()


func show_rewarded_hint() -> Dictionary:
	if Platform.is_wechat_minigame():
		return {
			"ok": false,
			"error": "FEATURE_NOT_AVAILABLE",
			"provider": "wechat_unconfigured",
		}
	# Mock provider used until a real platform adapter is configured.
	await get_tree().create_timer(0.25).timeout
	var proof := "test_ad_" + ApiClient.new_request_id()
	var result := await ApiClient.claim_test_ad_reward(proof)
	Analytics.track("rewarded_ad_result", {"success": result.ok, "provider": "mock"})
	return result


func purchase_no_ads() -> Dictionary:
	if Platform.is_wechat_minigame():
		return {
			"ok": false,
			"error": "FEATURE_NOT_AVAILABLE",
			"provider": "wechat_unconfigured",
		}
	var transaction_id := ApiClient.new_request_id()
	var result := await ApiClient.verify_test_purchase(transaction_id)
	if result.ok:
		no_ads = true
		entitlement_changed.emit("no_ads", true)
	Analytics.track("purchase_result", {"success": result.ok, "product_id": "no_ads", "platform": "mock"})
	return result
