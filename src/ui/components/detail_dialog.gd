extends Control
## Presentation only. Callers own actions, data, back navigation and game state.

const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Styles = preload("res://src/ui/styles/ui_styles.gd")

enum Profile { LANDSCAPE_CARD, BATTLE_INFO, ECONOMY, COLLECTION, LEGACY_BATTLE }
enum CloseBehavior { CALLBACK_ONLY, HIDE, FREE }

var title_label: Label
var close_button: Button
var header: HBoxContainer
var body: VBoxContainer
var media: HBoxContainer
var content: Control
var scroll: ScrollContainer
var actions: HBoxContainer
var _close_callback: Callable
var _close_behavior: CloseBehavior
var _closing := false
var _ui: RefCounted

static func create(host: Control, profile: Profile, heading: Label, close_control: Button, close: Callable, viewport: Vector2, ui: RefCounted, behavior: CloseBehavior = CloseBehavior.CALLBACK_ONLY) -> Control:
	var dialog := new()
	dialog.title_label = heading
	dialog.close_button = close_control
	dialog._close_callback = close
	dialog._close_behavior = behavior
	dialog._ui = ui
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dialog)
	dialog._build_surface(profile, viewport, ui)
	dialog._build_content(profile)
	close_control.pressed.connect(dialog.request_close)
	dialog.visibility_changed.connect(func():
		if dialog.visible:
			dialog._closing = false
	)
	if profile == Profile.BATTLE_INFO:
		close_control.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				close_control.accept_event()
				dialog.request_close()
		)
		close_control.grab_focus()
	if profile == Profile.LEGACY_BATTLE:
		dialog.hide()
	return dialog

func request_close() -> void:
	if _closing:
		return
	_closing = true
	if _close_callback.is_valid():
		_close_callback.call()
	if is_queued_for_deletion():
		return
	match _close_behavior:
		CloseBehavior.HIDE: hide()
		CloseBehavior.FREE: queue_free()

func _shade(color: Color) -> void:
	var shade := ColorRect.new()
	shade.color = color
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

func _background(node_name: String, brightness: float = 1.0) -> void:
	var background := TextureRect.new()
	background.name = node_name
	background.texture = load(Tokens.DETAIL_BACKGROUND_PATH)
	background.modulate = Color(brightness, brightness, brightness)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _inset(control: Control, horizontal: float, vertical: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = horizontal
	control.offset_right = -horizontal
	control.offset_top = vertical
	control.offset_bottom = -vertical

func _build_surface(profile: Profile, viewport: Vector2, ui: RefCounted) -> void:
	body = VBoxContainer.new()
	match profile:
		Profile.LANDSCAPE_CARD:
			z_index = 350
			_shade(Color(Tokens.SURFACE, 0.9))
			_background("DetailBackground", 0.8)
			var frame := Panel.new()
			frame.name = "DetailFrame"
			frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := Styles.make_textured_panel_style(Tokens.SURFACE, Tokens.BORDER, 0, false) as StyleBoxTexture
			style.draw_center = false
			frame.add_theme_stylebox_override("panel", style)
			add_child(frame)
			_inset(body, 24, 12)
			add_child(body)
		Profile.BATTLE_INFO:
			name = "BattleChoiceDialog"
			z_index = 350
			_shade(Tokens.SURFACE)
			_background("DetailBackground", 0.65)
			var margin := MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var horizontal := maxi(24, int((viewport.x - 960) / 2))
			for side in ["left", "right"]:
				margin.add_theme_constant_override("margin_" + side, horizontal)
			for side in ["top", "bottom"]:
				margin.add_theme_constant_override("margin_" + side, 20)
			add_child(margin)
			var panel := PanelContainer.new()
			panel.add_theme_stylebox_override("panel", Styles.make_textured_panel_style(Color(Tokens.SURFACE, 0.88), Tokens.BORDER, 16, false))
			margin.add_child(panel)
			body.add_theme_constant_override("separation", 12)
			panel.add_child(body)
		Profile.ECONOMY:
			name = "EconomyDetailOverlay"
			_background("DetailSceneBackdrop")
			_shade(Color(Tokens.SURFACE, 0.46))
			var panel: PanelContainer = ui.make_surface_panel(Tokens.SURFACE, Tokens.BORDER, 1, 8, 12)
			panel.name = "EconomyDetailPanel"
			add_child(panel)
			_inset(panel, maxf(12, (viewport.x - 1040) * 0.5), maxf(8, (viewport.y - 620) * 0.5))
			body.add_theme_constant_override("separation", 8)
			panel.add_child(body)
		Profile.COLLECTION:
			_shade(Color(0.015, 0.025, 0.04, 0.97))
			_inset(body, 24, 16)
			add_child(body)
		Profile.LEGACY_BATTLE:
			z_index = 300
			_shade(Color(0.006, 0.01, 0.02, 0.9))
			_inset(body, 16, 16)
			add_child(body)

func _build_content(profile: Profile) -> void:
	if title_label != null:
		header = HBoxContainer.new()
		body.add_child(header)
		header.add_child(title_label)
		header.add_child(close_button)
	else:
		body.add_child(close_button)
	var scroll_parent: Control = body
	if profile == Profile.LANDSCAPE_CARD:
		media = HBoxContainer.new()
		media.size_flags_vertical = Control.SIZE_EXPAND_FILL
		media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		media.add_theme_constant_override("separation", 20)
		body.add_child(media)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		media.add_child(right)
		scroll_parent = right
	var horizontal_mode := ScrollContainer.SCROLL_MODE_AUTO if profile == Profile.COLLECTION else ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_name := ""
	if profile in [Profile.LANDSCAPE_CARD, Profile.BATTLE_INFO]:
		scroll_name = "CardDetailScroll"
	elif profile == Profile.ECONOMY:
		scroll_name = "EconomyDetailScroll"
	scroll = _ui.make_scroll(scroll_parent, horizontal_mode, profile == Profile.ECONOMY, scroll_name)
	content = scroll
	if profile in [Profile.ECONOMY, Profile.COLLECTION]:
		var column: VBoxContainer = _ui.make_content_column(8 if profile == Profile.ECONOMY else -1)
		scroll.add_child(column)
		content = column
	if profile in [Profile.LANDSCAPE_CARD, Profile.ECONOMY]:
		actions = _ui.make_action_row()
		scroll_parent.add_child(actions)
