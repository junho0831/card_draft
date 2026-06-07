extends RefCounted
class_name ProfileStore

const LOCAL_DEBUG_GOLD := 999999999999999999
const LOCAL_DEBUG_CARD_COPIES := 3

func load_or_create(path: String, card_defs: Array, deck_service, deck_size: int, max_copies: int) -> Dictionary:
	var profile := {}
	var loaded := false
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		if not text.strip_edges().is_empty():
			var json := JSON.new()
			if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
				profile = json.data
				loaded = true
	if not loaded:
		profile = make_default_profile(card_defs, deck_size)
	profile = normalize(profile, card_defs, deck_service, deck_size, max_copies)
	save(path, profile)
	return profile

func make_default_profile(card_defs: Array, deck_size: int) -> Dictionary:
	var owned := {}
	var deck: Array = []
	for i in range(card_defs.size()):
		var card: Dictionary = card_defs[i]
		var count := 2
		if i < 6:
			count = 3
		owned[String(card["id"])] = count
		for j in range(count):
			if deck.size() < deck_size:
				deck.append(String(card["id"]))
	return {
		"player_name": "플레이어",
		"gold": LOCAL_DEBUG_GOLD,
		"rank_points": 0,
		"soul_stones": 0,
		"owned_cards": owned,
		"selected_deck": deck,
		"unlocked_cards": [],
		"unlocked_relics": [],
		"upgrades": {
			"start_hp": 0,
			"start_gold": 0,
			"second_chance": 0,
		},
		"settings": {
			"battle_cutscene": true,
			"fast_ai": false,
		},
	}

func normalize(profile: Dictionary, card_defs: Array, deck_service, deck_size: int, max_copies: int) -> Dictionary:
	if not profile.has("player_name"):
		profile["player_name"] = "플레이어"
	if not profile.has("gold"):
		profile["gold"] = LOCAL_DEBUG_GOLD
	if not profile.has("rank_points"):
		profile["rank_points"] = 0
	if not profile.has("soul_stones"):
		profile["soul_stones"] = 0
	if not profile.has("owned_cards") or typeof(profile["owned_cards"]) != TYPE_DICTIONARY:
		profile["owned_cards"] = {}
	if not profile.has("selected_deck") or typeof(profile["selected_deck"]) != TYPE_ARRAY:
		profile["selected_deck"] = []
	if not profile.has("unlocked_cards") or typeof(profile["unlocked_cards"]) != TYPE_ARRAY:
		profile["unlocked_cards"] = []
	if not profile.has("unlocked_relics") or typeof(profile["unlocked_relics"]) != TYPE_ARRAY:
		profile["unlocked_relics"] = []
	if not profile.has("upgrades") or typeof(profile["upgrades"]) != TYPE_DICTIONARY:
		profile["upgrades"] = {}
	if not profile.has("settings") or typeof(profile["settings"]) != TYPE_DICTIONARY:
		profile["settings"] = {}
	if not profile["upgrades"].has("start_hp"):
		profile["upgrades"]["start_hp"] = 0
	if not profile["upgrades"].has("start_gold"):
		profile["upgrades"]["start_gold"] = 0
	if not profile["upgrades"].has("second_chance"):
		profile["upgrades"]["second_chance"] = 0
	if not profile["settings"].has("battle_cutscene"):
		profile["settings"]["battle_cutscene"] = true
	if not profile["settings"].has("fast_ai"):
		profile["settings"]["fast_ai"] = false

	var cards_by_id := {}
	var index := 0
	for card in card_defs:
		var id := String(card["id"])
		cards_by_id[id] = card
		if not profile["owned_cards"].has(id):
			profile["owned_cards"][id] = 3 if index < 6 else 2
		index += 1
	if not deck_service.is_deck_valid(profile["selected_deck"], cards_by_id, profile["owned_cards"], deck_size, max_copies):
		profile["selected_deck"] = deck_service.make_owned_starter_deck(card_defs, profile["owned_cards"], deck_size, max_copies)
	return profile

func apply_local_debug_defaults(profile: Dictionary, card_defs: Array = []) -> Dictionary:
	profile["gold"] = max(int(profile.get("gold", 0)), LOCAL_DEBUG_GOLD)
	if not profile.has("owned_cards") or typeof(profile["owned_cards"]) != TYPE_DICTIONARY:
		profile["owned_cards"] = {}
	for card in card_defs:
		var id := String(card.get("id", ""))
		if id.is_empty():
			continue
		profile["owned_cards"][id] = max(int(profile["owned_cards"].get(id, 0)), LOCAL_DEBUG_CARD_COPIES)
	return profile

func save(path: String, profile: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("프로필 저장 실패: %s" % path)
		return
	file.store_string(JSON.stringify(profile, "\t"))
