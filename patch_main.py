with open("scripts/core/main.gd", "r") as f:
    lines = f.readlines()

new_lines = []
skip_mode = False

for i, line in enumerate(lines):
    if line.startswith("func _process"):
        # We should just keep the def, and let it pass for now.
        pass
    new_lines.append(line)

with open("scripts/core/main.gd", "w") as f:
    for line in new_lines:
        f.write(line)
