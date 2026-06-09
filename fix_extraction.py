with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

new_lines = []
start_battle_lines = []
in_start_battle = False

for line in lines:
    if line.startswith("func _start_battle("):
        in_start_battle = True
        start_battle_lines.append(line)
        continue
    if in_start_battle:
        if line.startswith("func "):
            in_start_battle = False
            new_lines.append(line)
        else:
            start_battle_lines.append(line)
    else:
        new_lines.append(line)

with open("scripts/core/main.gd", "w") as f:
    f.writelines(new_lines)

with open("scripts/ui/screens/battle_screen.gd", "a") as f:
    f.write("\n")
    for line in start_battle_lines:
        line = line.replace("active_screen", "main.active_screen")
        line = line.replace("_clear_screen", "main._clear_screen")
        line = line.replace("current_run", "main.current_run")
        line = line.replace("_show_map", "main._show_map")
        line = line.replace("card_db", "main.card_db")
        line = line.replace("relic_service", "main.relic_service")
        line = line.replace("run_store", "main.run_store")
        f.write(line)

print("Extraction fixed")
