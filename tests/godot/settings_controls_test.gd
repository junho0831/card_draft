extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Policy = preload("res://src/ui/components/battle_presentation.gd")
var failures: Array[String] = []
func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func settle() -> void:
	for i in range(8): await process_frame
func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for(file + ".png"))
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func run() -> void:
	root.size = Vector2i(802, 390)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", root.size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.set_process(false) # Viewports are driven explicitly by this test.
	main.touch_input_active = true
	for legacy in [false, true]:
		var old: Dictionary = main.profile_store.normalize({"settings":{"battle_cutscene":legacy}}, [])
		check(Policy.effect_mode(old.settings) == ("rich" if legacy else "compact"), "legacy effects preserved")
		check(old.settings.battle_auto_focus == "outside" and old.settings.bgm_volume == 1.0, "legacy focus and volume preserved")
	var invalid: Dictionary = main.profile_store.normalize({"settings":{"bgm_volume":-2,"sfx_volume":"oops","battle_auto_focus":"bad"}}, [])
	check(invalid.settings.bgm_volume == 0 and invalid.settings.sfx_volume == 1 and invalid.settings.battle_auto_focus == "outside", "invalid settings normalized")
	for viewport in [Vector2i(802,390), Vector2i(390,844)]:
		root.size = viewport
		main.set_meta("layout_viewport_override", viewport)
		main._apply_root_layout()
		main.last_layout_signature = main._layout_signature(viewport)
		main.layout_resize_timer.stop()
		main._show_settings()
		await settle()
		var screen = main.active_screen_controller
		var bgm: HSlider = main.root_box.find_child("bgm_volume", true, false)
		var sfx: HSlider = main.root_box.find_child("sfx_volume", true, false)
		check(bgm.get_global_rect().end.x <= viewport.x, "volume slider fits %s" % viewport)
		await capture("settings-%d" % viewport.x)
		var slider_point := bgm.get_global_rect().get_center()
		main.touch_scroll_router._begin_gesture(slider_point, main.root_box)
		check(not main.touch_scroll_router._move_gesture(slider_point + Vector2(40,0), Vector2(40,0)), "slider owns drag instead of page")
		main.touch_scroll_router._end_gesture()
		await click(bgm)
		check(bgm.value > 40 and bgm.value < 60, "volume responds to pointer input")
		bgm.value = 0
		sfx.value = 35
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "zero music volume mutes BGM")
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "music mute does not mute effects")
		check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.35)), "SFX gain applied")
		main.audio_manager._process(1)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "ducking does not undo user mute")
		bgm.value = 70
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("BGM")), "music can be unmuted")
		screen._on_focus_selected(0)
		main._save_profile()
		var saved: Dictionary = main.profile_store.load_or_create(Storage.profile_path(), main.card_defs)
		check(is_equal_approx(float(saved.settings.sfx_volume), 0.35), "volume survives save/load")
		check(saved.settings.battle_auto_focus == "always", "focus survives save/load")
		main.root_scroll.ensure_control_visible(screen.preview_button)
		await settle()
		var selector: OptionButton = main.root_box.find_child("EffectsMode", true, false)
		main.root_scroll.ensure_control_visible(selector)
		await settle()
		var point := selector.get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = point
		press.global_position = point
		press.pressed = true
		root.push_input(press, true)
		await process_frame
		check(not selector.get_popup().visible, "selector waits for release so a swipe can start")
		var scroll_before: int = main.root_scroll.scroll_vertical
		var motion := InputEventMouseMotion.new()
		motion.position = point - Vector2(0, 50)
		motion.global_position = motion.position
		motion.relative = Vector2(0, -50)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
		press.pressed = false
		press.position = motion.position
		press.global_position = motion.position
		root.push_input(press, true)
		await settle()
		check(main.root_scroll.scroll_vertical > scroll_before, "swipe starting on selector scrolls settings")
		check(not selector.get_popup().visible, "swiping selector does not open choices")
		main.root_scroll.ensure_control_visible(selector)
		await settle()
		await click(selector)
		check(selector.get_popup().visible, "selector still opens with a tap after a swipe")
		selector.get_popup().hide()
		main.root_scroll.ensure_control_visible(screen.preview_button)
		await settle()
		var before := JSON.stringify(main.current_run)
		for index in range(3):
			screen._on_effects_selected(index)
			check(Policy.effect_mode(main.player_profile.settings) == screen.EFFECT_MODES[index], "effects choice applied")
			await click(screen.preview_button)
			check(screen.preview.playing, "preview starts from button input")
			await create_timer(0.22).timeout
			check(screen.preview.damage_label.visible, "preview shows damage in all modes")
			if index == 0: await capture("preview-%d" % viewport.x)
			await create_timer(0.85).timeout
			check(not screen.preview.playing and not screen.preview_replay.disabled, "preview releases replay button")
			check(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(screen.preview_close.get_global_rect()), "preview close fits viewport")
			await click(screen.preview_replay)
			check(screen.preview.playing, "replay starts through pointer input")
			await click(screen.preview_close)
			await settle()
			check(not is_instance_valid(screen.preview_overlay), "preview closes during playback")
		check(JSON.stringify(main.current_run) == before, "preview never changes run")
		var profile_before := JSON.stringify(main.player_profile)
		screen.request_reset()
		await settle()
		check(screen.reset_confirmation.get_ok_button().size.y >= 48, "reset confirmation has a large touch target")
		await capture("reset-%d" % viewport.x)
		check(JSON.stringify(main.player_profile) == profile_before, "opening reset does not reset profile")
		screen.reset_confirmation.get_cancel_button().pressed.emit()
		await settle()
		check(JSON.stringify(main.player_profile) == profile_before, "cancel reset preserves profile")
		screen.reset_confirmation.hide()
	# Reset requires explicit confirmation, exercised only against isolated QA storage.
	var settings_screen = main.active_screen_controller
	main.player_profile.soul_stones = 123
	main._save_profile()
	settings_screen.request_reset()
	settings_screen.reset_confirmation.confirmed.emit()
	await settle()
	check(main.player_profile.soul_stones == 0, "confirmed reset resets profile")
	check(main.player_profile.settings.bgm_volume == 1.0, "confirmed reset restores volume")
	# Camera preference affects automatic following only, not explicit navigation.
	root.size = Vector2i(802,390)
	main.set_meta("layout_viewport_override", root.size)
	main._apply_root_layout()
	main.last_layout_signature = main._layout_signature(root.size)
	main.layout_resize_timer.stop()
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	await settle()
	var battle = main.battle_screen
	var view = battle.landscape_view
	main.player_profile.settings.battle_auto_focus = "off"
	view.board_scroll.scroll_vertical = 0
	await view.session.focus([{"player":true, "hero":true}])
	check(view.board_scroll.scroll_vertical == 0, "auto follow off preserves scroll")
	await view.session.focus([{"player":true, "hero":true}], false, true)
	check(view.board_scroll.scroll_vertical > 0, "manual navigation works with auto follow off")
	main.player_profile.settings.battle_auto_focus = "outside"
	var camera_before: int = view.board_scroll.scroll_vertical
	await view.session.focus([{"player":true, "hero":true}])
	check(view.board_scroll.scroll_vertical == camera_before, "visible target does not move outside-only camera")
	main.player_profile.settings.battle_auto_focus = "always"
	await view.session.focus([{"player":false,"hero":true}])
	check(view.board_scroll.scroll_vertical == 0, "always mode reaches target")
	main.player_profile.settings.reduced_battle_fx = true
	main.set_meta("disable_timed_battle_fx", false)
	battle.opponent.field.clear()
	battle.player.field = [{"id":"militia","name":"민병대","race":"인간","battle_unit_id":9901,"attack":1,"health":3,"max_health":3,"can_attack":true}]
	battle._refresh_ui()
	await settle()
	var hp_before := int(battle.opponent.health)
	await battle.attack_executor.execute("player", 9901, {"kind":"hero"})
	check(battle.opponent.health == hp_before - 1 and not battle.attack_executor.busy, "minimal mode resolves one attack without lock")
	check(battle.battle_fx_layer.get_children().all(func(node): return node is Label), "minimal mode keeps labels without particles")
	await create_timer(1.25).timeout
	check(battle.battle_fx_layer.get_child_count() == 0, "minimal damage labels are cleaned up")
	main._clear_screen()
	main.queue_free()
	await settle()
	print("PASS settings migration/audio/preview/reset/camera" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
