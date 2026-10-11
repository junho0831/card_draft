extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const Metrics = preload("res://src/ui/styles/button_metrics.gd")
const Dialog = preload("res://src/ui/components/detail_dialog.gd")
const Cards = preload("res://src/ui/components/card_view.gd")
const Economy = preload("res://src/ui/components/economy_detail_view.gd")
var failures: Array[String] = []
var count := 0
var callbacks := 0

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)

func settle() -> void:
	for frame in range(4):
		await process_frame

func on_close() -> void:
	callbacks += 1

func run() -> void:
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("layout_viewport_override", Vector2(844, 390))
	root.add_child(main)
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	main._init_run("human", "human_elite")
	await settle()
	var run_before := JSON.stringify(main.current_run)
	var saved_before := FileAccess.get_file_as_string(Storage.run_path())
	var profile_before := FileAccess.get_file_as_string(Storage.profile_path())
	seed(94127)
	var expected_random := randi()
	seed(94127)
	for dimensions in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		main.set_meta("layout_viewport_override", Vector2(dimensions))
		main._apply_root_layout()
		await create_timer(0.3).timeout
		await settle()
		var row: HBoxContainer = main.ui.make_action_row(8)
		main.modal_layer.add_child(row)
		var titles: Array[String] = ["구매", "바람의 궁수 · 구매", "아주 긴 한국어 카드 이름을 가진 기사 · 구매"]
		var button: Button = Economy.action_button(main, titles[0], on_close)
		row.add_child(button)
		Economy.size_action_labels(button, titles, 120)
		await settle()
		var reserved := button.custom_minimum_size.x
		var rect := button.get_global_rect()
		for title in titles:
			Economy.set_action_label(button, title)
			await settle()
			var glyphs := button.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
			check(glyphs.x + button.get_theme_stylebox("normal").get_minimum_size().x <= reserved, "reserved width fits Korean label")
			check(button.get_global_rect() == rect and button.custom_minimum_size.x == reserved, "selection preserves reserved button geometry")
			check(button.tooltip_text == title and not button.clip_text, "label and tooltip stay in sync")
		button.disabled = true
		Metrics.set_label(button, "품절")
		await settle()
		check(button.get_global_rect() == rect, "sold-out state preserves geometry")
		button.pressed.emit()
		check(callbacks == 1, "factory connects callback once")
		callbacks = 0
		row.queue_free()
		await settle()
		var card: Dictionary = main.card_db.get_card("forest_archer").duplicate(true)
		card.name = titles[2]
		var face := Cards.make_compact_offer(main, card, 180, 194, "120 골드 · 품절")
		main.modal_layer.add_child(face)
		Cards.add_offer_selection(main, face)
		check(face.has_node("EconomyOfferArt") and face.has_node("EconomyOfferName"), "compact card keeps public node names")
		check(face.get_node("EconomyOfferName").max_lines_visible == 2, "long card name keeps two-line presentation")
		Economy.select_offer(face, true)
		check(face.get_node("EconomyOfferSelection").visible, "shared selection marker can be selected")
		Economy.select_offer(face, false)
		check(not face.get_node("EconomyOfferSelection").visible, "shared selection marker can be cancelled")
		face.queue_free()
		await settle()
		var child_count: int = main.modal_layer.get_child_count()
		for profile in Dialog.Profile.values():
			for repeat in range(2):
				var heading: Label = null
				if profile not in [Dialog.Profile.COLLECTION, Dialog.Profile.LEGACY_BATTLE]:
					heading = main.ui.make_label("긴 한국어 카드 상세보기", 20, Color.WHITE)
				var close: Button = main.ui.make_button("닫기")
				var dialog = Dialog.create(main.modal_layer, profile, heading, close, on_close, Vector2(dimensions), main.ui, Dialog.CloseBehavior.FREE)
				dialog.show()
				check(dialog.scroll != null and dialog.close_button == close, "profile exposes common scroll and close")
				dialog.scroll.scroll_vertical = 30
				close.pressed.emit()
				close.pressed.emit()
				check(callbacks == 1, "close callback is never duplicated")
				callbacks = 0
				await settle()
				check(not is_instance_valid(dialog), "delete-on-close leaves no dialog")
		var hidden = Dialog.create(main.modal_layer, Dialog.Profile.LEGACY_BATTLE, null, main.ui.make_button("전투로 돌아가기"), on_close, Vector2(dimensions), main.ui, Dialog.CloseBehavior.HIDE)
		var identity: int = hidden.get_instance_id()
		for repeat in range(3):
			hidden.show()
			hidden.close_button.pressed.emit()
			hidden.close_button.pressed.emit()
			check(callbacks == 1, "reused dialog closes once each time")
			callbacks = 0
			check(is_instance_valid(hidden) and not hidden.visible and hidden.get_instance_id() == identity, "hidden dialog is reused, not recreated")
		hidden.queue_free()
		await settle()
		check(main.modal_layer.get_child_count() == child_count, "repeated open/close leaves no orphan nodes")
	check(randi() == expected_random, "UI creation/scroll/selection/close preserve global RNG")
	check(JSON.stringify(main.current_run) == run_before, "UI operations preserve run state")
	check(FileAccess.get_file_as_string(Storage.run_path()) == saved_before, "UI operations preserve run save")
	check(FileAccess.get_file_as_string(Storage.profile_path()) == profile_before, "UI operations preserve profile save")
	main.queue_free()
	await settle()
	print("PASS common UI: %d assertions" % count if failures.is_empty() else "FAIL common UI: " + str(failures))
	quit(0 if failures.is_empty() else 1)
