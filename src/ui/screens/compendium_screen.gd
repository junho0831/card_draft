extends RefCounted
class_name CompendiumScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(main._make_label("현재 카드 %d종 / 유물 %d개" % [main.card_defs.size(), main.relic_service.relics.size()], 16, Color(0.92, 0.94, 0.98, 1.0)))
	for card in main.card_defs:
		box.add_child(main._make_label("%s [%s/%s] 비용 %d" % [String(card.get("name", "")), String(card.get("race", "")), String(card.get("attr", "")), int(card.get("cost", 0))], 14, Color(0.84, 0.88, 0.95, 1.0)))
	box.add_child(HSeparator.new())
	for relic in main.relic_service.relics:
		box.add_child(main._make_label("%s - %s" % [String(relic.get("name", "")), String(relic.get("text", ""))], 14, Color(1.0, 0.88, 0.55, 1.0)))
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
