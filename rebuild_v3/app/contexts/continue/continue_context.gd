class_name CotcContinueContext
extends Control

signal load_requested(save_id: String)
signal back_requested

const CYAN_GLOW: Color = Color(0.20, 1.0, 1.0, 1.0)
const SAVE_ROW_TEXT: Color = Color(0.88, 0.95, 1.0, 1.0)
const SAVE_ROW_BACKGROUND: Color = Color(0.015, 0.045, 0.075, 0.46)
const SAVE_ROW_SELECTED_BACKGROUND: Color = Color(0.015, 0.16, 0.20, 0.72)

@onready var _water_background: CotcWaterVideoBackground = %WaterVideoBackground
@onready var _save_scroll: ScrollContainer = %SaveScroll
@onready var _save_list: VBoxContainer = %SaveList
@onready var _empty_label: Label = %EmptyLabel
@onready var _status_label: Label = %StatusLabel
@onready var _load_button: TextureButton = %LoadButton
@onready var _delete_button: TextureButton = %DeleteButton
@onready var _back_button: TextureButton = %BackButton
@onready var _confirm_overlay: Control = %ConfirmOverlay
@onready var _confirm_label: Label = %ConfirmLabel
@onready var _confirm_delete_button: TextureButton = %ConfirmDeleteButton
@onready var _confirm_cancel_button: TextureButton = %ConfirmCancelButton

var _save_service: CotcSaveService
var _save_entries: Array[Dictionary] = []
var _save_rows: Array[Button] = []
var _selected_index: int = -1
var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_button.pressed.connect(_request_selected_load)
	_delete_button.pressed.connect(_open_delete_confirmation)
	_back_button.pressed.connect(_request_back)
	_confirm_delete_button.pressed.connect(_confirm_delete)
	_confirm_cancel_button.pressed.connect(_close_delete_confirmation)
	_configure_action_button(_load_button)
	_configure_action_button(_delete_button)
	_configure_action_button(_back_button)
	_configure_action_button(_confirm_delete_button)
	_configure_action_button(_confirm_cancel_button)
	_confirm_overlay.hide()
	hide()


func bind_save_service(save_service: CotcSaveService) -> void:
	_save_service = save_service
	if _save_service != null and not _save_service.saves_changed.is_connected(_refresh_saves):
		_save_service.saves_changed.connect(_refresh_saves)


func activate() -> void:
	_active = true
	show()
	_water_background.play_background()
	_confirm_overlay.hide()
	_status_label.text = ""
	_refresh_saves()
	if _save_entries.is_empty():
		_back_button.grab_focus()
	else:
		_load_button.grab_focus()


func deactivate() -> void:
	_active = false
	_confirm_overlay.hide()
	_water_background.stop_background()
	hide()


func show_load_error(message: String) -> void:
	_status_label.text = message


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _confirm_overlay.visible:
		if event.is_action_pressed(&"ui_cancel"):
			_close_delete_confirmation()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_up"):
		_select_relative(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		_select_relative(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and _selected_index >= 0:
		_request_selected_load()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()


func _refresh_saves() -> void:
	for child: Node in _save_list.get_children():
		child.free()
	_save_rows.clear()
	_save_entries.clear()
	_selected_index = -1

	if _save_service != null:
		_save_entries = _save_service.list_saves()
	_empty_label.visible = _save_entries.is_empty()

	for index: int in range(_save_entries.size()):
		var row: Button = _create_save_row(_save_entries[index], index)
		_save_list.add_child(row)
		_save_rows.append(row)

	_set_action_buttons_enabled(not _save_entries.is_empty())
	if not _save_entries.is_empty():
		_select_index(0)


func _create_save_row(save_data: Dictionary, index: int) -> Button:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(0.0, 112.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_font_size_override(&"font_size", 16)
	row.add_theme_color_override(&"font_color", SAVE_ROW_TEXT)
	row.add_theme_color_override(&"font_hover_color", Color.WHITE)
	row.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	row.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	row.add_theme_constant_override(&"shadow_offset_x", 2)
	row.add_theme_constant_override(&"shadow_offset_y", 2)
	row.text = _format_save_row(save_data)
	row.mouse_entered.connect(_on_save_row_hovered.bind(index))
	row.pressed.connect(_on_save_row_pressed.bind(index))
	_apply_save_row_style(row, false)
	return row


func _format_save_row(save_data: Dictionary) -> String:
	var metadata: Dictionary = {}
	var metadata_value: Variant = save_data.get("metadata", {})
	if typeof(metadata_value) == TYPE_DICTIONARY:
		metadata = metadata_value as Dictionary
	var save_name: String = str(save_data.get("name", "Saved Game"))
	var location: String = str(metadata.get("location", "Unknown location"))
	var date_text: String = str(save_data.get("saved_at_text", "Unknown date"))
	var playtime: String = str(metadata.get("playtime_text", "00:00:00"))
	var saved_onos: int = int(metadata.get("onos", 0))
	var current_fins: int = int(metadata.get("current_fins", 0))
	var maximum_fins: int = int(metadata.get("max_fins", 0))
	var star_count: int = int(metadata.get("star_piece_count", 0))
	return "%s\n%s\n%s  •  %s\n%d Onos  •  Fins %d/%d  •  Stars %d" % [
		save_name,
		location,
		date_text,
		playtime,
		saved_onos,
		current_fins,
		maximum_fins,
		star_count,
	]


func _make_save_row_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SAVE_ROW_SELECTED_BACKGROUND if selected else SAVE_ROW_BACKGROUND
	style.border_color = CYAN_GLOW if selected else Color(0.20, 0.62, 0.68, 0.60 if hovered else 0.22)
	var border_width: int = 3 if selected else (1 if hovered else 0)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	if selected:
		style.shadow_color = Color(0.15, 1.0, 1.0, 0.55)
		style.shadow_size = 8
	return style


func _apply_save_row_style(row: Button, selected: bool) -> void:
	row.add_theme_stylebox_override(&"normal", _make_save_row_style(selected))
	row.add_theme_stylebox_override(&"hover", _make_save_row_style(selected, true))
	row.add_theme_stylebox_override(&"pressed", _make_save_row_style(selected, true))
	row.add_theme_stylebox_override(&"disabled", _make_save_row_style(selected))


func _on_save_row_hovered(index: int) -> void:
	_select_index(index)


func _on_save_row_pressed(index: int) -> void:
	_select_index(index)


func _select_relative(direction: int) -> void:
	if _save_entries.is_empty():
		return
	var next_index: int = _selected_index + direction
	if next_index < 0:
		next_index = _save_entries.size() - 1
	elif next_index >= _save_entries.size():
		next_index = 0
	_select_index(next_index)


func _select_index(index: int) -> void:
	if index < 0 or index >= _save_entries.size():
		_selected_index = -1
		_set_action_buttons_enabled(false)
		return
	_selected_index = index
	for row_index: int in range(_save_rows.size()):
		var selected: bool = row_index == _selected_index
		var row: Button = _save_rows[row_index]
		row.modulate = Color.WHITE
		_apply_save_row_style(row, selected)
	_set_action_buttons_enabled(true)
	call_deferred(&"_ensure_selected_visible")


func _ensure_selected_visible() -> void:
	if not _active or _selected_index < 0 or _selected_index >= _save_rows.size():
		return
	var selected_row: Button = _save_rows[_selected_index]
	if is_instance_valid(selected_row):
		_save_scroll.ensure_control_visible(selected_row)


func _configure_action_button(button: TextureButton) -> void:
	button.mouse_entered.connect(_refresh_action_button_glow.bind(button))
	button.mouse_exited.connect(_refresh_action_button_glow.bind(button))
	button.focus_entered.connect(_refresh_action_button_glow.bind(button))
	button.focus_exited.connect(_refresh_action_button_glow.bind(button))
	_refresh_action_button_glow(button)


func _refresh_action_button_glow(button: TextureButton) -> void:
	var label: Label = button.get_node_or_null("Label") as Label
	if label == null:
		return
	var active: bool = button.is_hovered() or button.has_focus()
	label.add_theme_color_override(
		&"font_outline_color",
		Color(0.12, 1.0, 1.0, 0.95) if active else Color(0.0, 0.0, 0.0, 0.82),
	)
	label.add_theme_constant_override(&"outline_size", 7 if active else 2)
	label.add_theme_color_override(
		&"font_shadow_color",
		Color(0.12, 1.0, 1.0, 0.72) if active else Color(0.0, 0.0, 0.0, 0.9),
	)
	label.add_theme_constant_override(&"shadow_offset_x", 0 if active else 2)
	label.add_theme_constant_override(&"shadow_offset_y", 0 if active else 2)


func _set_action_buttons_enabled(enabled: bool) -> void:
	_load_button.disabled = not enabled
	_delete_button.disabled = not enabled


func _request_selected_load() -> void:
	var selected: Dictionary = _get_selected_save()
	if selected.is_empty():
		_status_label.text = "Select a saved game first."
		return
	_status_label.text = ""
	load_requested.emit(str(selected.get("save_id", "")))


func _open_delete_confirmation() -> void:
	var selected: Dictionary = _get_selected_save()
	if selected.is_empty():
		return
	_confirm_label.text = "Delete ‘%s’?\nThis cannot be undone." % str(selected.get("name", "Saved Game"))
	_confirm_overlay.show()
	_confirm_cancel_button.grab_focus()


func _close_delete_confirmation() -> void:
	_confirm_overlay.hide()
	_delete_button.grab_focus()


func _confirm_delete() -> void:
	var selected: Dictionary = _get_selected_save()
	if selected.is_empty() or _save_service == null:
		_close_delete_confirmation()
		return
	var deleted: bool = _save_service.delete_save(str(selected.get("save_id", "")))
	_confirm_overlay.hide()
	if not deleted:
		_status_label.text = _save_service.last_error_message
		return
	_status_label.text = "Saved game deleted."
	_refresh_saves()


func _get_selected_save() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _save_entries.size():
		return {}
	return _save_entries[_selected_index]


func _request_back() -> void:
	back_requested.emit()


func get_debug_lines() -> Array[String]:
	return [
		"[ContinueContext]",
		"visible=%s" % str(visible),
		"save_count=%d" % _save_entries.size(),
		"selected_index=%d" % _selected_index,
		"background_playing=%s" % str(_water_background.is_background_playing()),
	]
