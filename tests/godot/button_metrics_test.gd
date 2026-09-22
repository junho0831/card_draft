extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Factory = preload("res://src/ui/ui_factory.gd")
const Metrics = preload("res://src/ui/styles/button_metrics.gd")
const Styles = preload("res://src/ui/styles/battle_styles.gd")
var failures: Array[String] = []
func _init() -> void:
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func settle() -> void:
	for i in range(4): await process_frame
func run() -> void:
	var factory := Factory.new()
	for viewport in [Vector2i(390,844), Vector2i(802,390), Vector2i(1280,720)]:
		root.size = viewport
		var box := VBoxContainer.new()
		box.position = Vector2(12,12)
		box.size.x = viewport.x - 24
		root.add_child(box)
		var buttons: Array[Button] = []
		for role in ["primary", "secondary", "danger"]:
			var button := Button.new()
			button.text = "확인 · " + role
			factory.style_role_button(button, role)
			box.add_child(button)
			buttons.append(button)
		var compact := Button.new()
		compact.text = "정보"
		Metrics.apply(compact, "compact")
		Styles.apply_compact_button(compact, Color.WHITE)
		box.add_child(compact)
		var multiline := Button.new()
		multiline.text = "새 런 시작\n세력과 전략 선택"
		factory.style_primary_button(multiline)
		box.add_child(multiline)
		await settle()
		var expected := buttons[0].size.y
		check(expected == 52, "action height is 52")
		check(compact.size.y == 44 and multiline.size.y == 64, "toolbar and multiline use explicit tiers")
		for button in buttons:
			check(button.size.y == expected, "semantic color does not change geometry")
			var rect := button.get_global_rect()
			button.disabled = true
			await settle()
			check(button.get_global_rect() == rect, "disabled state does not resize")
			button.disabled = false
			button.text = "상태가 바뀌어서 아주 길어진 행동 버튼의 제목도 높이는 유지됩니다"
			Metrics.apply(button)
			await settle()
			check(button.get_global_rect() == rect, "long labels preserve row and viewport width")
			for state in ["normal", "hover", "pressed", "disabled"]:
				check(button.get_theme_stylebox(state).get_minimum_size() == button.get_theme_stylebox("normal").get_minimum_size(), "state padding stays constant")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("buttons-%d.png" % viewport.x))
		box.queue_free()
		await settle()
	print("PASS common button geometry/states/long labels" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
