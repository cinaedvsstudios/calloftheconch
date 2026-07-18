class_name CotcInventoryKeyboardInput
extends Node


@onready var _inventory: CotcInventoryOverlay = get_parent() as CotcInventoryOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _inventory == null or not _inventory.is_open():
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if event.is_action_pressed(&"pause", false, true) or event.is_action_pressed(&"inventory", false, true):
		_inventory.close_inventory()
		_accept_event()
		return

	var no_modifiers: bool = (
		not key_event.alt_pressed
		and not key_event.ctrl_pressed
		and not key_event.meta_pressed
		and not key_event.shift_pressed
	)
	if not no_modifiers:
		return

	match key_event.keycode:
		KEY_LEFT:
			_inventory.call(&"_move_selection", Vector2i.LEFT)
		KEY_RIGHT:
			_inventory.call(&"_move_selection", Vector2i.RIGHT)
		KEY_UP:
			_inventory.call(&"_move_selection", Vector2i.UP)
		KEY_DOWN:
			_inventory.call(&"_move_selection", Vector2i.DOWN)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_inventory.call(&"_equip_selected_item")
		_:
			return

	_accept_event()


func _accept_event() -> void:
	get_viewport().set_input_as_handled()
