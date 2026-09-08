extends RefCounted

static func stage(run: Dictionary) -> int:
	if not bool(run.get("guided_run", false)) or int(run.get("act", 1)) > 1:
		return 5
	return maxi(int(run.get("lesson_resume_stage", 0)), int(run.get("current_node_index", 0)))

static func description(run: Dictionary) -> String:
	if int(run.get("current_node_index", 0)) < int(run.get("lesson_resume_stage", 0)):
		return ""
	match stage(run):
		0: return "1/5 소환과 공격 · 카드를 소환하고 선봉을 처치한 뒤 영웅을 공격하세요. 유닛끼리는 서로 피해를 줍니다."
		1: return "2/5 장비 고르기 · 장비는 아군 한 명을 강화합니다. 다음 전투에서 직접 대상을 골라보세요."
		2: return "3/5 장비와 2연계 · 장비를 누른 뒤 아군을 고르세요. 같은 연계 표시의 카드를 이어 쓰면 보너스가 생깁니다."
		3: return "4/5 휴식과 성장 · 체력이 부족하면 회복하고, 여유가 있으면 자주 쓰는 카드를 강화하세요."
		4: return "5/5 첫 보스 · 적의 예고를 읽고 필살기를 써보세요. 같은 연계를 세 번 이으면 전투당 한 번 피니시가 발동합니다."
	return ""

static func equipment_choices() -> Array[String]:
	return ["training_sword", "wind_quiver", "bone_armor"]

static func first_battle(run: Dictionary) -> bool:
	return bool(run.get("guided_run", false)) and int(run.get("act", 1)) == 1 and int(run.get("current_node_index", 0)) == 0
