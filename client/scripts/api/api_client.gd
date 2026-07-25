extends Node

const DEFAULT_BASE_URL := "https://oddspot.guaguatu.com"
const DEFAULT_USER_SERVER_URL := "https://api.guaguatu.com"
const USER_SERVER_APP_ID := "game_odd_spot"
const REQUEST_TIMEOUT_SECONDS := 2.0

var base_url := DEFAULT_BASE_URL


func ensure_session() -> Dictionary:
	_configure_base_url()
	if SessionStore.has_access_token():
		return {"ok": true, "data": {}}
	return {"ok": false, "error": "LOGIN_REQUIRED"}


func get_bootstrap() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/v1/bootstrap", {}, true, true)


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


func _exchange_user_token(login_data: Dictionary) -> Dictionary:
	var user_token := str(login_data.get("token", ""))
	if user_token.is_empty():
		return {"ok": false, "error": "USER_TOKEN_MISSING"}
	var response := await _request_json(HTTPClient.METHOD_POST, "/v1/sessions/user-server", {
		"token": user_token,
		"locale": TranslationServer.get_locale(),
	}, false, false)
	if response.ok:
		SessionStore.update_session(response.data.get("data", {}))
		var identity_refresh := str(login_data.get("refresh_token", ""))
		if not identity_refresh.is_empty():
			await _request_user_server("/api/v1/user/logout", {
				"app_id": USER_SERVER_APP_ID,
				"refresh_token": identity_refresh,
			})
	return response


func _request_user_server(path: String, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
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
	var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
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
	else:
		SessionStore.clear_session()
	return response


func logout() -> void:
	if SessionStore.has_access_token() and not SessionStore.refresh_token.is_empty():
		await _request_json(HTTPClient.METHOD_POST, "/v1/sessions/logout", {
			"refresh_token": SessionStore.refresh_token,
		}, true, false)
	SessionStore.clear_session()


func _request_json(method: HTTPClient.Method, path: String, body: Dictionary, authenticated: bool, allow_refresh := false, idempotency_key := "") -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
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
		return {"ok": false, "error": "request could not start (%s)" % start_error}

	var result: Array = await request.request_completed
	request.queue_free()
	var network_result: int = result[0]
	var status_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	if network_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network error (%s)" % network_result, "status": 0}
	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "error": "invalid server response", "status": status_code}
	if status_code == 401 and authenticated and allow_refresh:
		var refresh_result := await refresh_session()
		if refresh_result.ok:
			return await _request_json(method, path, body, true, false, idempotency_key)
	if status_code < 200 or status_code >= 300:
		return {"ok": false, "error": str(parsed.get("error_code", "HTTP_%s" % status_code)), "status": status_code, "data": parsed}
	return {"ok": true, "data": parsed}


func _platform_name() -> String:
	match OS.get_name():
		"Android": return "android"
		"iOS": return "ios"
		_: return "desktop"


func new_request_id() -> String:
	var value := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20, 12)]


func _configure_base_url() -> void:
	var environment_url := OS.get_environment("ODDSPOT_API_BASE_URL").strip_edges()
	if not environment_url.is_empty():
		base_url = environment_url.trim_suffix("/")
		return
	var production_url := str(ProjectSettings.get_setting("oddspot/network/production_base_url", "")).strip_edges()
	if not production_url.is_empty():
		base_url = production_url.trim_suffix("/")
		return
	base_url = DEFAULT_BASE_URL
