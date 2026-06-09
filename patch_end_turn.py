import sys

with open("scripts/ui/screens/battle_screen.gd", "r") as f:
    content = f.read()

content = content.replace("func _check_auto_end_turn() -> void:", "func _check_no_actions_loss() -> void:")
content = content.replace("_check_auto_end_turn()", "_check_no_actions_loss()")

old_end = """	if not has_attacker and not has_playable_card:
		main._add_log("할 수 있는 행동이 없어 자동으로 턴을 종료합니다.")
		_on_end_turn_pressed()"""

new_end = """	if not has_attacker and not has_playable_card:
		main._add_log("더 이상 할 수 있는 행동이 없어 패배합니다.")
		player.health = 0
		_check_game_over()"""

content = content.replace(old_end, new_end)

with open("scripts/ui/screens/battle_screen.gd", "w") as f:
    f.write(content)

print("End turn logic updated.")
