extends "res://rebuild_v3/app/contexts/gameplay/gameplay_context.gd"

## Phase 3 equipment input dispatcher.
##
## Item A remains responsible for Hylas's existing interaction timing, while the
## Ctrl-modified utility action is consumed here before it can fall through to
## Item A. Item behavior handlers return true only when an item really activates;
## limited-use Item B quantities are then consumed exactly once.

signal equipped_item_used(slot_id: StringName, item_id: StringName, behavior_id: StringName)
signal equipped_item_use_failed(slot_id: StringName, item_id: StringName, behavior_id: StringName)

const ITEM_CATALOG = preload("res://rebuild_v3/app/inventory/item_catalog.gd")
const SLOT_A: StringName = &"item_a"
const SLOT_B: StringName = &"item_b"
const NORMAL_CONCH_BEHAVIOR: StringName = &"normal_conch"

var _hylas: CotcHylas
var _item_behavior_handlers: Array[Callable] = []
var _warned_missing_behaviors: Dictionary = {}
var _last_item_use_slot: StringName = &""
var _last_item_use_id: StringName = &""
var _last_item_use_succeeded: bool = false


func _ready() -> void:
	super._ready()
	_resolve_hylas()
	_connect_hylas_item_request()
	_sync_equipped_item_a()


func bind_game_state(game_state: CotcGameState) -> void:
	if _game_state != null and _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)

	super.bind_game_state(game_state)

	if _game_state != null and not _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
	_sync_equipped_item_a()


func register_item_behavior_handler(handler: Callable) -> void:
	if not handler.is_valid() or _item_behavior_handlers.has(handler):
		return
	_item_behavior_handlers.append(handler)


func unregister_item_behavior_handler(handler: Callable) -> void:
	_item_behavior_handlers.erase(handler)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	# Resolve the exact chord before the inherited Ctrl-release inventory logic.
	# This guarantees Ctrl+Item A never opens inventory or reaches Hylas as A.
	if event.is_action_pressed(&"utility_item", false, true):
		_inventory_candidate = false
		_cancel_hylas_pending_interaction()
		if _can_use_equipped_items():
			_use_equipped_item_b()
		get_viewport().set_input_as_handled()
		return

	super._unhandled_input(event)


func _can_use_equipped_items() -> bool:
	return (
		_active
		and not _in_city
		and not get_tree().paused
		and not _inventory_overlay.is_open()
		and not _pause_overlay.visible
		and not _death_overlay.is_open()
	)


func _use_equipped_item_b() -> bool:
	if _game_state == null:
		return false
	var item_id: StringName = _game_state.get_equipped_item(SLOT_B)
	if String(item_id).is_empty():
		_record_item_use(SLOT_B, item_id, false)
		return false
	var origin: Vector2 = _hylas.global_position if is_instance_valid(_hylas) else Vector2.ZERO
	return _activate_catalog_item(SLOT_B, item_id, origin, Vector2.ZERO)


func _on_hylas_item_a_requested(
		item_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> void:
	if not _can_use_equipped_items() or _game_state == null:
		return
	if _game_state.get_equipped_item(SLOT_A) != item_id:
		return
	_activate_catalog_item(SLOT_A, item_id, origin, direction)


func _activate_catalog_item(
		slot_id: StringName,
		item_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	if _game_state == null or String(item_id).is_empty():
		_record_item_use(slot_id, item_id, false)
		return false
	if not _game_state.is_item_valid_for_slot(item_id, slot_id, true):
		_record_item_use(slot_id, item_id, false)
		return false
	if not ITEM_CATALOG.activates_on_use(item_id):
		_record_item_use(slot_id, item_id, false)
		return false

	var behavior_id: StringName = ITEM_CATALOG.get_behavior_id(item_id)
	if String(behavior_id).is_empty():
		_record_item_use(slot_id, item_id, false)
		return false

	var consumes_quantity: bool = (
		ITEM_CATALOG.item_has_quantity(item_id)
		and ITEM_CATALOG.get_ownership_source(item_id) == ITEM_CATALOG.OWNERSHIP_INVENTORY
	)
	if consumes_quantity and _game_state.get_inventory_quantity(item_id) <= 0:
		_record_item_use(slot_id, item_id, false)
		return false

	var activated: bool = false
	if behavior_id == NORMAL_CONCH_BEHAVIOR and slot_id == SLOT_A:
		if is_instance_valid(_hylas) and _hylas.has_method(&"activate_normal_conch"):
			activated = bool(_hylas.call(&"activate_normal_conch", direction))
	else:
		activated = _dispatch_item_behavior(behavior_id, item_id, slot_id, origin, direction)

	if not activated:
		_warn_for_missing_behavior(behavior_id)
		_record_item_use(slot_id, item_id, false)
		equipped_item_use_failed.emit(slot_id, item_id, behavior_id)
		return false

	if consumes_quantity and not _game_state.remove_inventory_item(item_id, 1):
		push_error("Activated item '%s' but could not consume its quantity." % String(item_id))

	_record_item_use(slot_id, item_id, true)
	if is_instance_valid(_hud):
		_hud.pulse_equipment_slot(slot_id)
	equipped_item_used.emit(slot_id, item_id, behavior_id)
	return true


func _dispatch_item_behavior(
		behavior_id: StringName,
		item_id: StringName,
		slot_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	var invalid_handlers: Array[Callable] = []
	for handler: Callable in _item_behavior_handlers:
		if not handler.is_valid():
			invalid_handlers.append(handler)
			continue
		var result: Variant = handler.call(behavior_id, item_id, slot_id, origin, direction)
		if bool(result):
			for invalid_handler: Callable in invalid_handlers:
				_item_behavior_handlers.erase(invalid_handler)
			return true
	for invalid_handler: Callable in invalid_handlers:
		_item_behavior_handlers.erase(invalid_handler)
	return false


func _warn_for_missing_behavior(behavior_id: StringName) -> void:
	if String(behavior_id).is_empty() or _warned_missing_behaviors.has(String(behavior_id)):
		return
	_warned_missing_behaviors[String(behavior_id)] = true
	push_warning("No active gameplay handler accepted item behavior '%s'." % String(behavior_id))


func _on_equipped_item_changed(slot_id: StringName, _item_id: StringName) -> void:
	if slot_id == SLOT_A:
		_sync_equipped_item_a()


func _sync_equipped_item_a() -> void:
	_resolve_hylas()
	if not is_instance_valid(_hylas) or not _hylas.has_method(&"set_equipped_item_a"):
		return
	var item_id: StringName = NORMAL_CONCH_BEHAVIOR
	if _game_state != null:
		item_id = _game_state.get_equipped_item(SLOT_A)
	_hylas.call(&"set_equipped_item_a", item_id)


func _resolve_hylas() -> void:
	if is_instance_valid(_hylas):
		return
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		if not _level.is_ancestor_of(candidate):
			continue
		_hylas = candidate as CotcHylas
		if is_instance_valid(_hylas):
			return


func _connect_hylas_item_request() -> void:
	_resolve_hylas()
	if not is_instance_valid(_hylas) or not _hylas.has_signal(&"item_a_requested"):
		push_warning("Hylas is missing the Phase 3 Item A request signal.")
		return
	var callback: Callable = Callable(self, "_on_hylas_item_a_requested")
	if not _hylas.is_connected(&"item_a_requested", callback):
		_hylas.connect(&"item_a_requested", callback)


func _cancel_hylas_pending_interaction() -> void:
	_resolve_hylas()
	if is_instance_valid(_hylas) and _hylas.has_method(&"cancel_pending_interaction"):
		_hylas.call(&"cancel_pending_interaction")


func _record_item_use(slot_id: StringName, item_id: StringName, succeeded: bool) -> void:
	_last_item_use_slot = slot_id
	_last_item_use_id = item_id
	_last_item_use_succeeded = succeeded


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("item_behavior_handlers=%d" % _item_behavior_handlers.size())
	lines.append("last_item_use_slot=%s" % String(_last_item_use_slot))
	lines.append("last_item_use_id=%s" % String(_last_item_use_id))
	lines.append("last_item_use_succeeded=%s" % str(_last_item_use_succeeded))
	return lines
