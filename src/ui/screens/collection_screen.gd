extends RefCounted
class_name CollectionScreen

const Layout = preload("res://src/ui/screens/screen_layout.gd")
const DetailDialog = preload("res://src/ui/components/detail_dialog.gd")
const CardView = preload("res://src/ui/components/card_view.gd")

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact = main._is_compact_layout()
	Layout.back(main, body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	list.add_child(Layout.label(main, "카드 %d종" % main.card_defs.size(), true))
	var filters := ["전체", "보유", "미보유", "인간", "엘프", "언데드", "공용", "변경 원정"]
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(180, 44)
	selector.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for filter in filters:
		selector.add_item(filter)
	selector.select(maxi(0, filters.find(main.collection_filter)))
	selector.item_selected.connect(func(index: int): _set_collection_filter(filters[index]))
	list.add_child(selector)
	var filtered_cards := _filtered_collection_cards()
	var columns := maxi(1, mini(4, int((main._layout_viewport_size().x - 48) / (190 if compact else 244))))
	var row: HBoxContainer = null
	for index in range(filtered_cards.size()):
		if index % columns == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)
		row.add_child(_make_collection_card(filtered_cards[index], compact))


func _set_collection_filter(filter: String) -> void:
	main.collection_filter = filter
	main._show_collection()

func _filtered_collection_cards() -> Array:
	var filtered: Array = []
	var race_filter: String = "중립" if main.collection_filter == "공용" else String(main.collection_filter)
	for card in main.card_defs:
		var owned := int(main.player_profile["owned_cards"].get(String(card.get("id", "")), 0))
		if main.collection_filter == "보유" and owned <= 0:
			continue
		if main.collection_filter == "미보유" and owned > 0:
			continue
		if main.collection_filter == "변경 원정" and card.get("expansion") != "frontier_100":
			continue
		if race_filter not in ["전체", "보유", "미보유", "변경 원정"] and String(card.get("race", "")) != race_filter:
			continue
		filtered.append(card)
	return filtered

func _make_collection_card(card: Dictionary, compact: bool) -> Control:
	var owned := int(main.player_profile["owned_cards"].get(String(card.get("id", "")), 0))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = Vector2(170 if compact else 220, 0)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var width := 170 if compact else 220
	var face := CardView.make_compact_offer(main, card, width, int(width * 1.5))
	if owned <= 0:
		face.modulate = Color(0.45, 0.45, 0.5, 1.0)
	content.add_child(face)
	content.add_child(main._make_label("보유 %d장" % owned, 14, main.ui.UI_TOKENS.TEXT_SECONDARY))
	var inspect: Button = main.ui.make_button("")
	inspect.text = "크게 보기"
	inspect.custom_minimum_size.y = 48
	inspect.pressed.connect(_inspect_card.bind(card))
	content.add_child(inspect)
	return panel

func _collection_lore_text(card: Dictionary) -> String:
	var lore: Dictionary = main.card_lore_service.lore_for(String(card.get("id", "")))
	var story := String(lore.get("story", "")).strip_edges()
	var role := String(lore.get("role", "")).strip_edges()
	var hook := String(lore.get("hook", "")).strip_edges()
	var lines: Array[String] = []
	if not story.is_empty():
		lines.append("스토리: %s" % story)
	if not role.is_empty():
		lines.append("운용: %s" % role)
	if not hook.is_empty():
		lines.append("빌드: %s" % hook)
	if lines.is_empty():
		return String(card.get("text", ""))
	return "\n".join(lines)

func _inspect_card(card: Dictionary) -> void:
	main._clear_modal()
	var close: Button = main.ui.make_button("닫기")
	close.custom_minimum_size.y = 48
	var overlay = DetailDialog.create(main.modal_layer, DetailDialog.Profile.COLLECTION, main._make_label(String(card.name), 24, main.ui.UI_TOKENS.TEXT_PRIMARY), close, main._clear_modal, main._layout_viewport_size(), main.ui)
	var column: Control = overlay.content
	var viewer := preload("res://src/ui/components/card_inspection_view.gd").new()
	var height := clampf(main._layout_viewport_size().y - 116, 160, 470)
	var extent := Vector2(height * 2.0 / 3.0, height)
	var face := CardView.make_compact_offer(main, card, int(extent.x), int(extent.y))
	viewer.setup(face, extent, extent)
	viewer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay.media.add_child(viewer)
	overlay.media.move_child(viewer, 0)
	var description: Label = main._make_label(_collection_lore_text(card), 16, Color(0.9, 0.92, 0.96))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
