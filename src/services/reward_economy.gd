extends RefCounted

static func base_id(card_id: String) -> String:
	return card_id.trim_suffix("_plus")

static func available(pool: Array, picked: Array, history: Array = []) -> Array[String]:
	var used := {}
	for id in picked:
		used[base_id(String(id))] = true
	var recent := {}
	for batch in history.slice(maxi(0, history.size() - 2)):
		for id in batch:
			recent[base_id(String(id))] = true
	var all: Array[String] = []
	var fresh: Array[String] = []
	for raw_id in pool:
		var id := String(raw_id)
		var base := base_id(id)
		if used.has(base):
			continue
		used[base] = true
		all.append(id)
		if not recent.has(base):
			fresh.append(id)
	return fresh if not fresh.is_empty() else all

static func record_pending(run_data: Dictionary) -> void:
	var reward: Dictionary = run_data.get("pending_card_reward", {})
	if reward.is_empty() or bool(reward.get("offer_history_recorded", false)):
		return
	reward["offer_history_recorded"] = true
	if bool(reward.get("lesson_equipment", false)):
		return
	var batch: Array[String] = []
	for id in reward.get("choices", []):
		var base := base_id(String(id))
		if not batch.has(base):
			batch.append(base)
	if batch.is_empty():
		return
	var history: Array = run_data.get("reward_offer_history", []).duplicate(true)
	history.append(batch)
	run_data["reward_offer_history"] = history.slice(maxi(0, history.size() - 2))

static func cost_buckets(deck: Array, get_card: Callable) -> Dictionary:
	var counts := {"0-1": 0, "2-3": 0, "4+": 0}
	for id in deck:
		var card: Dictionary = get_card.call(String(id))
		if not card.is_empty():
			var bucket := cost_bucket(int(card.get("cost", 0)))
			counts[bucket] += 1
	return counts

static func cost_bucket(cost: int) -> String:
	return "0-1" if cost <= 1 else ("2-3" if cost <= 3 else "4+")
