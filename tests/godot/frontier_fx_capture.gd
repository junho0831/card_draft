extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Profiles = preload("res://src/battle/card_impact_profiles.gd")
func _initialize():
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func run():
	root.size = Vector2i(1280, 720)
	var surface := Control.new()
	root.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("101724")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(bg)
	var targets: Array = []
	var index := 0
	for key in Profiles.PROFILES:
		var pos := Vector2((index % 4) * 320 + 16, (index / 4) * 240 + 16)
		var title := Label.new()
		title.text = key.to_upper()
		title.position = pos
		title.add_theme_font_size_override("font_size", 22)
		surface.add_child(title)
		var attacker := ColorRect.new()
		attacker.color = Color(Profiles.PROFILES[key].color).darkened(0.35)
		attacker.position = pos + Vector2(10, 50); attacker.size = Vector2(75,125)
		surface.add_child(attacker)
		var defender := ColorRect.new()
		defender.color = Color("28374b")
		defender.position = pos + Vector2(190,50); defender.size = Vector2(75,125)
		surface.add_child(defender)
		targets.append([attacker,defender,"impact_"+key])
		index += 1
	var fx := preload("res://src/ui/effects/battle_fx_layer.gd").new()
	surface.add_child(fx)
	await process_frame
	var baseline := fx.get_child_count()
	var policy = preload("res://src/ui/components/battle_presentation.gd")
	for landscape in [false, true]:
		var light: Dictionary = policy.attack_motion(landscape, 2, false)
		var heavy: Dictionary = policy.attack_motion(landscape, 4, false)
		assert(light.distance < heavy.distance and light.hit_stop < heavy.hit_stop, "light attacks travel less and pause less")
	for style in ["hit_human", "impact_metal", "impact_fire", "impact_lightning", "impact_wind"]:
		fx.play_attack(targets[0][0], targets[0][1], 2, false, style)
		var light_count := fx.get_child_count()
		await create_timer(0.8).timeout
		assert(fx.get_child_count() == baseline, "light effects clean up")
		fx.play_attack(targets[0][0], targets[0][1], 4, false, style)
		assert(fx.get_child_count() > light_count, "heavy effects have stronger accents: " + style)
		await create_timer(0.8).timeout
	for target in targets: fx.play_attack(target[0],target[1],4,false,target[2])
	await create_timer(0.07).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("impact-profiles.png"))
	await create_timer(0.8).timeout
	assert(fx.get_child_count() == baseline, "all impact profile transients are released")
	for target in targets: assert(target[0].size == Vector2(75,125), "impact does not resize attacker")
	fx.set_meta("reduced_effects", true)
	for target in targets: fx.play_attack(target[0], target[1], 4, false, target[2])
	assert(fx.get_child_count() == baseline, "reduced effects skips all motifs")
	surface.queue_free()
	await process_frame
	print("PASS 12 impact motifs and transient cleanup")
	quit()
