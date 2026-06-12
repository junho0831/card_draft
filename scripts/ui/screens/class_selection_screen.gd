extends RefCounted
class_name ClassSelectionScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact: bool = main._is_compact_layout_for(980.0)
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760 if not compact else 420)
	body.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	panel.add_child(list)

	list.add_child(main._make_label("당신의 출신을 선택하세요. 각 종족별로 다른 기본 덱과 유물을 지급받습니다.", 14, Color(0.8, 0.85, 0.9, 1.0)))

	var grid: BoxContainer
	if compact:
		grid = VBoxContainer.new()
	else:
		grid = HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 20)
	list.add_child(grid)

	var classes = [
		{
			"id": "human",
			"name": "인간 기사",
			"color": Color(0.28, 0.38, 0.54, 1.0),
			"desc": "기본 유물: 기사단 깃발\n아군 유닛이 소환될 때 공격력이 +1 증가합니다.\n\n다양한 검술 카드와 방어 카드로 균형잡힌 전투를 지향합니다.",
			"art": 7
		},
		{
			"id": "elf",
			"name": "엘프 순찰자",
			"color": Color(0.25, 0.45, 0.25, 1.0),
			"desc": "기본 유물: 세계수 잎\n매 턴 시작 시 카드를 1장 더 뽑습니다.\n\n민첩한 콤보와 자연의 힘(의식)을 활용해 적을 제압합니다.",
			"art": 9
		},
		{
			"id": "undead",
			"name": "언데드 사령술사",
			"color": Color(0.4, 0.2, 0.4, 1.0),
			"desc": "기본 유물: 사령술사의 반지\n전투마다 처음 사망한 아군을 1/1 해골로 되살립니다.\n\n아군의 희생과 저주 카드를 활용해 상대를 좀먹습니다.",
			"art": 11
		}
	]

	for cls in classes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(220, 260) if not compact else Vector2(0, 180)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.ui.style_button(btn, cls.color)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		var art = main.ui.make_art_rect(cls.art, Vector2(96, 96))
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(art)
		
		var title = main._make_label(cls.name, 20, Color(1, 0.95, 0.8))
		title.add_theme_constant_override("outline_size", 2)
		title.add_theme_color_override("font_outline_color", Color(0,0,0))
		vbox.add_child(title)
		
		var desc = main._make_label(cls.desc, 12, Color(0.9, 0.9, 0.9))
		desc.custom_minimum_size = Vector2(200, 0)
		vbox.add_child(desc)

		btn.pressed.connect(Callable(main, "_init_run").bind(cls.id))
		grid.add_child(btn)

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "돌아가기", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
