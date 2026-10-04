extends RefCounted

const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Styles = preload("res://src/ui/styles/ui_styles.gd")
const BattleStyles = preload("res://src/ui/styles/battle_styles.gd")
const Factory = preload("res://src/ui/ui_factory.gd")
var failures: Array[String] = []
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value: failures.append(message)

func run() -> Dictionary:
	check(ResourceLoader.exists(Tokens.TABLETOP_PATH), "tabletop asset is bundled")
	check(Tokens.FONT_TITLE == 24 and Tokens.FONT_BODY == 16 and Tokens.FONT_CAPTION == 14, "shared typography hierarchy")
	var factory := Factory.new()
	for mode in ["hand", "field", "reward", "shop", "collection"]:
		var metrics := Tokens.card_metrics(mode, true, true)
		for key in ["title_font", "identity_font", "summary_font", "detail_font"]:
			check(metrics[key] >= 14, "card typography minimum " + mode + " " + key)
	var filters := factory.make_filter_bar(["전체", "인간"], "인간", self, "filter_selected", false)
	check(filters.get_child(1).button_pressed and filters.get_child(1).icon != null, "active filter has persistent non-color indicator")
	check(not filters.get_child(0).button_pressed, "inactive filter stays unselected")
	filters.free()
	for role in ["primary", "secondary", "danger", "power", "turn"]:
		var button := Button.new()
		button.text = "선택 확인"
		factory.style_role_button(button, role)
		check(button.custom_minimum_size.y >= 44, "touch target " + role)
		var normal: StyleBox = button.get_theme_stylebox("normal")
		check(normal is StyleBoxTexture, "shared material " + role)
		for state in ["hover", "pressed", "disabled", "focus"]:
			check(button.get_theme_stylebox(state).get_minimum_size() == normal.get_minimum_size(), "stable geometry " + role + " " + state)
		button.free()
	var battle_button := Button.new()
	BattleStyles.apply_battle_button(battle_button, Color.RED, Color.BLUE, false, "turn")
	var style := battle_button.get_theme_stylebox("normal") as StyleBoxTexture
	check(style != null and style.texture.resource_path == Styles.BUTTON_GOLD_PATH, "turn end shares primary material")
	battle_button.free()
	for accent in [Color.RED, Color.BLUE, Color.GREEN]:
		var panel := Styles.make_textured_panel_style(Tokens.SURFACE, accent, 12) as StyleBoxTexture
		check(panel.texture.resource_path.ends_with("panel_silver.svg"), "panels share silver material")
		check(panel.texture_margin_left == panel.texture_margin_right, "symmetric nine slice")
	return {"count": count, "failures": failures}

func filter_selected(_value: String) -> void:
	pass
