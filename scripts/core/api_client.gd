extends Node
class_name ApiClient

const DEFAULT_BASE_URL := "http://127.0.0.1:8080"

var base_url := DEFAULT_BASE_URL
var user_id := ""
var timeout_seconds := 2.0

func configure(new_base_url: String, new_user_id: String = "") -> void:
	base_url = new_base_url.trim_suffix("/")
	user_id = new_user_id

func set_user_id(new_user_id: String) -> void:
	user_id = new_user_id

func guest_login(player_name: String) -> Dictionary:
	return await _request("/api/guest-login", HTTPClient.METHOD_POST, {
		"playerName": player_name,
	}, false)

func fetch_cards() -> Dictionary:
	return await _request("/api/cards", HTTPClient.METHOD_GET, {}, false)

func fetch_profile() -> Dictionary:
	return await _request("/api/profile", HTTPClient.METHOD_GET, {}, true)

func fetch_collection() -> Dictionary:
	return await _request("/api/collection", HTTPClient.METHOD_GET, {}, true)

func fetch_decks() -> Dictionary:
	return await _request("/api/decks", HTTPClient.METHOD_GET, {}, true)

func create_deck(name: String, card_ids: Array) -> Dictionary:
	return await _request("/api/decks", HTTPClient.METHOD_POST, {
		"name": name,
		"cardIds": card_ids,
	}, true)

func update_deck(deck_id: String, name: String, card_ids: Array) -> Dictionary:
	return await _request("/api/decks/%s" % deck_id, HTTPClient.METHOD_PUT, {
		"name": name,
		"cardIds": card_ids,
	}, true)

func select_deck(deck_id: String) -> Dictionary:
	return await _request("/api/decks/%s/select" % deck_id, HTTPClient.METHOD_POST, {}, true)

func create_ai_match(mode: String, deck_id: String) -> Dictionary:
	return await _request("/api/matches/ai", HTTPClient.METHOD_POST, {
		"mode": mode,
		"deckId": deck_id,
	}, true)

func submit_match_result(match_id: String, result: String) -> Dictionary:
	return await _request("/api/matches/%s/result" % match_id, HTTPClient.METHOD_POST, {
		"result": result,
	}, true)

func fetch_shop_products() -> Dictionary:
	return await _request("/api/shop/products", HTTPClient.METHOD_GET, {}, true)

func buy_shop_product(product_id: String, race_filter: String = "") -> Dictionary:
	return await _request("/api/shop/purchase", HTTPClient.METHOD_POST, {
		"productId": product_id,
		"raceFilter": race_filter,
	}, true)

func _request(path: String, method: HTTPClient.Method, body: Dictionary, include_user: bool) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
	add_child(request)

	var headers := ["Content-Type: application/json"]
	if include_user:
		if user_id.is_empty():
			request.queue_free()
			return {"ok": false, "status": 0, "body": {}, "error": "서버 유저 ID가 없습니다."}
		headers.append("X-User-Id: %s" % user_id)

	var body_text := ""
	if method != HTTPClient.METHOD_GET:
		body_text = JSON.stringify(body)

	var err := request.request("%s%s" % [base_url, path], headers, method, body_text)
	if err != OK:
		request.queue_free()
		return {"ok": false, "status": 0, "body": {}, "error": "HTTP 요청 생성 실패"}

	var response: Array = await request.request_completed
	request.queue_free()
	var result_code: int = response[0]
	var http_status: int = response[1]
	var raw_body: PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": http_status, "body": {}, "error": "서버 연결 실패"}

	var text := raw_body.get_string_from_utf8()
	var parsed: Variant = {}
	if not text.is_empty():
		parsed = JSON.parse_string(text)
		if parsed == null:
			parsed = {"raw": text}

	return {
		"ok": http_status >= 200 and http_status < 300,
		"status": http_status,
		"body": parsed,
		"error": _error_message(parsed),
	}

func _error_message(parsed: Variant) -> String:
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		return String(parsed["error"])
	return ""
