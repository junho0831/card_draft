extends Control
## Isolated visual sample: uses authored battle art/audio/fx, never a run or combat state.
const Fx = preload("res://src/ui/effects/battle_fx_layer.gd")
const Presentation = preload("res://src/ui/components/battle_presentation.gd")
const Styles = preload("res://src/ui/styles/battle_styles.gd")
signal finished
var main
var attacker: TextureRect
var defender: TextureRect
var damage_label: Label
var fx: Control
var playing := false

func setup(owner_main) -> void:
	main = owner_main
	custom_minimum_size.y = 160
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", Styles.make_flat_style(Color("081320"), Color("695638")))
	add_child(backdrop)
	attacker = main.ui.make_card_art(main, main.card_db.get_card("trainee_swordsman"), Vector2(76, 112))
	defender = main.ui.make_card_art(main, main.card_db.get_card("militia"), Vector2(76, 112))
	for entry in [[attacker, 0.12], [defender, 0.64]]:
		var card: TextureRect = entry[0]
		add_child(card)
		card.anchor_left = entry[1]
		card.anchor_right = entry[1]
		card.position.y = 20
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx = Fx.new()
	fx.set_meta("compact_landscape", true)
	add_child(fx)
	damage_label = Label.new()
	damage_label.text = "−3"
	damage_label.add_theme_font_size_override("font_size", 36)
	damage_label.add_theme_color_override("font_color", Color("ffcc7b"))
	damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	damage_label.add_theme_constant_override("outline_size", 6)
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.hide()
	add_child(damage_label)
	damage_label.z_index = 80

func play() -> void:
	if playing: return
	playing = true
	var mode := Presentation.effect_mode(main.player_profile.settings)
	var origin := attacker.position
	var motion := Presentation.attack_motion(true, 3, false)
	var tween := create_tween()
	if mode == "rich":
		tween.tween_property(attacker, "position", origin - Vector2(9, 0), motion.windup)
		tween.tween_property(attacker, "position", origin + Vector2(motion.distance, 0), motion.approach)
	tween.tween_callback(_hit.bind(mode))
	if mode == "rich":
		tween.tween_interval(motion.hit_stop)
		tween.tween_property(attacker, "position", origin, motion.recover)
	tween.tween_interval(0.65)
	tween.tween_callback(func():
		attacker.position = origin
		defender.modulate = Color.WHITE
		damage_label.hide()
		playing = false
		finished.emit()
	)

func _hit(mode: String) -> void:
	main.audio_manager.play_sound("hit_human")
	damage_label.position = defender.position + Vector2(12, 24)
	damage_label.show()
	if mode != "minimal":
		fx.play_attack(attacker, defender, 3, false, "hit_human")
		defender.modulate = Color(1, 0.4, 0.3)
		var tween := create_tween()
		tween.tween_property(defender, "modulate", Color.WHITE, 0.22)
