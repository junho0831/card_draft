extends RefCounted
class_name CompendiumScreen

const Fantasy = preload("res://src/ui/fantasy_components.gd")
const Presentation = preload("res://src/ui/components/battle_presentation.gd")
var main: Node
var grid: GridContainer
var counter: Label
var race_filter: OptionButton
var type_filter: OptionButton
var search: LineEdit
var detail_overlay: Control
const RACES := ["전체 세력", "인간", "엘프", "언데드", "중립"]
const TYPES := ["전체 종류", "unit", "spell", "equipment"]

func _init(value: Node) -> void:
	main = value

func build(body: VBoxContainer) -> void:
	counter = main._make_label("", 18, Color(1, 0.88, 0.6))
	body.add_child(counter)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	body.add_child(filters)
	race_filter = OptionButton.new()
	for race in RACES:
		race_filter.add_item("공용" if race == "중립" else race)
	type_filter = OptionButton.new()
	for text in ["전체 종류", "유닛", "주문", "장비"]:
		type_filter.add_item(text)
	for option in [race_filter, type_filter]:
		option.custom_minimum_size.y = 44
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.item_selected.connect(func(_index): _refresh_grid())
		filters.add_child(option)
	search = LineEdit.new()
	search.placeholder_text = "카드 이름 또는 효과 검색"
	search.custom_minimum_size.y = 44
	search.text_changed.connect(func(_text): _refresh_grid())
	body.add_child(search)
	grid = GridContainer.new()
	var card_width := 154 if main._layout_viewport_size().x < 600 else 208
	grid.columns = clampi(floori((main._layout_viewport_size().x - 38) / float(card_width + 10)), 1, 4)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	_refresh_grid()
	var relics := VBoxContainer.new()
	relics.visible = false
	var toggle := Button.new()
	toggle.text = "유물 %d개 펼쳐보기" % main.relic_service.relics.size()
	toggle.custom_minimum_size.y = 44
	toggle.pressed.connect(func(): relics.visible = not relics.visible)
	body.add_child(toggle)
	body.add_child(relics)
	for relic in main.relic_service.relics:
		relics.add_child(main._make_label("%s · %s" % [relic.get("name", ""), relic.get("text", "")], 14, Color(0.86, 0.88, 0.94)))
	main._add_menu_button(body, "메인으로", "_show_main_menu", Color(0.16, 0.2, 0.28))

func _refresh_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var query := search.text.strip_edges().to_lower()
	for card in main.card_defs:
		if race_filter.selected > 0 and card.get("race", "") != RACES[race_filter.selected]:
			continue
		if type_filter.selected > 0 and card.get("type", "") != TYPES[type_filter.selected]:
			continue
		if not query.is_empty() and not (String(card.get("name", "")) + " " + String(card.get("text", ""))).to_lower().contains(query):
			continue
		var face := Fantasy.card(main, card, 154 if main._layout_viewport_size().x < 600 else 208, 258)
		grid.add_child(face)
		Fantasy.clickable_card(face, _show_detail.bind(card))
	counter.text = "카드 도감 · %d / %d종" % [grid.get_child_count(), main.card_defs.size()]

func _show_detail(card: Dictionary) -> void:
	_close_detail()
	var content := VBoxContainer.new()
	main.modal_layer.add_child(content)
	var viewer := preload("res://src/ui/components/card_inspection_view.gd").new()
	var face := Fantasy.card(main, card, 270, 420)
	face.theme = main.theme
	viewer.setup(face, Vector2(300, 470), Vector2(270, 420))
	content.add_child(viewer)
	var lore: Dictionary = main.card_lore_service.lore_for(String(card.get("id", "")))
	content.add_child(main._make_label(String(lore.get("story", "")), 15, Color(0.86, 0.9, 0.96)))
	detail_overlay = Presentation.make_detail_overlay(main.modal_layer, content, _close_detail)
	var close_button := detail_overlay.find_children("*", "Button", true, false)
	if not close_button.is_empty():
		close_button[0].text = "도감으로 돌아가기"
	detail_overlay.visible = true

func _close_detail() -> void:
	if is_instance_valid(detail_overlay):
		detail_overlay.queue_free()
	detail_overlay = null
