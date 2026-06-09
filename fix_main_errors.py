with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.startswith("var modal_layer: Control"):
        new_lines.append(line)
        new_lines.append("var battle_cutscene\n")
    elif line.startswith("func _start_battle()"):
        # We need to insert _prepare_battle instead!
        pass
    else:
        new_lines.append(line)

with open("scripts/core/main.gd", "w") as f:
    f.writelines(new_lines)

with open("scripts/core/main.gd", "a") as f:
    f.write("\n")
    f.write("func _prepare_battle(tier: String) -> void:\n")
    f.write("\tactive_screen = \"battle\"\n")
    f.write("\t_clear_screen()\n")
    f.write("\tvar BattleScreenClass = load(\"res://scripts/ui/screens/battle_screen.gd\")\n")
    f.write("\tvar battle_screen = BattleScreenClass.new(self)\n")
    f.write("\tbattle_screen._prepare_battle(tier)\n")

print("Fixed main.gd")
