class_name CotcInventoryOverlay
extends Control

signal inventory_opened
signal inventory_closed
signal item_equipped(slot_id: StringName, item_id: StringName)

const ITEM_CATALOG = preload("res://rebuild_v3/app/inventory/item_catalog.gd")

const SLOT_A: StringName = &"item_a"
const SLOT_B: StringName = &"item_b"
const GRID_COLUMNS: int = 3
const CELL_SIZE: Vector2 = Vector2(112.0, 116.0)
const MAGENTA: Color = Color(0.96, 0.15, 0.78, 1.0)
const CYAN: Color = Color(0.10, 0.88, 1.0, 1.0)

@onready var _close_button: Button = %CloseButton
@onready var _item_scroll: ScrollContainer = %ItemScroll
@onready var _item_a_grid: GridContainer = %ItemAGrid
@onready var _item_b_grid: GridContainer = %ItemBGrid
@onready var _item_a_empty: Label = %ItemAEmpty
@onready var _item_b_empty: Label = %ItemBEmpty

var _game_state: CotcGameState
var _is_open: bool = false
var _selected_item_id: StringName = &""
var _item_ids: Array[StringName] = []
var _item_cells: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(close_inventory)
	hide()


func bind_game_state(game_state: CotcGameState) -> void:
	if _game_state != null:
		_disconnect_game_state()
	_game_state = game_state
	if _game_state != null:
		_connect_game_state()
	if _is_open:
		_rebuild_items()


func open_inventory() -> void:
	if _is_open or _game_state == null:
		return
	_is_open = true
	_rebuild_items()
	show()
	inventory_opened.emit()


func close_inventory() -> void:
	if not _is_open:
		return
	_is_open = false
	hide()
	inventory_closed.emit()


func is_open() -> bool:
	return _is_open


func get_selected_item_id() -> StringName:
	return _selected_item_id


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed(&"pause"):
		close_inventory()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"move_left"):
		_move_selection(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_right"):
		_move_selection(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_up"):
		_move_selection(Vector2i.UP)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_down"):
		_move_selection(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"conch"):
		_equip_selected_item()
		get_viewport().set_input_as_handled()


func _connect_game_state() -> void:
	if not _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
	if not _game_state.inventory_changed.is_connected(_on_inventory_changed):
		_game_state.inventory_changed.connect(_on_inventory_changed)
	if not _game_state.permanent_inventory_changed.is_connected(_on_permanent_inventory_changed):
		_game_state.permanent_inventory_changed.connect(_on_permanent_inventory_changed)
	if not _game_state.shells_changed.is_connected(_on_shells_changed):
		_game_state.shells_changed.connect(_on_shells_changed)
	if not _game_state.star_pieces_changed.is_connected(_on_star_pieces_changed):
		_game_state.star_pieces_changed.connect(_on_star_pieces_changed)
	if not _game_state.state_replaced.is_connected(_on_state_replaced):
		_game_state.state_replaced.connect(_on_state_replaced)


func _disconnect_game_state() -> void:
	if _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)
	if _game_state.inventory_changed.is_connected(_on_inventory_changed):
		_game_state.inventory_changed.disconnect(_on_inventory_changed)
	if _game_state.permanent_inventory_changed.is_connected(_on_permanent_inventory_changed):
		_game_state.permanent_inventory_changed.disconnect(_on_permanent_inventory_changed)
	if _game_state.shells_changed.is_connected(_on_shells_changed):
		_game_state.shells_changed.disconnect(_on_shells_changed)
	if _game_state.star_pieces_changed.is_connected(_on_star_pieces_changed):
		_game_state.star_pieces_changed.disconnect(_on_star_pieces_changed)
	if _game_state.state_replaced.is_connected(_on_state_replaced):
		_game_state.state_replaced.disconnect(_on_state_replaced)


func _rebuild_items() -> void:
	var previous_selection: StringName = _selected_item_id
	_clear_grid(_item_a_grid)
	_clear_grid(_item_b_grid)
	_item_ids.clear()
	_item_cells.clear()

	var item_a_ids: Array[StringName] = []
	var item_b_ids: Array[StringName] = []
	for item_id: StringName in ITEM_CATALOG.get_all_item_ids():
		if not _game_state.is_item_owned(item_id):
			continue
		var slot_id: StringName = ITEM_CATALOG.get_slot(item_id)
		if slot_id == SLOT_A:
			item_a_ids.append(item_id)
		elif slot_id == SLOT_B:
			item_b_ids.append(item_id)

	_item_a_empty.visible = item_a_ids.is_empty()
	_item_b_empty.visible = item_b_ids.is_empty()

	var nav_row: int = 0
	_add_item_group(_item_a_grid, item_a_ids, nav_row)
	nav_row += maxi(1, ceili(float(item_a_ids.size()) / float(GRID_COLUMNS))) + 1
	_add_item_group(_item_b_grid, item_b_ids, nav_row)

	if _item_ids.is_empty():
		_selected_item_id = &""
		return

	if not String(previous_selection).is_empty() and _item_cells.has(String(previous_selection)):
		_selected_item_id = previous_selection
	else:
		var equipped_a: StringName = _game_state.get_equipped_item(SLOT_A)
		var equipped_b: StringName = _game_state.get_equipped_item(SLOT_B)
		if _item_cells.has(String(equipped_a)):
			_selected_item_id = equipped_a
		elif _item_cells.has(String(equipped_b)):
			_selected_item_id = equipped_b
		else:
			_selected_item_id = _item_ids[0]

	_refresh_cell_states()


func _add_item_group(
		grid: GridContainer,
		item_ids: Array[StringName],
		start_row: int,
	) -> void:
	for group_index: int in range(item_ids.size()):
		var item_id: StringName = item_ids[group_index]
		var nav_position: Vector2i = Vector2i(
			group_index % GRID_COLUMNS,
			start_row + floori(float(group_index) / float(GRID_COLUMNS)),
		)
		var cell: Control = _create_item_cell(item_id, nav_position)
		grid.add_child(cell)
		_item_ids.append(item_id)


func _create_item_cell(item_id: StringName, nav_position: Vector2i) -> Control:
	var definition: Dictionary = ITEM_CATALOG.get_item(item_id)

	var cell: Control = Control.new()
	cell.name = "Item_%s" % String(item_id)
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background: Panel = Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override(&"panel", _make_cell_background_style())
	cell.add_child(background)

	var equipped_frame: Panel = Panel.new()
	equipped_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipped_frame.offset_left = 5.0
	equipped_frame.offset_top = 5.0
	equipped_frame.offset_right = -5.0
	equipped_frame.offset_bottom = -5.0
	equipped_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipped_frame.z_index = 2
	equipped_frame.add_theme_stylebox_override(&"panel", _make_frame_style(CYAN, 3))
	cell.add_child(equipped_frame)

	var selector_frame: Panel = Panel.new()
	selector_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selector_frame.z_index = 3
	selector_frame.add_theme_stylebox_override(&"panel", _make_frame_style(MAGENTA, 4))
	cell.add_child(selector_frame)

	var button: Button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_on_item_mouse_entered.bind(item_id))
	button.pressed.connect(_on_item_pressed.bind(item_id))
	cell.add_child(button)

	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 9.0
	content.offset_top = 8.0
	content.offset_right = -9.0
	content.offset_bottom = -7.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 3)
	button.add_child(content)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(68.0, 68.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = str(definition.get("icon_path", ""))
	if not icon_path.is_empty():
		icon.texture = load(icon_path) as Texture2D
	content.add_child(icon)

	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(definition.get("display_name", String(item_id)))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override(&"font_size", 13)
	name_label.add_theme_color_override(&"font_color", Color(0.93, 0.90, 0.78, 1.0))
	content.add_child(name_label)

	var quantity_label: Label = Label.new()
	quantity_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantity_label.offset_left = -35.0
	quantity_label.offset_top = 7.0
	quantity_label.offset_right = -8.0
	quantity_label.offset_bottom = 32.0
	quantity_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override(&"font_size", 16)
	quantity_label.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.48, 1.0))
	cell.add_child(quantity_label)

	_item_cells[String(item_id)] = {
		"cell": cell,
		"selector": selector_frame,
		"equipped": equipped_frame,
		"quantity": quantity_label,
		"nav_position": nav_position,
	}
	return cell


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _make_cell_background_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.055, 0.10, 0.76)
	style.border_color = Color(0.31, 0.48, 0.58, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _make_frame_style(color_value: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = color_value
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style


func _refresh_cell_states() -> void:
	if _game_state == null:
		return
	var equipped_a: StringName = _game_state.get_equipped_item(SLOT_A)
	var equipped_b: StringName = _game_state.get_equipped_item(SLOT_B)
	for item_id: StringName in _item_ids:
		var cell_data: Dictionary = _item_cells.get(String(item_id), {})
		var selector: Panel = cell_data.get("selector") as Panel
		var equipped: Panel = cell_data.get("equipped") as Panel
		var quantity: Label = cell_data.get("quantity") as Label
		if selector != null:
			selector.visible = item_id == _selected_item_id
		if equipped != null:
			equipped.visible = item_id == equipped_a or item_id == equipped_b
		if quantity != null:
			if ITEM_CATALOG.item_has_quantity(item_id):
				quantity.text = "×%d" % _game_state.get_inventory_quantity(item_id)
				quantity.show()
			else:
				quantity.text = ""
				quantity.hide()


func _select_item(item_id: StringName) -> void:
	if not _item_cells.has(String(item_id)):
		return
	_selected_item_id = item_id
	_refresh_cell_states()
	call_deferred(&"_ensure_selected_visible")


func _ensure_selected_visible() -> void:
	if not _is_open or not _item_cells.has(String(_selected_item_id)):
		return
	var cell_data: Dictionary = _item_cells.get(String(_selected_item_id), {})
	var cell: Control = cell_data.get("cell") as Control
	if cell != null:
		_item_scroll.ensure_control_visible(cell)


func _move_selection(direction: Vector2i) -> void:
	if _item_ids.is_empty():
		return
	if String(_selected_item_id).is_empty() or not _item_cells.has(String(_selected_item_id)):
		_select_item(_item_ids[0])
		return

	var current_data: Dictionary = _item_cells.get(String(_selected_item_id), {})
	var current_position: Vector2i = current_data.get("nav_position", Vector2i.ZERO)
	var best_item: StringName = &""
	var best_score: float = INF

	for item_id: StringName in _item_ids:
		if item_id == _selected_item_id:
			continue
		var candidate_data: Dictionary = _item_cells.get(String(item_id), {})
		var candidate_position: Vector2i = candidate_data.get("nav_position", Vector2i.ZERO)
		var delta: Vector2i = candidate_position - current_position
		var valid_direction: bool = (
			(direction.x < 0 and delta.x < 0)
			or (direction.x > 0 and delta.x > 0)
			or (direction.y < 0 and delta.y < 0)
			or (direction.y > 0 and delta.y > 0)
		)
		if not valid_direction:
			continue
		var primary_distance: int = absi(delta.x) if direction.x != 0 else absi(delta.y)
		var secondary_distance: int = absi(delta.y) if direction.x != 0 else absi(delta.x)
		var score: float = float(primary_distance * 100 + secondary_distance)
		if score < best_score:
			best_score = score
			best_item = item_id

	if not String(best_item).is_empty():
		_select_item(best_item)


func _equip_selected_item() -> void:
	if String(_selected_item_id).is_empty():
		return
	_equip_item(_selected_item_id)


func _equip_item(item_id: StringName) -> void:
	if _game_state == null:
		return
	var slot_id: StringName = ITEM_CATALOG.get_slot(item_id)
	if not _game_state.equip_item(item_id, slot_id):
		return
	_refresh_cell_states()
	item_equipped.emit(slot_id, item_id)


func _on_item_mouse_entered(item_id: StringName) -> void:
	if _is_open:
		_select_item(item_id)


func _on_item_pressed(item_id: StringName) -> void:
	if not _is_open:
		return
	_select_item(item_id)
	_equip_item(item_id)


func _on_equipped_item_changed(_slot_id: StringName, _item_id: StringName) -> void:
	if _is_open:
		_refresh_cell_states()


func _on_inventory_changed(
		_item_id: StringName,
		_quantity: int,
		_delta: int,
	) -> void:
	if _is_open:
		_rebuild_items()


func _on_permanent_inventory_changed(_item_id: StringName, _owned: bool) -> void:
	if _is_open:
		_rebuild_items()


func _on_shells_changed() -> void:
	if _is_open:
		_rebuild_items()


func _on_star_pieces_changed() -> void:
	if _is_open:
		_rebuild_items()


func _on_state_replaced(_reason: StringName) -> void:
	if _is_open:
		_rebuild_items()


func get_debug_lines() -> Array[String]:
	return [
		"[InventoryOverlay]",
		"open=%s" % str(_is_open),
		"selected_item=%s" % String(_selected_item_id),
		"visible_items=%d" % _item_ids.size(),
	]
