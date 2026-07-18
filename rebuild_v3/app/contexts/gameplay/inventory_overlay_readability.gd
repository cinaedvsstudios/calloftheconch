extends "res://rebuild_v3/app/contexts/gameplay/inventory_overlay.gd"

const SOFT_TEXT_SHADOW: Color = Color(0.03, 0.07, 0.11, 0.50)
const READABLE_CELL_SIZE: Vector2 = Vector2(116.0, 126.0)
const READABLE_ICON_SIZE: Vector2 = Vector2(60.0, 60.0)
const READABLE_NAME_HEIGHT: float = 34.0

var _selection_dirty: bool = false


func open_inventory() -> void:
	if _is_open or _game_state == null:
		return
	# Pause before rebuilding or showing the overlay so no gameplay physics,
	# animation, enemies, currents or background effects receive another frame.
	# The gameplay music player is PROCESS_MODE_ALWAYS and continues normally.
	get_tree().paused = true
	_selection_dirty = false
	super.open_inventory()


func close_inventory() -> void:
	if not _is_open:
		return
	_selection_dirty = false
	super.close_inventory()


func _create_item_cell(item_id: StringName, nav_position: Vector2i) -> Control:
	var cell: Control = super._create_item_cell(item_id, nav_position)
	cell.custom_minimum_size = READABLE_CELL_SIZE
	cell.clip_contents = true
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var button: Button
	for child: Node in cell.get_children():
		var candidate_button: Button = child as Button
		if candidate_button != null:
			button = candidate_button
			break
	if button == null:
		return cell

	button.custom_minimum_size = READABLE_CELL_SIZE
	button.clip_contents = true
	button.tooltip_text = str(ITEM_CATALOG.get_item(item_id).get("display_name", String(item_id)))

	var content: VBoxContainer
	for child: Node in button.get_children():
		var candidate_content: VBoxContainer = child as VBoxContainer
		if candidate_content != null:
			content = candidate_content
			break
	if content == null:
		return cell

	content.clip_contents = true
	content.offset_top = 6.0
	content.offset_bottom = -6.0
	content.add_theme_constant_override(&"separation", 2)

	for child: Node in content.get_children():
		var icon: TextureRect = child as TextureRect
		if icon != null:
			icon.custom_minimum_size = READABLE_ICON_SIZE
			continue
		var name_label: Label = child as Label
		if name_label == null:
			continue
		name_label.custom_minimum_size = Vector2(0.0, READABLE_NAME_HEIGHT)
		name_label.custom_maximum_size = Vector2(98.0, READABLE_NAME_HEIGHT)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override(&"font_size", 12)
		name_label.tooltip_text = name_label.text

	return cell


func _move_selection(direction: Vector2i) -> void:
	var previous_selection: StringName = _selected_item_id
	super._move_selection(direction)
	if _selected_item_id != previous_selection:
		_selection_dirty = true


func _equip_selected_item() -> void:
	super._equip_selected_item()
	_selection_dirty = false


func _on_item_mouse_entered(_item_id: StringName) -> void:
	# Hovering should not silently change the item selected by keyboard input.
	pass


func _on_item_pressed(item_id: StringName) -> void:
	if not _is_open:
		return
	_select_item(item_id)
	_selection_dirty = true


func _apply_label_readability(label: Label, outline_size: int, shadow_spread: int) -> void:
	label.add_theme_color_override(&"font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override(&"outline_size", outline_size)
	label.add_theme_color_override(&"font_shadow_color", SOFT_TEXT_SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 2)
	label.add_theme_constant_override(&"shadow_offset_y", 3)
	label.add_theme_constant_override(&"shadow_outline_size", shadow_spread + 5)
