extends RefCounted
class_name UiGuideScreen

var main: Node

const GUIDE_PANELS := [
	{
		"number": 1,
		"title": "메인 메뉴",
		"subtitle": "Main Menu",
		"preview": "menu",
		"bullets": [
			"주요 메뉴: 이어하기, 새 런, 카드 컬렉션, 유물, 메타 진행",
			"중앙 영웅: 현재 분위기와 대표 이미지를 강조",
			"현재 런 정보: 진행 중인 런 상태 요약",
			"최근 런 기록: 이전 결과와 빌드 흐름 확인",
			"빌드 통계: 자주 가는 방향을 보여줌",
		],
	},
	{
		"number": 2,
		"title": "맵 화면",
		"subtitle": "Run Map",
		"preview": "map",
		"bullets": [
			"맵 범례: 각 노드 종류와 의미",
			"맵 노드: 이동 가능한 경로와 이벤트 지점",
			"현재 목표: 이번 Act 목표와 다음 노드 정보",
			"현재 빌드: 런의 성장 방향 요약",
			"상태 바: 체력, 골드, 자원 확인",
		],
	},
	{
		"number": 3,
		"title": "카드 보상 화면",
		"subtitle": "Card Reward",
		"preview": "reward",
		"bullets": [
			"현재 빌드 요약: 어떤 방향인지 먼저 보여줌",
			"카드 선택: 보상 후보 중 1장을 선택해 덱에 추가",
			"추천 이유: 빌드 시너지 설명",
			"건너뛰기: 선택하지 않고 다음으로 진행",
		],
	},
	{
		"number": 4,
		"title": "상점 화면",
		"subtitle": "Shop",
		"preview": "shop",
		"bullets": [
			"상품 목록: 구매 가능한 카드, 유물, 소모품",
			"골드: 현재 보유 골드",
			"카드 제거: 덱 압축용 핵심 기능",
			"덱 확인: 현재 덱 구성 확인",
		],
	},
	{
		"number": 5,
		"title": "전투 화면",
		"subtitle": "Battle",
		"preview": "battle",
		"bullets": [
			"적 정보: 적 영웅 체력과 공격력",
			"전장: 적/아군 유닛 배치 공간",
			"전투 로그: 전투 중 발생 이벤트 기록",
			"플레이어 정보: 체력, 빌드, 마나",
			"손패: 현재 사용할 카드",
			"턴 종료: 적 턴으로 진행",
			"영웅 공격: 선택한 유닛으로 적 영웅 공격",
		],
	},
	{
		"number": 6,
		"title": "이벤트 화면",
		"subtitle": "Event",
		"preview": "event",
		"bullets": [
			"이벤트 설명: 상황과 스토리 전달",
			"선택지: 여러 행동 중 하나를 선택",
			"보상 미리보기: 선택 시 얻을 결과 확인",
		],
	},
	{
		"number": 7,
		"title": "휴식 화면",
		"subtitle": "Rest",
		"preview": "rest",
		"bullets": [
			"휴식: 체력 회복",
			"카드 제거 또는 강화: 덱 정비",
			"명상: 장기 자원 강화",
			"떠나기: 다음 노드로 이동",
		],
	},
	{
		"number": 8,
		"title": "런 결과 화면",
		"subtitle": "Run Result",
		"preview": "result",
		"bullets": [
			"결과: 승리/패배 표현",
			"런 정보: 이번 런의 주요 기록",
			"획득 보상: 플레이 보상 요약",
			"다음 행동: 메인 메뉴 또는 새로운 런",
		],
	},
]

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact := _is_guide_compact_layout()
	var panel: PanelContainer = main._make_screen_panel(Color(0.045, 0.05, 0.06, 0.985), 1500 if not compact else 520)
	body.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_row)
	var title: Label = main._make_label("Card Draft UI 설계 가이드", 22 if compact else 24, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(0, 30)
	title_row.add_child(title)
	var subtitle: Label = main._make_label("주요 화면 구성과 역할 설명", 13 if compact else 14, Color(0.74, 0.78, 0.84, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(subtitle)

	var guide_summary: Label = main._make_label("플레이어가 지금 무엇을 해야 하는지, 이번 런이 어떤 빌드로 성장하는지, 왜 그 선택이 맞는지를 한 장에서 설명합니다.", 11 if compact else 12, Color(0.82, 0.86, 0.9, 1.0))
	guide_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(guide_summary)

	var divider := ColorRect.new()
	divider.color = Color(0.28, 0.22, 0.12, 0.7)
	divider.custom_minimum_size = Vector2(0, 1)
	box.add_child(divider)

	var grid := GridContainer.new()
	var viewport_width: float = main._layout_viewport_size().x
	if compact:
		grid.columns = 1
	elif viewport_width >= 1440.0:
		grid.columns = 4
	elif viewport_width >= 980.0:
		grid.columns = 3
	else:
		grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)

	for panel_data in GUIDE_PANELS:
		grid.add_child(_make_guide_panel(panel_data, compact))

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "메인 메뉴", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _make_guide_panel(panel_data: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.05, 0.06, 0.075, 0.98), Color(0.24, 0.2, 0.12, 1.0), 1, 10, 10)
	panel.custom_minimum_size = Vector2(0, 300 if compact else 252)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(_make_tiny_chip(str(panel_data.get("number", 0)), Color(0.52, 0.26, 0.72, 1.0), Color(1.0, 0.95, 0.98, 1.0), 12 if compact else 13, 30))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)
	var title: Label = main._make_label("%s (%s)" % [String(panel_data.get("title", "")), String(panel_data.get("subtitle", ""))], 12 if compact else 13, Color(0.96, 0.97, 0.94, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_box.add_child(title)

	box.add_child(_make_preview(String(panel_data.get("preview", "")), compact))

	for idx in range((panel_data.get("bullets", []) as Array).size()):
		var bullet_text := String((panel_data.get("bullets", []) as Array)[idx])
		box.add_child(_make_bullet_row(idx + 1, bullet_text, compact))
	return panel

func _make_bullet_row(number: int, text: String, compact: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip: PanelContainer = _make_tiny_chip(str(number), Color(0.3, 0.22, 0.56, 1.0), Color(1.0, 0.94, 1.0, 1.0), 9 if compact else 10, 22)
	chip.custom_minimum_size = Vector2(22, 18)
	row.add_child(chip)
	var label: Label = main._make_label(text, 9 if compact else 10, Color(0.82, 0.86, 0.92, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

func _make_preview(kind: String, compact: bool) -> Control:
	match kind:
		"menu":
			return _make_menu_preview(compact)
		"map":
			return _make_map_preview(compact)
		"reward":
			return _make_reward_preview(compact)
		"shop":
			return _make_shop_preview(compact)
		"battle":
			return _make_battle_preview(compact)
		"event":
			return _make_event_preview(compact)
		"rest":
			return _make_rest_preview(compact)
		"result":
			return _make_result_preview(compact)
	return main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 1.0), Color(0.24, 0.2, 0.12, 1.0), 1, 8, 6)

func _make_menu_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_menu_button_stack(["계속하기", "새로운 런", "카드 컬렉션", "유물", "메타 진행"], compact))
	row.add_child(_make_preview_art_panel(8, compact))
	row.add_child(_make_summary_stack(["현재 런 정보", "최근 런 기록", "빌드 통계"], compact))
	return _wrap_preview(row)

func _make_map_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_summary_stack(["전투", "엘리트", "이벤트", "상점", "휴식", "보스"], compact))
	row.add_child(_make_map_canvas_mock(compact))
	row.add_child(_make_summary_stack(["현재 목표", "다음 보상", "현재 빌드"], compact))
	return _wrap_preview(row)

func _make_reward_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_summary_stack(["현재 빌드"], compact))
	var cards: Control = VBoxContainer.new() if compact else HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cards)
	for art_index in [1, 4, 5]:
		cards.add_child(_make_card_preview_mock(art_index, "추천 카드" if art_index == 1 else "", compact))
	row.add_child(_make_summary_stack(["추천 이유", "건너뛰기"], compact))
	return _wrap_preview(row)

func _make_shop_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	var products: Control = VBoxContainer.new() if compact else HBoxContainer.new()
	products.add_theme_constant_override("separation", 8)
	products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(products)
	for art_index in [4, 0, 9, 6]:
		products.add_child(_make_card_preview_mock(art_index, "골드 90" if art_index == 4 else "", compact))
	row.add_child(_make_summary_stack(["카드 제거", "덱 확인"], compact))
	return _wrap_preview(row)

func _make_battle_preview(compact: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 92 if compact else 84)
	box.add_theme_constant_override("separation", 8)
	box.add_child(_make_tiny_chip("현재 목표: 적 영웅 체력을 0으로 만드세요.", Color(0.12, 0.14, 0.18, 1.0), Color(0.94, 0.96, 0.9, 1.0), 10 if compact else 11, 20))
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_make_summary_stack(["적 영웅", "HP 20/24", "공격력 4"], compact))
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 6)
	row.add_child(field)
	field.add_child(_make_unit_row([2, 2, 2, 2, 2], true, compact))
	field.add_child(_make_unit_row([8, 1, 8, 8, 8], false, compact))
	row.add_child(_make_summary_stack(["전투 로그", "턴 종료"], compact))
	var footer: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	footer.add_child(_make_tiny_chip("플레이어 49/50", Color(0.22, 0.12, 0.14, 1.0), Color(1.0, 0.88, 0.88, 1.0), 9 if compact else 10, 20))
	footer.add_child(_make_tiny_chip("마나 3/3", Color(0.08, 0.18, 0.32, 1.0), Color(0.88, 0.94, 1.0, 1.0), 9 if compact else 10, 20))
	footer.add_child(_make_tiny_chip("손패 5장", Color(0.18, 0.18, 0.1, 1.0), Color(1.0, 0.92, 0.72, 1.0), 9 if compact else 10, 20))
	return _wrap_preview(box)

func _make_event_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	var story := VBoxContainer.new()
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_theme_constant_override("separation", 6)
	row.add_child(story)
	story.add_child(_make_tiny_chip("여행 중 이상한 상인을 만났습니다.", Color(0.16, 0.12, 0.08, 1.0), Color(1.0, 0.92, 0.76, 1.0), 9 if compact else 10, 20))
	story.add_child(main._make_art_rect(9, Vector2(86 if compact else 96, 48 if compact else 54)))
	story.add_child(_make_tiny_chip("특별한 물건을 가져왔지.", Color(0.12, 0.16, 0.12, 1.0), Color(0.88, 0.94, 0.88, 1.0), 9 if compact else 10, 20))
	row.add_child(_make_summary_stack(["보상 미리보기", "업그레이드", "유물 획득"], compact))
	return _wrap_preview(row)

func _make_rest_preview(compact: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 92 if compact else 84)
	box.add_theme_constant_override("separation", 8)
	box.add_child(_make_tiny_chip("캠프에 도착했습니다. 어떤 행동을 하시겠습니까?", Color(0.12, 0.14, 0.18, 1.0), Color(0.94, 0.96, 0.9, 1.0), 9 if compact else 10, 20))
	box.add_child(main._make_art_rect(11, Vector2(100 if compact else 112, 38 if compact else 44)))
	var actions: Control = VBoxContainer.new() if compact else HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	actions.add_child(_make_action_card("휴식", "체력 20 회복", compact))
	actions.add_child(_make_action_card("카드 제거", "덱 압축", compact))
	actions.add_child(_make_action_card("명상", "최대 체력 +5", compact))
	return _wrap_preview(box)

func _make_result_preview(compact: bool) -> Control:
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92 if compact else 84)
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_preview_art_panel(8, compact, "승리!"))
	row.add_child(_make_summary_stack(["런 정보", "플레이 시간", "처치한 적", "획득 보상"], compact))
	return _wrap_preview(row)

func _wrap_preview(content: Control) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 8, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	return panel

func _make_menu_button_stack(texts: Array, compact: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(88 if compact else 104, 0)
	box.add_theme_constant_override("separation", 6)
	for text_value in texts:
		box.add_child(_make_tiny_chip(String(text_value), Color(0.12, 0.14, 0.18, 1.0), Color(0.94, 0.96, 0.9, 1.0), 8 if compact else 9, 18))
	return box

func _make_preview_art_panel(art_index: int, compact: bool, title: String = "") -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	if not title.is_empty():
		var title_label: Label = main._make_label(title, 12 if compact else 13, Color(1.0, 0.88, 0.55, 1.0))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title_label)
	box.add_child(main._make_art_rect(art_index, Vector2(62 if compact else 70, 54 if compact else 60)))
	return box

func _make_summary_stack(lines: Array, compact: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(64 if compact else 72, 0)
	box.add_theme_constant_override("separation", 4)
	for line in lines:
		box.add_child(_make_tiny_chip(String(line), Color(0.12, 0.14, 0.18, 1.0), Color(0.88, 0.92, 0.98, 1.0), 8 if compact else 9, 18))
	return box

func _make_map_canvas_mock(compact: bool) -> Control:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.06, 0.07, 0.08, 1.0), Color(0.18, 0.22, 0.16, 1.0), 1, 8, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(72 if compact else 84, 54 if compact else 58)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	content.add_child(top)
	for text_value in ["전투", "?", "상점"]:
		top.add_child(_make_tiny_chip(String(text_value), Color(0.16, 0.16, 0.1, 1.0), Color(1.0, 0.92, 0.72, 1.0), 8 if compact else 9, 16))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	content.add_child(bottom)
	for text_value in ["엘리트", "휴식", "보스"]:
		bottom.add_child(_make_tiny_chip(String(text_value), Color(0.12, 0.16, 0.24, 1.0), Color(0.88, 0.94, 1.0, 1.0), 8 if compact else 9, 16))
	return panel

func _make_card_preview_mock(art_index: int, title: String, compact: bool) -> Control:
	var frame: PanelContainer = main.ui.make_surface_panel(Color(0.09, 0.1, 0.11, 1.0), Color(0.56, 0.42, 0.16, 1.0), 2, 8, 6)
	frame.custom_minimum_size = Vector2(40 if compact else 44, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	if not title.is_empty():
		box.add_child(_make_tiny_chip(title, Color(0.28, 0.2, 0.08, 1.0), Color(1.0, 0.92, 0.72, 1.0), 7 if compact else 8, 16))
	box.add_child(main._make_art_rect(art_index, Vector2(32 if compact else 34, 36 if compact else 38)))
	box.add_child(_make_tiny_chip("효과", Color(0.12, 0.14, 0.18, 1.0), Color(0.9, 0.94, 1.0, 1.0), 7 if compact else 8, 16))
	return frame

func _make_unit_row(arts: Array, enemy_row: bool, compact: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for art_value in arts:
		var frame: PanelContainer = main.ui.make_surface_panel(
			Color(0.14, 0.12, 0.12, 1.0) if enemy_row else Color(0.12, 0.14, 0.16, 1.0),
			Color(0.36, 0.18, 0.16, 1.0) if enemy_row else Color(0.18, 0.28, 0.36, 1.0),
			1,
			6,
			4
		)
		frame.custom_minimum_size = Vector2(18 if compact else 20, 26 if compact else 28)
		frame.add_child(main._make_art_rect(int(art_value), Vector2(12 if compact else 14, 14 if compact else 16)))
		row.add_child(frame)
	return row

func _make_action_card(title: String, subtitle: String, compact: bool) -> Control:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.1, 0.1, 0.08, 1.0), Color(0.32, 0.24, 0.12, 1.0), 1, 8, 6)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_label: Label = main._make_label(title, 10 if compact else 11, Color(1.0, 0.88, 0.55, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var sub_label: Label = main._make_label(subtitle, 8 if compact else 9, Color(0.86, 0.9, 0.96, 1.0))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub_label)
	return panel

func _make_tiny_chip(text: String, bg_color: Color, text_color: Color, font_size: int, min_height: int) -> PanelContainer:
	var chip: PanelContainer = main.ui.make_surface_panel(bg_color, bg_color.lightened(0.16), 1, 6, 6)
	chip.custom_minimum_size = Vector2(0, min_height)
	var label: Label = main._make_label(text, font_size, text_color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(label)
	return chip

func _is_guide_compact_layout() -> bool:
	return main._is_compact_layout_for(1180.0, 980.0)
