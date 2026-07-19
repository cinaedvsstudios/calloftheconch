extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller_world_sync.gd"

## Mounts the persistent Leaf Sheep companion into the shared item-effect owner.

const BEHAVIOR_LEAF_SHEEP: StringName = &"leaf_sheep"
const ITEM_LEAF_SHEEP: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"

@onready var _leaf_sheep: CotcLeafSheep = %LeafSheep

var _leaf_sheep_hud_active: bool = false


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	super.configure(context, level, hylas)
	_leaf_sheep.configure(context, level, hylas)


func bind_game_state(game_state: CotcGameState) -> void:
	super.bind_game_state(game_state)
	_leaf_sheep.bind_game_state(game_state)


func set_active(is_active: bool) -> void:
	if not is_active:
		_leaf_sheep.force_deactivate(&"gameplay_inactive")
	_leaf_sheep.set_gameplay_active(is_active)
	super.set_active(is_active)


func handle_item_behavior(
		behavior_id: StringName,
		item_id: StringName,
		slot_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	if behavior_id == BEHAVIOR_LEAF_SHEEP and item_id == ITEM_LEAF_SHEEP:
		return _leaf_sheep.toggle_activation()
	return super.handle_item_behavior(behavior_id, item_id, slot_id, origin, direction)


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_leaf_sheep_hud()


func clear_active_effects() -> void:
	_leaf_sheep.force_deactivate(&"effects_cleared")
	_clear_leaf_sheep_hud_active()
	super.clear_active_effects()


func force_deactivate_leaf_sheep(reason: StringName) -> void:
	_leaf_sheep.force_deactivate(reason)
	_refresh_leaf_sheep_hud()


func set_leaf_sheep_gameplay_active(is_active: bool) -> void:
	_leaf_sheep.set_gameplay_active(is_active)


func set_leaf_sheep_darkness_profile(
		profile_id: StringName,
		darkness_strength: float,
		darkness_tint: Color = Color(0.004, 0.012, 0.055, 1.0),
	) -> void:
	_leaf_sheep.set_darkness_profile(profile_id, darkness_strength, darkness_tint)


func _refresh_leaf_sheep_hud() -> void:
	if not is_instance_valid(_leaf_sheep):
		return
	var leaf_sheep_equipped: bool = (
		_game_state != null
		and _game_state.get_equipped_item(ITEM_SLOT_B) == ITEM_LEAF_SHEEP
	)
	if _leaf_sheep.is_active():
		_set_item_b_timed_active(true)
		_leaf_sheep_hud_active = true
	elif _leaf_sheep_hud_active:
		_clear_leaf_sheep_hud_active()
	if not is_instance_valid(_status_countdown):
		return
	if _leaf_sheep.get_phase_remaining() > 0.0:
		_status_countdown.set_countdown(
			ITEM_LEAF_SHEEP,
			_leaf_sheep.get_phase_remaining(),
			_leaf_sheep.get_phase_duration(),
		)
	elif (
			leaf_sheep_equipped
			and _leaf_sheep.is_cooling_down()
			and _leaf_sheep.get_cooldown_remaining() > 0.0
		):
		_status_countdown.set_countdown(
			ITEM_LEAF_SHEEP,
			_leaf_sheep.get_cooldown_remaining(),
			_leaf_sheep.cooldown_duration,
		)
	elif _status_countdown.get_active_item_id() == ITEM_LEAF_SHEEP:
		_status_countdown.clear_countdown()


func _clear_leaf_sheep_hud_active() -> void:
	if not _leaf_sheep_hud_active:
		return
	_leaf_sheep_hud_active = false
	_set_item_b_timed_active(false)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	if is_instance_valid(_leaf_sheep):
		lines.append_array(_leaf_sheep.get_debug_lines())
	lines.append("leaf_sheep_hud_active=%s" % str(_leaf_sheep_hud_active))
	return lines
