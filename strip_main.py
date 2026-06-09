with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

funcs_to_remove = [
    "_start_turn", "_show_turn_banner", "_draw_cards", "_on_hand_card_pressed",
    "_battle_effect_context", "_calculate_damage", "_on_player_unit_pressed",
    "_on_opponent_unit_pressed", "_attack_opponent_hero", "_combat",
    "_check_auto_end_turn", "_play_hero_cutscene", "_cleanup_dead_units",
    "_cleanup_side_dead", "_on_end_turn_pressed", "_run_ai_turn", "_check_game_over",
    "_finish_battle_victory", "_spawn_floating_text", "_flash_label", "_render_field",
    "_render_hand", "_render_battle_deck", "_refresh_ui"
]

new_lines = []
skip = False
for line in lines:
    if line.startswith("func "):
        fn_name = line.split("(")[0].split(" ")[1]
        if fn_name in funcs_to_remove:
            skip = True
        else:
            skip = False
    
    if not skip:
        new_lines.append(line)

with open("scripts/core/main.gd", "w") as f:
    f.writelines(new_lines)
