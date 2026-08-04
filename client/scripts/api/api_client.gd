extends Node

const DEFAULT_BASE_URL := "https://oddspot.guaguatu.com"
const DEFAULT_USER_SERVER_URL := "https://api.guaguatu.com"
const USER_SERVER_APP_ID := "game_odd_spot"
const GET_TIMEOUT_SECONDS := 10.0
const AUTH_TIMEOUT_SECONDS := 10.0
const WRITE_TIMEOUT_SECONDS := 15.0
const MAX_REQUEST_ATTEMPTS := 3

var base_url := DEFAULT_BASE_URL
var business_date := ""
var app_timezone := ""


func ensure_session() -> Dictionary:
	_configure_base_url()
	if SessionStore.has_access_token():
		return {"ok": true, "data": {}}
	return {"ok": false, "error": "LOGIN_REQUIRED"}


func get_bootstrap() -> Dictionary:
	var result := await _request_json(HTTPClient.METHOD_GET, "/v1/bootstrap", {}, true, true)
	if result.ok:
		var data: Dictionary = result.data.get("data", {})
		business_date = str(data.get("business_date", business_date))
		app_timezone = str(data.get("app_timezone", app_timezone))
	return result


func get_locales() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/locales", {}, false, true)


func get_default_locale() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/locale/default", {}, false, true)


func update_locale(locale: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_PUT, "/v1/session/locale", {
		"locale": locale,
	}, true, true)


func get_business_date() -> Dictionary:
	if not business_date.is_empty():
		return {"ok": true, "business_date": business_date, "app_timezone": app_timezone}
	var result := await get_bootstrap()
	if not result.ok:
		return result
	var data: Dictionary = result.data.get("data", {})
	var business_date := str(data.get("business_date", ""))
	if business_date.is_empty():
		return {"ok": false, "error": "BUSINESS_DATE_MISSING"}
	return {
		"ok": true,
		"business_date": business_date,
		"app_timezone": str(data.get("app_timezone", "")),
	}


func get_home() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/home", {}, true, true)

func get_catalog() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/catalog", {}, true, true)


func get_daily_challenge() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/daily-challenge", {}, true, true)


func get_activities() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/activities", {}, true, true)


func get_experiment(key: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/experiments/%s" % key.uri_encode(), {}, true, true)


func send_events(events: Array) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/v1/events/batch", {"events": events}, true, true)


func claim_test_ad_reward(proof: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/v1/rewards/ad", {"provider": "mock", "proof": proof, "reward_type": "hint"}, true, true, new_request_id())


func verify_test_purchase(transaction_id: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/v1/purchases/verify", {"platform": "mock", "product_id": "no_ads", "transaction_id": transaction_id, "receipt": "test_purchase_" + transaction_id}, true, true, new_request_id())


func bind_test_account(account_name: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/v1/account/bind", {"provider": "test", "proof": "test_account_" + account_name}, true, true)


func login_test_account(account_name: String) -> Dictionary:
	var response := await _request_json(HTTPClient.METHOD_POST, "/v1/account/login", {"provider": "test", "proof": "test_account_" + account_name}, false, false)
	if response.ok:
		SessionStore.update_session(response.data.get("data", {}))
	return response


func login_user(account_name: String, password: String) -> Dictionary:
	var body := {
		"app_id": USER_SERVER_APP_ID,
		"login_type": 1,
		"password": password,
	}
	if account_name.contains("@"):
		body["email"] = account_name.strip_edges().to_lower()
	else:
		body["username"] = account_name.strip_edges()
	var result := await _request_user_server("/api/v1/user/login", body)
	if not result.ok:
		return result
	var login_data: Dictionary = result.data.get("data", {})
	return await _exchange_user_token(login_data)


func login_wechat() -> Dictionary:
	if not Platform.is_wechat_minigame():
		return {"ok": false, "error": "WECHAT_LOGIN_UNAVAILABLE"}
	var code_result := await _request_wechat_login_code()
	if not code_result.ok:
		return code_result
	var wx_info := {
		"code": str(code_result.get("code", "")),
	}
	var profile: Dictionary = code_result.get("profile", {})
	if not profile.is_empty():
		wx_info["nickname"] = str(profile.get("nickname", ""))
		wx_info["avatar"] = str(profile.get("avatar_url", ""))
		wx_info["avatar_url"] = str(profile.get("avatar_url", ""))
	var result := await _request_user_server("/api/v1/user/login", {
		"app_id": USER_SERVER_APP_ID,
		"login_type": 2,
		"wx_info": wx_info,
	})
	if not result.ok:
		return result
	var login_data: Dictionary = result.data.get("data", {})
	var exchanged := await _exchange_user_token(login_data)
	if exchanged.ok and not profile.is_empty():
		await update_user_profile(str(profile.get("nickname", "")), str(profile.get("avatar_url", "")))
		await refresh_user_profile()
	return exchanged


func _request_wechat_login_code() -> Dictionary:
	var wechat_auth = JavaScriptBridge.get_interface("oddSpotWechatAuth")
	if wechat_auth == null:
		return {"ok": false, "error": "WECHAT_API_UNAVAILABLE"}
	wechat_auth.begin()
	for _attempt in range(120):
		await get_tree().create_timer(0.1).timeout
		var parsed = JsonUtils.parse_string(str(wechat_auth.getResult()))
		if not parsed is Dictionary:
			continue
		match str(parsed.get("state", "")):
			"success":
				var code := str(parsed.get("code", "")).strip_edges()
				if code.is_empty():
					return {"ok": false, "error": "WECHAT_LOGIN_CODE_MISSING"}
				var profile: Dictionary = parsed.get("profile", {})
				return {"ok": true, "code": code, "profile": profile}
			"failed":
				return {
					"ok": false,
					"error": "WECHAT_LOGIN_FAILED",
					"message": str(parsed.get("message", "")),
				}
	return {"ok": false, "error": "WECHAT_LOGIN_TIMEOUT"}


func register_user(account_name: String, password: String) -> Dictionary:
	var result := await _request_user_server("/api/v1/user/register", {
		"app_id": USER_SERVER_APP_ID,
		"username": account_name,
		"nickname": account_name,
		"password": password,
	})
	if not result.ok:
		return result
	var register_data: Dictionary = result.data.get("data", {})
	var login_data: Dictionary = register_data.get("login_info", register_data)
	return await _exchange_user_token(login_data)


func send_email_code(email: String) -> Dictionary:
	return await _request_user_server("/api/v1/user/email/send-code", {
		"app_id": USER_SERVER_APP_ID,
		"email": email.strip_edges().to_lower(),
		"purpose": "login",
	})


func verify_email_code(email: String, code: String) -> Dictionary:
	var result := await _request_user_server("/api/v1/user/email/verify", {
		"app_id": USER_SERVER_APP_ID,
		"email": email.strip_edges().to_lower(),
		"code": code.strip_edges(),
	})
	if not result.ok:
		return result
	var verification: Dictionary = result.data.get("data", {})
	if verification.get("login_info") is Dictionary:
		var exchanged := await _exchange_user_token(verification.login_info)
		if exchanged.ok:
			exchanged["logged_in"] = true
		return exchanged
	return {"ok": true, "data": verification}


func complete_email_registration(ticket: String, username: String, nickname: String, password: String) -> Dictionary:
	var result := await _request_user_server("/api/v1/user/email/complete-registration", {
		"app_id": USER_SERVER_APP_ID,
		"registration_ticket": ticket,
		"username": username.strip_edges(),
		"nickname": nickname.strip_edges(),
		"password": password,
	})
	if not result.ok:
		return result
	return await _exchange_user_token(result.data.get("data", {}))


func update_user_profile(nickname: String, avatar: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = 8.0
	add_child(request)
	var user_server_url := str(ProjectSettings.get_setting("oddspot/network/user_server_base_url", DEFAULT_USER_SERVER_URL)).trim_suffix("/")
	var body := {"nickname": nickname.strip_edges(), "avatar": avatar.strip_edges()}
	var start_error := request.request(
		user_server_url + "/api/v1/user/info/" + SessionStore.user_id.uri_encode(),
		PackedStringArray(["Accept: application/json", "Content-Type: application/json", "Authorization: Bearer %s" % SessionStore.user_server_token]),
		HTTPClient.METHOD_PUT,
		JSON.stringify(body)
	)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "request could not start"}
	var response: Array = await request.request_completed
	request.queue_free()
	var parsed = JsonUtils.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if response[0] != HTTPRequest.RESULT_SUCCESS or not parsed is Dictionary:
		return {"ok": false, "error": "USER_PROFILE_UNAVAILABLE"}
	if response[1] < 200 or response[1] >= 300 or int(parsed.get("code", -1)) != 0:
		return {"ok": false, "error": str(parsed.get("message", "USER_PROFILE_FAILED"))}
	return {"ok": true, "data": parsed}


func _exchange_user_token(login_data: Dictionary) -> Dictionary:
	var user_token := str(login_data.get("token", ""))
	if user_token.is_empty():
		return {"ok": false, "error": "USER_TOKEN_MISSING"}
	var response := await _request_json(HTTPClient.METHOD_POST, "/v1/sessions/user-server", {
		"token": user_token,
		"locale": TranslationServer.get_locale(),
	}, false, false)
	if response.ok:
		var session_data: Dictionary = response.data.get("data", {})
		var user_info: Dictionary = login_data.get("user_info", login_data.get("user", login_data.get("profile", {})))
		if user_info.is_empty():
			user_info = login_data
		var returned_name := str(user_info.get("nickname", user_info.get("username", user_info.get("name", user_info.get("display_name", "")))))
		var returned_avatar := str(user_info.get("avatar_url", user_info.get("avatar", user_info.get("avatarUrl", ""))))
		if not returned_name.is_empty():
			session_data["username"] = returned_name
		if not returned_avatar.is_empty():
			session_data["avatar_url"] = returned_avatar
		session_data["user_server_token"] = user_token
		session_data["user_server_refresh_token"] = str(login_data.get("refresh_token", ""))
		SessionStore.update_session(session_data)
	return response


func refresh_user_profile() -> Dictionary:
	if SessionStore.user_server_token.is_empty():
		return {"ok": false, "error": "USER_PROFILE_SESSION_MISSING"}
	var result := await _request_user_server_profile()
	if not result.ok and not SessionStore.user_server_refresh_token.is_empty():
		var refreshed := await _request_user_server("/api/v1/user/refresh_token", {
			"app_id": USER_SERVER_APP_ID,
			"refresh_token": SessionStore.user_server_refresh_token,
		})
		if refreshed.ok:
			var refresh_data: Dictionary = refreshed.data.get("data", {})
			SessionStore.user_server_token = str(refresh_data.get("token", SessionStore.user_server_token))
			SessionStore.user_server_refresh_token = str(refresh_data.get("refresh_token", SessionStore.user_server_refresh_token))
			result = await _request_user_server_profile()
	if not result.ok:
		return result
	var profile: Dictionary = result.data.get("data", {})
	if profile.has("user_info") and profile.user_info is Dictionary:
		profile = profile.user_info
	var session_data := {
		"user_id": SessionStore.user_id,
		"access_token": SessionStore.access_token,
		"refresh_token": SessionStore.refresh_token,
		"username": str(profile.get("nickname", profile.get("username", profile.get("name", "")))),
		"avatar_url": str(profile.get("avatar", profile.get("avatar_url", ""))),
		"user_server_token": SessionStore.user_server_token,
		"user_server_refresh_token": SessionStore.user_server_refresh_token,
	}
	SessionStore.update_session(session_data)
	return {"ok": true, "data": profile}


func _request_user_server_profile() -> Dictionary:
	var request := HTTPRequest.new()
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = 8.0
	add_child(request)
	var user_server_url := str(ProjectSettings.get_setting("oddspot/network/user_server_base_url", DEFAULT_USER_SERVER_URL)).trim_suffix("/")
	var path := "/api/v1/user/info/%s" % SessionStore.user_id.uri_encode()
	var start_error := request.request(user_server_url + path,
		PackedStringArray(["Accept: application/json", "Authorization: Bearer %s" % SessionStore.user_server_token]),
		HTTPClient.METHOD_GET)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "request could not start"}
	var response: Array = await request.request_completed
	request.queue_free()
	var parsed = JsonUtils.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if response[0] != HTTPRequest.RESULT_SUCCESS or not parsed is Dictionary:
		return {"ok": false, "error": "USER_PROFILE_UNAVAILABLE"}
	if response[1] < 200 or response[1] >= 300 or int(parsed.get("code", -1)) != 0:
		return {"ok": false, "error": str(parsed.get("message", "USER_PROFILE_FAILED"))}
	return {"ok": true, "data": parsed}


func _request_user_server(path: String, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = 8.0
	add_child(request)
	var user_server_url := str(ProjectSettings.get_setting("oddspot/network/user_server_base_url", DEFAULT_USER_SERVER_URL)).trim_suffix("/")
	var start_error := request.request(user_server_url + path,
		PackedStringArray(["Accept: application/json", "Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": "request could not start"}
	var result: Array = await request.request_completed
	request.queue_free()
	var status_code: int = result[1]
	var parsed = JsonUtils.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if result[0] != HTTPRequest.RESULT_SUCCESS or not parsed is Dictionary:
		return {"ok": false, "error": "USER_SERVER_UNAVAILABLE"}
	if status_code < 200 or status_code >= 300 or int(parsed.get("code", -1)) != 0:
		return {"ok": false, "error": str(parsed.get("message", "LOGIN_FAILED")), "data": parsed}
	return {"ok": true, "data": parsed}


func report_level(level_id: String, category: String, description: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/v1/reports", {"level_id": level_id, "category": category, "description": description}, true, true)


func get_level(level_id: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/levels/%s" % level_id.uri_encode(), {}, true, true)


func start_level(level_id: String, level_version: int, attempt_id: String, idempotency_key := "") -> Dictionary:
	return await write_level("/v1/levels/%s/start" % level_id.uri_encode(), {
		"attempt_id": attempt_id,
		"level_version": level_version,
	}, idempotency_key)


func update_level_progress(level_id: String, attempt_id: String, found: Array, hints_used: int, duration_ms: int, idempotency_key := "") -> Dictionary:
	return await write_level("/v1/levels/%s/progress" % level_id.uri_encode(), {
		"attempt_id": attempt_id,
		"found": found,
		"hints_used": hints_used,
		"duration_ms": duration_ms,
	}, idempotency_key)


func complete_level(level_id: String, attempt_id: String, difference_ids: Array, hints_used: int, duration_ms: int, idempotency_key := "") -> Dictionary:
	return await write_level("/v1/levels/%s/complete" % level_id.uri_encode(), {
		"attempt_id": attempt_id,
		"difference_ids": difference_ids,
		"hints_used": hints_used,
		"duration_ms": duration_ms,
	}, idempotency_key)


func write_level(path: String, body: Dictionary, idempotency_key := "") -> Dictionary:
	var stable_key := idempotency_key if not idempotency_key.is_empty() else new_request_id()
	return await _request_json(HTTPClient.METHOD_POST, path, body, true, true, stable_key)


func refresh_session() -> Dictionary:
	if SessionStore.refresh_token.is_empty():
		return {"ok": false, "error": "REFRESH_TOKEN_MISSING"}
	var response := await _request_json(HTTPClient.METHOD_POST, "/v1/sessions/refresh", {
		"refresh_token": SessionStore.refresh_token,
	}, false, false)
	if response.ok:
		SessionStore.update_session(response.data.get("data", {}))
	elif _is_invalid_refresh_response(response):
		SessionStore.clear_session()
	return response


func logout() -> void:
	if SessionStore.has_access_token() and not SessionStore.refresh_token.is_empty():
		await _request_json(HTTPClient.METHOD_POST, "/v1/sessions/logout", {
			"refresh_token": SessionStore.refresh_token,
		}, true, false)
	SessionStore.clear_session()


func _request_json(method: HTTPClient.Method, path: String, body: Dictionary, authenticated: bool, allow_refresh := false, idempotency_key := "", attempt := 1) -> Dictionary:
	_configure_base_url()
	if authenticated and allow_refresh and not SessionStore.has_valid_access_token():
		var proactive_refresh := await refresh_session()
		if not proactive_refresh.ok:
			return proactive_refresh
	var request := HTTPRequest.new()
	request.accept_gzip = not Platform.is_web_like()
	request.timeout = _request_timeout(method, path)
	add_child(request)
	var headers := PackedStringArray(["Accept: application/json"])
	var encoded_body := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		encoded_body = JSON.stringify(body)
	if authenticated:
		headers.append("Authorization: Bearer %s" % SessionStore.access_token)
	if not idempotency_key.is_empty():
		headers.append("Idempotency-Key: %s" % idempotency_key)

	var start_error := request.request(base_url + path, headers, method, encoded_body)
	if start_error != OK:
		request.queue_free()
		var start_failure := {"ok": false, "error": "REQUEST_START_FAILED", "status": 0, "retryable": true}
		return await _retry_or_return(start_failure, method, path, body, authenticated, allow_refresh, idempotency_key, attempt)

	var result: Array = await request.request_completed
	request.queue_free()
	var network_result: int = result[0]
	var status_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	if network_result != HTTPRequest.RESULT_SUCCESS:
		var network_failure := {"ok": false, "error": "NETWORK_ERROR_%s" % network_result, "status": 0, "retryable": true}
		return await _retry_or_return(network_failure, method, path, body, authenticated, allow_refresh, idempotency_key, attempt)
	var parsed = JsonUtils.parse_string(response_body.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "error": "INVALID_SERVER_RESPONSE", "status": status_code, "retryable": false}
	if status_code == 401 and authenticated and allow_refresh:
		var refresh_result := await refresh_session()
		if refresh_result.ok:
			return await _request_json(method, path, body, true, false, idempotency_key)
	if status_code < 200 or status_code >= 300:
		var failure := {"ok": false, "error": str(parsed.get("error_code", "HTTP_%s" % status_code)), "status": status_code, "data": parsed, "retryable": status_code in [408, 429] or status_code >= 500}
		return await _retry_or_return(failure, method, path, body, authenticated, allow_refresh, idempotency_key, attempt)
	return {"ok": true, "status": status_code, "data": parsed, "retryable": false}


func _retry_or_return(failure: Dictionary, method: HTTPClient.Method, path: String, body: Dictionary, authenticated: bool, allow_refresh: bool, idempotency_key: String, attempt: int) -> Dictionary:
	var safe_to_retry := method == HTTPClient.METHOD_GET or not idempotency_key.is_empty()
	if not safe_to_retry or not bool(failure.get("retryable", false)) or attempt >= MAX_REQUEST_ATTEMPTS:
		return failure
	var delay := 0.5 if attempt == 1 else 1.5
	delay += randf_range(0.0, 0.25)
	await get_tree().create_timer(delay).timeout
	return await _request_json(method, path, body, authenticated, allow_refresh, idempotency_key, attempt + 1)


func _request_timeout(method: HTTPClient.Method, path: String) -> float:
	if path.begins_with("/v1/sessions/"):
		return AUTH_TIMEOUT_SECONDS
	return GET_TIMEOUT_SECONDS if method == HTTPClient.METHOD_GET else WRITE_TIMEOUT_SECONDS


func _is_invalid_refresh_response(response: Dictionary) -> bool:
	var status := int(response.get("status", 0))
	if status not in [400, 401, 403]:
		return false
	var error := str(response.get("error", "")).to_upper()
	return error in ["INVALID_REFRESH_TOKEN", "REFRESH_TOKEN_INVALID", "REFRESH_TOKEN_EXPIRED", "REFRESH_TOKEN_REVOKED", "REFRESH_TOKEN_NOT_FOUND"]


func _platform_name() -> String:
	match OS.get_name():
		"Android": return "android"
		"iOS": return "ios"
		_: return "desktop"


func new_request_id() -> String:
	var value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20, 12)]


func _configure_base_url() -> void:
	var production_url := str(ProjectSettings.get_setting("oddspot/network/production_base_url", "")).strip_edges()
	# Exported runtimes may inherit environment variables from their host (the
	# WeChat developer tool reports itself as Windows and does this in practice).
	# Local overrides are therefore editor-only; every packaged build uses the
	# endpoint signed into project.godot.
	base_url = resolve_base_url(
		OS.has_feature("editor"),
		OS.get_environment("ODDSPOT_API_BASE_URL"),
		production_url,
	)


static func resolve_base_url(is_editor: bool, environment_url: String, production_url: String) -> String:
	var clean_environment := environment_url.strip_edges().trim_suffix("/")
	if is_editor and not clean_environment.is_empty():
		return clean_environment
	var clean_production := production_url.strip_edges().trim_suffix("/")
	return clean_production if not clean_production.is_empty() else DEFAULT_BASE_URL
