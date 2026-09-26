extends RefCounted
const Presentation = preload("res://src/ui/components/battle_presentation.gd")
## Presentation lifetime is independent of the disposable battlefield controls.
var owner: WeakRef
var tree: SceneTree
var view: Control
var disposed := false
var focus_tween: Tween
var focus_generation := 0
var focus_pending := false
var pointer_down := false
var interaction_generation := 0
var return_generation := 0
var tweens: Array[Tween] = []
var battle:
	get: return owner.get_ref()

func _init(battle_owner) -> void:
	owner = weakref(battle_owner)
	tree = battle_owner.main.get_tree()

func attach(control: Control) -> void:
	view = control

func _view_alive() -> bool:
	return not disposed and is_instance_valid(view) and view.is_inside_tree()

func cancel_focus() -> void:
	return_generation += 1
	focus_pending = false
	focus_generation += 1
	if is_instance_valid(focus_tween): focus_tween.kill()

func gesture_started(_point: Vector2) -> void:
	interaction_generation += 1
	pointer_down = true
	if is_instance_valid(focus_tween) and focus_tween.is_running():
		battle.main.touch_scroll_router.block_current_tap()
	cancel_focus()

func gesture_ended() -> void:
	pointer_down = false

func dispose() -> void:
	disposed = true
	cancel_focus()
	for tween in tweens:
		if is_instance_valid(tween): tween.kill()
	tweens.clear()

func _tween(node: Node) -> Tween:
	var tween := tree.create_tween().bind_node(node)
	tweens.append(tween)
	return tween

func _wait(tween: Tween) -> bool:
	while not disposed and tween.is_valid() and tween.is_running():
		await tree.process_frame
	tweens.erase(tween)
	return not disposed

func scroll_for_rect(rect: Rect2) -> int:
	# Content coordinates stay stable even before ScrollContainer's deferred layout.
	var top: float = rect.position.y - view.lanes.global_position.y
	var bottom: float = top + rect.size.y
	var destination := float(view.board_scroll.scroll_vertical)
	if top < destination + 8:
		destination = top - 8
	elif bottom > destination + view.board_scroll.size.y - 8:
		destination = bottom - view.board_scroll.size.y + 8
	var bar: ScrollBar = view.board_scroll.get_v_scroll_bar()
	return int(clampf(destination, 0, maxf(0, bar.max_value - bar.page)))

func focus(targets: Array, immediate: bool = false, manual: bool = false) -> void:
	if pointer_down or not _view_alive(): return
	if view.board_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED: return
	if not manual and not immediate and battle.main.player_profile.settings.get("battle_auto_focus", "outside") == "off": return
	cancel_focus()
	focus_pending = true
	var request := focus_generation
	await _move_to_targets(targets, immediate)
	if request == focus_generation: focus_pending = false

func _move_to_targets(targets: Array, immediate: bool = false) -> void:
	if pointer_down or not _view_alive() or not is_instance_valid(view.board_scroll):
		return
	var generation := focus_generation
	var rects: Array[Rect2] = []
	for target in targets:
		var node: Control = view.resolve_focus(target)
		if is_instance_valid(node): rects.append(node.get_global_rect())
	if rects.is_empty(): return
	var union := rects[0]
	for rect in rects: union = union.merge(rect)
	if union.size.y <= view.board_scroll.size.y - 16:
		rects = [union]
	for rect in rects.slice(0, 2):
		if generation != focus_generation or pointer_down: return
		# Re-resolve the second target after the first scroll changed global coordinates.
		if rects.size() > 1:
			var node: Control = view.resolve_focus(targets[rects.find(rect)])
			if is_instance_valid(node): rect = node.get_global_rect()
		var destination := scroll_for_rect(rect)
		if battle.main.player_profile.settings.get("battle_auto_focus", "outside") == "always":
			var bar: ScrollBar = view.board_scroll.get_v_scroll_bar()
			destination = int(clampf(rect.get_center().y - view.lanes.global_position.y - view.board_scroll.size.y * 0.5, 0, maxf(0, bar.max_value - bar.page)))
		if destination == view.board_scroll.scroll_vertical: continue
		if immediate or battle._should_skip_timed_battle_fx():
			view.board_scroll.scroll_vertical = destination
			continue
		focus_tween = tree.create_tween()
		focus_tween.tween_property(view.board_scroll, "scroll_vertical", destination, 0.12 if rects.size() > 1 else 0.18).set_trans(Tween.TRANS_SINE)
		# Polling avoids awaiting a killed Tween's never-emitted finished signal.
		while _view_alive() and generation == focus_generation and focus_tween.is_running():
			await tree.process_frame

func return_to_allies(gesture: int) -> void:
	if not _view_alive(): return
	if view.board_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED: return
	var generation := return_generation
	# Let the outcome remain readable; user gestures/modal opening cancel this return.
	await tree.create_timer(0.45 if not battle._should_skip_timed_battle_fx() else 0.0).timeout
	if not _view_alive() or gesture != interaction_generation or generation != return_generation: return
	if battle.game_over or battle.battle_finished or battle.leaving_battle or battle.current_player != "player": return
	if is_instance_valid(view.card_dialog) or battle.battle_detail_visible: return
	var ready: Array[int] = battle._ready_player_attacker_indexes()
	await focus([battle._focus_unit(battle.player, ready[0]) if not ready.is_empty() else {"player":true, "hero":true}])

func inline_attack(attacker_node: Control, defender_node: Control, damage: int, attacker_is_player: bool, counter: bool = false, sfx_name: String = "") -> void:
	if disposed or not is_instance_valid(attacker_node) or not is_instance_valid(defender_node): return
	var start_pos = attacker_node.position
	var start_rotation := attacker_node.rotation
	var start_scale := Vector2.ONE
	var landscape: bool = battle._is_landscape_phone()
	var motion := Presentation.attack_motion(landscape, damage, counter)
	var lunge_offset = Vector2(0, -58 if attacker_is_player else 58)
	if landscape:
		var direction := defender_node.get_global_rect().get_center() - attacker_node.get_global_rect().get_center()
		if direction.length_squared() > 1.0:
			lunge_offset = direction.normalized() * float(motion.distance)
	if counter:
		lunge_offset *= 0.72
	attacker_node.pivot_offset = attacker_node.size * 0.5
	if motion.windup > 0.0:
		var windup := _tween(attacker_node)
		windup.set_parallel(true)
		windup.tween_property(attacker_node, "position", start_pos - lunge_offset.normalized() * 9.0, motion.windup)
		windup.tween_property(attacker_node, "scale", start_scale * 1.06, motion.windup)
		if not await _wait(windup): return
	var approach = _tween(attacker_node)
	approach.set_parallel(true)
	approach.tween_property(attacker_node, "position", start_pos + lunge_offset, motion.approach).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	approach.tween_property(attacker_node, "scale", Vector2(1.17, 1.17) if not counter else Vector2(1.1, 1.1), 0.085).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	approach.tween_property(attacker_node, "rotation", start_rotation + deg_to_rad(-4.5 if attacker_is_player else 4.5), 0.085)
	if not await _wait(approach): return

	impact(attacker_node, defender_node, damage, counter, sfx_name, true)
	await tree.create_timer(motion.hit_stop).timeout
	if disposed or not is_instance_valid(attacker_node) or not is_instance_valid(defender_node): return

	var recoil_direction: Vector2 = -lunge_offset.normalized()
	var recoil_position: Vector2 = Vector2(start_pos) + recoil_direction * (10.0 if damage >= 4 else 6.0)
	var recoil = _tween(attacker_node)
	recoil.tween_property(attacker_node, "position", recoil_position, motion.recoil).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(attacker_node, "scale", Vector2(0.94, 0.94), motion.recoil)
	recoil.tween_property(attacker_node, "position", start_pos, motion.recover).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(attacker_node, "scale", start_scale, motion.recover).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(attacker_node, "rotation", start_rotation, motion.recover)
	await _wait(recoil)


func _target(descriptor: Dictionary) -> Control:
	var ally := bool(descriptor.get("player", true))
	if descriptor.get("hero", false): return battle._hero_target_for_player(ally)
	var side: Dictionary = battle.player if ally else battle.opponent
	var index: int = battle.attack_executor.index_of(side, int(descriptor.get("unit_id", -1)))
	return battle._field_slot_for(side, index)

func play_attack(result: Dictionary) -> void:
	if disposed or battle._should_skip_timed_battle_fx(): return
	var attacker := _target(result.attacker)
	var defender := _target(result.defender)
	if not is_instance_valid(attacker) or not is_instance_valid(defender): return
	var damage := int(result.damage)
	var counter_damage := int(result.get("counter_damage", 0))
	if battle._is_battle_cutscene_enabled():
		await inline_attack(attacker, defender, damage, bool(result.attacker.player), false, String(result.attack_sfx))
		if not disposed and counter_damage > 0:
			await inline_attack(defender, attacker, counter_damage, bool(result.defender.player), true, String(result.counter_sfx))
	else:
		impact(attacker, defender, damage, false, String(result.attack_sfx))
		if counter_damage > 0:
			impact(defender, attacker, counter_damage, true, String(result.counter_sfx))

func impact(attacker: Control, defender: Control, damage: int, counter: bool, sfx: String, animated: bool = false) -> void:
	if disposed or not is_instance_valid(defender): return
	battle._show_damage_number(defender, damage, counter)
	if Presentation.effect_mode(battle.main.player_profile.settings) == "minimal":
		battle._play_sfx(sfx)
		return
	battle._play_attack_impact_fx(attacker, defender, damage, counter, sfx)
	battle._play_sfx(sfx if not sfx.is_empty() or not animated else battle._attack_impact_sfx({}, damage, counter))
	battle._spawn_impact_slash(defender, counter)
	battle._flash_target(defender, Color(1.0, 0.66, 0.18, 1.0) if counter else Color(1.0, 0.28, 0.22, 1.0), 0.24 if animated else 0.22)
	if animated:
		battle._shake_target(defender, 12.0 if damage < 3 else 18.0)
