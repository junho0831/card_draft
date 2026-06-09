import re

with open("scripts/ui/screens/battle_screen.gd", "r") as f:
    code = f.read()

# Replace local function calls that aren't in battle_screen.gd
# Battle functions inside battle_screen.gd are:
battle_funcs = [
    "_prepare_battle", "_new_side", "_build_battle_ui",
    "_start_turn", "_on_turn_timeout", "_check_auto_end_turn",
    "_draw_cards", "_on_hand_card_pressed", "_battle_effect_context",
    "_calculate_damage", "_on_player_unit_pressed", "_on_opponent_unit_pressed",
    "_attack_opponent_hero", "_combat", "_play_hero_cutscene",
    "_cleanup_dead_units", "_cleanup_side_dead", "_on_end_turn_pressed",
    "_run_ai_turn", "_check_game_over", "_finish_battle_victory",
    "_show_turn_banner", "_spawn_floating_text", "_flash_label",
    "_render_field", "_render_hand", "_render_battle_deck"
]

# Things that belong to main
main_vars = [
    "card_db", "deck_service", "enemy_service", "event_service", "profile_store",
    "relic_service", "reward_service", "run_generator", "run_store", "ui",
    "battle_effects", "card_defs", "cards_by_id", "player_profile", "current_run",
    "collection_filter", "active_screen", "pending_return_screen", "modal_layer",
    "battle_cutscene"
]

main_funcs = [
    "_node_type_name", "_make_label", "_make_panel_container", "_make_card_frame",
    "_make_art_rect", "_add_menu_button", "_add_title", "_add_log", "_show_error_screen",
    "_show_reward_screen", "_show_map"
]

# We should use regex to replace whole words
for v in main_vars:
    # only replace if it's not already main.var and not preceded by a dot
    code = re.sub(r'(?<!\.)\b' + v + r'\b', 'main.' + v, code)

for fn in main_funcs:
    code = re.sub(r'(?<!\.)\b' + fn + r'\(', 'main.' + fn + '(', code)

# Other substitutions
code = code.replace("get_tree()", "main.get_tree()")
code = code.replace("get_viewport_rect()", "main.get_viewport_rect()")
code = code.replace("Callable(self", "Callable(self") # self refers to BattleScreen now
# But wait, Callable(self, "_add_log") needs to point to main._add_log because _add_log is in main.
# But I already replaced _add_log with main._add_log? No, I didn't replace inside strings.
code = code.replace('Callable(self, "_add_log")', 'Callable(main, "_add_log")')
# Wait, are there other Callables? 
# "draw_cards": Callable(self, "_draw_cards") -> _draw_cards is now in BattleScreen, so self is correct.
# "cleanup_dead_units": Callable(self, "_cleanup_dead_units") -> self is correct.
# "calculate_damage": Callable(self, "_calculate_damage") -> self is correct.
# "_on_turn_timeout", "_on_hand_card_pressed", etc -> self is correct.

# Also in _prepare_battle, the timer was created in main.gd but now should be in battle_screen.gd.
# Since BattleScreen is RefCounted, it can't add_child. So we must add_child to main.
code = code.replace("turn_timer = Timer.new()", "turn_timer = Timer.new()\n    main.add_child(turn_timer)")

with open("scripts/ui/screens/battle_screen.gd", "w") as f:
    f.write(code)

print("Patch complete.")
