extends RefCounted
class_name RewardService

func apply_reward(profile: Dictionary, mode: String, battle_result: String, card_defs: Array) -> Dictionary:
	var gold_delta := 0
	var rank_delta := 0
	var card_reward := ""
	var did_win := battle_result == "win"
	if mode == "ranked":
		if did_win:
			gold_delta = 20
			rank_delta = 25
			card_reward = grant_random_card(profile, card_defs)
		else:
			gold_delta = 10
			rank_delta = -10
	else:
		if did_win:
			gold_delta = 30
			card_reward = grant_random_card(profile, card_defs)
		else:
			gold_delta = 10

	profile["gold"] = int(profile["gold"]) + gold_delta
	profile["rank_points"] = max(0, int(profile["rank_points"]) + rank_delta)

	var result_text := "패배"
	if did_win:
		result_text = "승리"
	var summary := "%s %s\n골드 +%d\n" % [mode_name(mode), result_text, gold_delta]
	if mode == "ranked":
		var rank_delta_text := "%d" % rank_delta
		if rank_delta >= 0:
			rank_delta_text = "+%d" % rank_delta
		summary += "랭크 점수 %s\n" % rank_delta_text
	if not card_reward.is_empty():
		summary += "카드 획득: %s\n" % card_reward
	return {
		"profile": profile,
		"summary": summary,
	}

func grant_random_card(profile: Dictionary, card_defs: Array) -> String:
	if card_defs.is_empty():
		return ""
	var card: Dictionary = card_defs[randi() % card_defs.size()]
	var id := String(card["id"])
	profile["owned_cards"][id] = int(profile["owned_cards"].get(id, 0)) + 1
	return String(card["name"])

func rank_name(points: int) -> String:
	if points >= 2000:
		return "다이아"
	if points >= 1500:
		return "플래티넘"
	if points >= 1000:
		return "골드"
	if points >= 500:
		return "실버"
	return "브론즈"

func mode_name(mode: String) -> String:
	if mode == "ranked":
		return "랭크전"
	return "일반전"
