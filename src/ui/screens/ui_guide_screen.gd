extends RefCounted
class_name UiGuideScreen
const Layout = preload("res://src/ui/screens/screen_layout.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	Layout.back(main, body)
	var title: Label = main.ui.make_label("원정 안내", 24, Tokens.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(title)
	for entry in [
		["원정", "세력과 시작 전략을 정하고 경로를 선택합니다. 보스에게 승리하면 원정이 끝납니다."],
		["전투", "마나를 사용해 카드를 내고 아군 유닛으로 공격합니다. 적 영웅의 체력이 0이 되면 승리합니다."],
		["카드와 덱", "전투 보상에서 카드 한 장을 선택할 수 있습니다. 상점과 이벤트에서는 덱의 카드를 제거할 수 있습니다."],
		["휴식", "휴식은 체력을 회복하고 명상은 카드 한 장을 강화합니다. 둘 중 한 행동을 선택하거나 떠날 수 있습니다."],
		["이벤트", "선택에 따라 체력, 골드, 카드, 유물이 달라집니다. 각 선택에 표시된 비용과 보상을 확인하세요."],
		["성장", "원정에서 얻은 영혼석으로 시작 체력, 시작 골드와 두 번째 기회를 강화합니다."]
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		body.add_child(row)
		var section: Label = main.ui.make_label(entry[0], 16, Tokens.ACCENT_GOLD)
		section.custom_minimum_size.x = 110
		section.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(section)
		var detail := Layout.label(main, entry[1])
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		body.add_child(HSeparator.new())
