class_name CotcInventoryKeyboardInput
extends Node


@onready var _inventory: CotcInventoryOverlay = get_parent() as CotcInventoryOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	if _inventory != null and not _inventory.inventory_opened.is_connected(_on_inventory_opened):
		_inventory.inventory_opened.connect(_on_inventory_opened)


func _input(event: InputEvent) -> void:
	if _inventory == null or not _inventory.is_open():
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"inventory"):
		_inventory.close_inventory()
		_accept_event()
		return

	var no_modifiers: bool = (
		not key_event.alt_pressed
		and not key_event.ctrl_pressed
		and not key_event.meta_pressed
		and not key_event.shift_pressed
	)
	if no_modifiers:
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
				_accept_event()
				return
		_accept_event()
		return

	# While the inventory is open, no modified keyboard input is allowed to leak
	# through to Hylas or another gameplay controller.
	_accept_event()


func _on_inventory_opened() -> void:
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		var hylas: CharacterBody2D = candidate as CharacterBody2D
		if hylas == null:
			continue
		_stop_hylas_motion(hylas)


func _stop_hylas_motion(hylas: CharacterBody2D) -> void:
	hylas.velocity = Vector2.ZERO
	var properties: Dictionary = {}
	for property_info: Dictionary in hylas.get_property_list():
		properties[StringName(str(property_info.get("name", "")))] = true

	_set_property_if_present(hylas, properties, &"_swim_velocity", Vector2.ZERO)
	_set_property_if_present(hylas, properties, &"_burst_coast_velocity", Vector2.ZERO)
	_set_property_if_present(hylas, properties, &"_special_velocity", Vector2.ZERO)
	_set_property_if_present(hylas, properties, &"_burst_active", false)
	_set_property_if_present(hylas, properties, &"_burst_elapsed", 0.0)
	_set_property_if_present(hylas, properties, &"_burst_remaining", 0.0)
	_set_property_if_present(hylas, properties, &"_brake_active", false)
	_set_property_if_present(hylas, properties, &"_pending_surface_jump", false)
	_set_property_if_present(hylas, properties, &"_tail_flip_remaining", 0.0)
	_set_property_if_present(hylas, properties, &"_jump_elapsed", 0.0)
	_set_property_if_present(hylas, properties, &"_tail_flip_combo_frame", false)
	_set_property_if_present(hylas, properties, &"_shift_space_tail_flip_requested", false)
	_set_property_if_present(hylas, properties, &"_tail_flip_chord_active", false)

	if hylas.has_method(&"_stop_movement_audio"):
		hylas.call(&"_stop_movement_audio")
	var sprite: AnimatedSprite2D = hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if sprite != null and sprite.animation in [&"swim", &"burst", &"tail_flip", &"jump", &"stop"]:
		if hylas.has_method(&"_set_visual_rotation"):
			hylas.call(&"_set_visual_rotation", 0.0)
		if hylas.has_method(&"_set_animation"):
			hylas.call(&"_set_animation", &"idle")

	var action_vfx: Node = hylas.get_node_or_null("ActionVFX")
	if action_vfx != null and action_vfx.has_method(&"clear_effects"):
		action_vfx.call(&"clear_effects")


func _set_property_if_present(
		target: Object,
		properties: Dictionary,
		property_name: StringName,
		value: Variant,
	) -> void:
	if properties.has(property_name):
		target.set(property_name, value)


func _accept_event() -> void:
	get_viewport().set_input_as_handled()
