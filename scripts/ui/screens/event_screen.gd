extends RefCounted
class_name EventScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var event_data: Dictionary = main.current_run.get("pending_event", {})
	body.add_child(main._make_run_summary_panel())
	var panel := main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 640)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(main._make_label(String(event_data.get("title", "")), 24, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label(String(event_data.get("description", "")), 16, Color(0.9, 0.92, 0.98, 1.0)))
	for option in event_data.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var button := main._add_menu_button(box, String(option.get("label", "")), "_noop", Color(0.22, 0.31, 0.38, 1.0))
		button.pressed.connect(Callable(self, "_resolve_event_option").bind(String(option.get("effect", ""))))

func _resolve_event_option(effect: String) -> void:
	var result: Dictionary = main.event_run_service.resolve_effect(main.current_run, effect, {
		"roll_high_cost_cards": Callable(main, "_roll_high_cost_cards"),
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"roll_card_choice_filtered": Callable(main, "_roll_card_choice_filtered"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"apply_relic": Callable(main.relic_service, "apply_on_acquire"),
		"card_name": Callable(self, "_card_name"),
	})
	match String(result.get("action", "")):
		"show_card_reward":
			main._save_run()
			main.run_flow.show_card_reward()
		"show_event":
			main._show_message(String(result.get("message", "")), "show_event", main.run_flow)
		"persisted_message":
			_show_persisted_message(String(result.get("message", "")), String(result.get("callback_method", "complete_event_and_return")))
		"show_remove_card":
			main._show_remove_card_screen(String(result.get("reason", "이벤트")), String(result.get("source", "event_complete")))
		"show_upgrade_card":
			main._show_upgrade_card_screen(String(result.get("source", "event_complete_upgrade")))
		"complete_event":
			main.run_flow.complete_event_and_return()
		_:
			main.run_flow.complete_event_and_return()

func _card_name(card_id: String) -> String:
	var card: Dictionary = main.card_db.get_card(card_id)
	if card.is_empty():
		return card_id
	return String(card.get("name", ""))

func _show_persisted_message(message: String, callback_method: String) -> void:
	main.current_run["pending_event"] = {}
	main.current_run["pending_message"] = {
		"target": "event",
		"message": message,
		"callback_method": callback_method,
	}
	main._save_run()
	main._show_message(message, callback_method, main.run_flow)
