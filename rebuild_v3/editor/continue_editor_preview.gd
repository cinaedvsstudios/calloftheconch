@tool
extends Node

@export_category("Editor Preview")
@export var preview_first_save_name: String = "Sea of Pillars"
@export var preview_second_save_name: String = "Neresithoppos"
@export var preview_selected_entry: int = 0

var _last_signature: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_refresh_preview(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_preview(false)


func _refresh_preview(force: bool) -> void:
	var root: Control = get_parent() as Control
	if root == null:
		return
	var signature_values: Array = [
		root.get("save_entry_width"),
		root.get("save_entry_height"),
		root.get("save_entry_spacing"),
		root.get("save_list_top_margin"),
		root.get("save_list_bottom_margin"),
		root.get("save_entry_font_size"),
		root.get("save_entry_content_margins"),
		root.get("save_entry_corner_radius"),
		root.get("save_text_color"),
		root.get("save_hover_text_color"),
		root.get("save_text_shadow_color"),
		root.get("save_text_shadow_offset"),
		root.get("save_background_color"),
		root.get("save_selected_background_color"),
		root.get("save_hover_border_color"),
		root.get("save_selected_border_color"),
		root.get("save_hover_border_width"),
		root.get("save_selected_border_width"),
		root.get("save_selected_glow_color"),
		root.get("save_selected_glow_size"),
		preview_first_save_name,
		preview_second_save_name,
		preview_selected_entry,
	]
	var signature: int = hash(signature_values)
	if not force and signature == _last_signature:
		return
	_last_signature = signature

	var save_frame: TextureRect = root.get_node_or_null("SaveFrame") as TextureRect
	var save_scroll: ScrollContainer = root.get_node_or_null("SaveFrame/SaveScroll") as ScrollContainer
	var save_list: VBoxContainer = root.get_node_or_null("SaveFrame/SaveScroll/SaveList") as VBoxContainer
	var empty_label: Label = root.get_node_or_null("SaveFrame/EmptyLabel") as Label
	var confirm_overlay: Control = root.get_node_or_null("ConfirmOverlay") as Control
	if save_frame == null or save_scroll == null or save_list == null:
		return

	var frame_width: float = save_frame.size.x
	if frame_width <= 0.0:
		frame_width = absf(save_frame.offset_right - save_frame.offset_left)
	var entry_width: float = clampf(float(root.get("save_entry_width")), 80.0, maxf(80.0, frame_width))
	var side_margin: float = maxf(0.0, (frame_width - entry_width) * 0.5)
	save_scroll.offset_left = side_margin
	save_scroll.offset_right = -side_margin
	save_scroll.offset_top = float(root.get("save_list_top_margin"))
	save_scroll.offset_bottom = -float(root.get("save_list_bottom_margin"))
	save_list.custom_minimum_size = Vector2(entry_width, 0.0)
	save_list.add_theme_constant_override(&"separation", int(root.get("save_entry_spacing")))

	for child: Node in save_list.get_children():
		if child.name.begins_with("__EditorSavePreview"):
			child.free()

	var preview_rows: Array[Dictionary] = [
		{
			"name": preview_first_save_name,
			"location": "The Sea of Pillars",
			"date": "14 July 2026  •  01:42:18",
			"stats": "18 Onos  •  Fins 4/4  •  Stars 1",
		},
		{
			"name": preview_second_save_name,
			"location": "The Agora of Myra",
			"date": "13 July 2026  •  00:57:03",
			"stats": "7 Onos  •  Fins 3/4  •  Stars 0",
		},
	]
	for index: int in range(preview_rows.size()):
		var row: Button = _create_preview_row(root, preview_rows[index], entry_width, index == preview_selected_entry)
		row.name = "__EditorSavePreview%02d" % index
		save_list.add_child(row)
	if empty_label != null:
		empty_label.visible = false
	if confirm_overlay != null:
		confirm_overlay.visible = false
	_preview_action_button(root, "ActionButtons/LoadButton", true)
	_preview_action_button(root, "ActionButtons/DeleteButton", false)
	_preview_action_button(root, "ActionButtons/BackButton", false)


func _create_preview_row(root: Control, data: Dictionary, width: float, selected: bool) -> Button:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(width, float(root.get("save_entry_height")))
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override(&"font_size", int(root.get("save_entry_font_size")))
	row.add_theme_color_override(&"font_color", root.get("save_text_color"))
	row.add_theme_color_override(&"font_hover_color", root.get("save_hover_text_color"))
	row.add_theme_color_override(&"font_pressed_color", root.get("save_hover_text_color"))
	row.add_theme_color_override(&"font_shadow_color", root.get("save_text_shadow_color"))
	var shadow_offset: Vector2i = root.get("save_text_shadow_offset")
	row.add_theme_constant_override(&"shadow_offset_x", shadow_offset.x)
	row.add_theme_constant_override(&"shadow_offset_y", shadow_offset.y)
	row.text = "%s\n%s\n%s\n%s" % [
		str(data.get("name", "Saved Game")),
		str(data.get("location", "Unknown location")),
		str(data.get("date", "Unknown date")),
		str(data.get("stats", "")),
	]
	var normal_style: StyleBoxFlat = _make_style(root, selected, false)
	var hover_style: StyleBoxFlat = _make_style(root, selected, true)
	row.add_theme_stylebox_override(&"normal", normal_style)
	row.add_theme_stylebox_override(&"hover", hover_style)
	row.add_theme_stylebox_override(&"pressed", hover_style)
	row.add_theme_stylebox_override(&"disabled", normal_style)
	return row


func _make_style(root: Control, selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = root.get("save_selected_background_color") if selected else root.get("save_background_color")
	style.border_color = root.get("save_selected_border_color") if selected else root.get("save_hover_border_color")
	var border_width: int = int(root.get("save_selected_border_width")) if selected else (int(root.get("save_hover_border_width")) if hovered else 0)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	var corner_radius: int = int(root.get("save_entry_corner_radius"))
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	var margins: Vector4 = root.get("save_entry_content_margins")
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	if selected:
		style.shadow_color = root.get("save_selected_glow_color")
		style.shadow_size = int(root.get("save_selected_glow_size"))
	return style


func _preview_action_button(root: Control, path: String, active: bool) -> void:
	var button: TextureButton = root.get_node_or_null(path) as TextureButton
	if button == null:
		return
	var label: Label = button.get_node_or_null("Label") as Label
	if label == null:
		return
	label.add_theme_color_override(
		&"font_outline_color",
		root.get("action_glow_outline_color") if active else root.get("action_rest_outline_color"),
	)
	label.add_theme_constant_override(
		&"outline_size",
		int(root.get("action_glow_outline_size")) if active else int(root.get("action_rest_outline_size")),
	)
	label.add_theme_color_override(
		&"font_shadow_color",
		root.get("action_glow_shadow_color") if active else root.get("action_rest_shadow_color"),
	)
	var rest_offset: Vector2i = root.get("action_rest_shadow_offset")
	label.add_theme_constant_override(&"shadow_offset_x", 0 if active else rest_offset.x)
	label.add_theme_constant_override(&"shadow_offset_y", 0 if active else rest_offset.y)
