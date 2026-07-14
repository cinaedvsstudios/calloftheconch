extends "res://rebuild_v3/app/contexts/gameplay/gameplay_equipment_input.gd"

@export_range(0.15, 0.8, 0.01) var inventory_double_tap_window: float = 0.36

var _last_inventory_tap_msec: int = -100000

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed(&"utility_item", false, true):
		_last_inventory_tap_msec = -100000
		super._unhandled_input(event)
		return

	if event.is_action_pressed(&"inventory", false, true):
		_inventory_candidate = false
		var now_msec: int = Time.get_ticks_msec()
		var elapsed: float = float(now_msec - _last_inventory_tap_msec) / 1000.0
		if elapsed <= inventory_double_tap_window:
			_last_inventory_tap_msec = -100000
			if _can_use_equipped_items():
				open_inventory()
		else:
			_last_inventory_tap_msec = now_msec
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released(&"inventory", false, true):
		_inventory_candidate = false
		get_viewport().set_input_as_handled()
		return

	super._unhandled_input(event)
