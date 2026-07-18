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
		box.add_child(main._make_label("%s [%s/%s] 비용 %d" % [String(card.get("name", "")), main.ui.card_race_display_name(card), String(card.get("attr", "")), int(card.get("cost", 0))], 14, Color(0.84, 0.88, 0.95, 1.0)))
	box.add_child(HSeparator.new())
	for relic in main.relic_service.relics:
		var relic_row := HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 8)
		box.add_child(relic_row)
		relic_row.add_child(main.ui.make_relic_badge(relic, false))
		var relic_text: Label = main._make_label(String(relic.get("text", "")), 13, Color(0.86, 0.88, 0.94, 1.0))
		relic_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		relic_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		relic_row.add_child(relic_text)
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
