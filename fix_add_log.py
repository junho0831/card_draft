with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if line.startswith("func _add_log"):
        skip = True
    elif skip and line.startswith("func "):
        skip = False
    
    if not skip:
        new_lines.append(line)

with open("scripts/core/main.gd", "w") as f:
    f.writelines(new_lines)

with open("scripts/ui/screens/battle_screen.gd", "a") as f:
    f.write("\n")
    f.write("func _add_log(message: String) -> void:\n")
    f.write("\tif log_label == null:\n")
    f.write("\t\treturn\n")
    f.write("\tlog_label.text = message + \"\\n\" + log_label.text\n")

print("Fixed _add_log")
