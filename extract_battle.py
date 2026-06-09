import re

with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

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

in_func = False
func_lines = []
other_lines = []

def starts_with_func(line):
    for fn in battle_funcs:
        if line.startswith(f"func {fn}("):
            return fn
    return None

current_func = None
extracted = {}

for line in lines:
    fn = starts_with_func(line)
    if fn:
        in_func = True
        current_func = fn
        extracted[current_func] = [line]
        continue
    
    if in_func:
        if line.startswith("func ") and not line.startswith("	"):
            # Reached a new function
            fn2 = starts_with_func(line)
            if fn2:
                current_func = fn2
                extracted[current_func] = [line]
            else:
                in_func = False
                other_lines.append(line)
        else:
            extracted[current_func].append(line)
    else:
        # We need to extract the variables too!
        if line.startswith("var ") and ("last_player_health" in line or "last_opponent_health" in line or "turn_overlay" in line or "turn_timer" in line or "turn_timer_label" in line or "opponent_info" in line or "opponent_field_box" in line or "hero_attack_button" in line or "player_field_box" in line or "player_info" in line or "hand_box" in line or "deck_count_label" in line or "deck_list_label" in line or "end_turn_button" in line or "player :=" in line or "opponent :=" in line or "current_player :=" in line or "selected_attacker :=" in line or "game_over :=" in line or "battle_finished :=" in line or "input_locked :=" in line or "battle_state :=" in line or "battle_tier :=" in line):
            # Don't add to other_lines, we will put them in battle_screen.gd
            continue
        
        # Need to remove the turn_timer code in _build_base_ui and _process
        # but let's just do it manually later
        other_lines.append(line)

with open("scripts/ui/screens/battle_screen.gd", "w") as f:
    f.write('extends RefCounted\n\n')
    f.write('var main\n')
    f.write('var root_box: VBoxContainer\n')
    f.write('var status_label: Label\n')
    f.write('var opponent_info: Label\n')
    f.write('var opponent_field_box: HBoxContainer\n')
    f.write('var hero_attack_button: Button\n')
    f.write('var player_field_box: HBoxContainer\n')
    f.write('var player_info: Label\n')
    f.write('var hand_box: HBoxContainer\n')
    f.write('var deck_count_label: Label\n')
    f.write('var turn_overlay: Panel\n')
    f.write('var turn_timer: Timer\n')
    f.write('var turn_timer_label: Label\n')
    f.write('var deck_list_label: RichTextLabel\n')
    f.write('var end_turn_button: Button\n')
    f.write('var last_player_health: int = -1\n')
    f.write('var last_opponent_health: int = -1\n')
    f.write('var player := {}\n')
    f.write('var opponent := {}\n')
    f.write('var current_player := "player"\n')
    f.write('var selected_attacker := -1\n')
    f.write('var game_over := false\n')
    f.write('var battle_finished := false\n')
    f.write('var input_locked := false\n')
    f.write('var battle_state := {}\n')
    f.write('var battle_tier := "normal"\n\n')
    
    f.write('func _init(main_ref) -> void:\n')
    f.write('    main = main_ref\n')
    f.write('    root_box = main.root_box\n\n')
    
    for k, v in extracted.items():
        for l in v:
            f.write(l)
        f.write('\n')

with open("scripts/core/main.gd", "w") as f:
    for l in other_lines:
        f.write(l)

print(f"Extracted {len(extracted)} functions.")
