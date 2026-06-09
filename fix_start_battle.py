with open("scripts/ui/screens/battle_screen.gd", "r") as f:
    content = f.read()

content = content.replace("func _start_battle() -> void:", "func start_battle() -> void:")
content = content.replace("	_start_battle()", "	start_battle()")

with open("scripts/ui/screens/battle_screen.gd", "w") as f:
    f.write(content)

with open("scripts/core/main.gd", "r") as f:
    content = f.read()

content = content.replace("		_start_battle()\n", "		var bs = load(\"res://scripts/ui/screens/battle_screen.gd\").new(self)\n		bs.start_battle()\n")

with open("scripts/core/main.gd", "w") as f:
    f.write(content)

print("Fixed start_battle")
