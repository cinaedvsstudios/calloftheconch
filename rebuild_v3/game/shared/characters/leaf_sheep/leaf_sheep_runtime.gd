extends "res://rebuild_v3/game/shared/characters/leaf_sheep/leaf_sheep.gd"

## Adds save-state replacement resets and optional level-owned depth darkness.

var _replacement_state_source: CotcGameState
var _depth_profile_enabled: bool = false
var _depth_start_y: float = 0.0
var _depth_full_y: float = 1.0
var _depth_maximum_darkness: float = 0.0
var _depth_tint: Color = Color(0.004, 0.012, 0.055, 1.0)


func _process(delta: float) -> void:
	_update_depth_darkness()
	super._process(delta)


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_state_replacement()
	super.bind_game_state(game_state)
	_replacement_state_source = game_state
	if (
			_replacement_state_source != null
			and not _replacement_state_source.state_replaced.is_connected(_on_state_replaced)
		):
		_replacement_state_source.state_replaced.connect(_on_state_replaced)


func set_gameplay_active(is_active: bool) -> void:
	super.set_gameplay_active(is_active)
	if not is_active:
		_set_overlay_enabled(false)
		return
	_update_depth_darkness()
	_set_overlay_enabled(_environment_darkness > 0.001)


func set_darkness_profile(
		profile_id: StringName,
		darkness_strength: float,
		darkness_tint: Color = Color(0.004, 0.012, 0.055, 1.0),
	) -> void:
	_depth_profile_enabled = false
	super.set_darkness_profile(profile_id, darkness_strength, darkness_tint)
	if not _gameplay_active:
		_set_overlay_enabled(false)


func clear_darkness_profile() -> void:
	_depth_profile_enabled = false
	super.clear_darkness_profile()


func _exit_tree() -> void:
	_disconnect_state_replacement()


func _read_level_darkness_profile() -> void:
	_depth_profile_enabled = false
	if not is_instance_valid(_level) or not _level.has_meta(&"leaf_sheep_darkness_profile"):
		super._read_level_darkness_profile()
		return
	var profile_value: Variant = _level.get_meta(&"leaf_sheep_darkness_profile")
	if not (profile_value is Dictionary):
		super._read_level_darkness_profile()
		return
	var profile: Dictionary = profile_value
	if not profile.has("start_y") or not profile.has("full_y"):
		super._read_level_darkness_profile()
		return
	_depth_profile_enabled = true
	_depth_start_y = float(profile.get("start_y", 0.0))
	_depth_full_y = float(profile.get("full_y", _depth_start_y + 1.0))
	_depth_maximum_darkness = clampf(
		float(profile.get("maximum_darkness", profile.get("darkness_strength", 0.92))),
		0.0,
		1.0,
	)
	var tint_value: Variant = profile.get("tint", default_darkness_tint)
	_depth_tint = tint_value if tint_value is Color else default_darkness_tint
	_active_darkness_profile = StringName(str(profile.get("id", "depths")))
	_apply_darkness_tint(_depth_tint)
	_update_depth_darkness()


func _update_depth_darkness() -> void:
	if not _depth_profile_enabled or not is_instance_valid(_hylas):
		return
	var depth_span: float = _depth_full_y - _depth_start_y
	var depth_ratio: float = 0.0
	if absf(depth_span) > 0.001:
		depth_ratio = clampf((_hylas.global_position.y - _depth_start_y) / depth_span, 0.0, 1.0)
	var eased_ratio: float = depth_ratio * depth_ratio * (3.0 - 2.0 * depth_ratio)
	_environment_darkness = _depth_maximum_darkness * eased_ratio
	_apply_darkness_tint(_depth_tint)
	_set_overlay_enabled(_gameplay_active and _environment_darkness > 0.001)


func _on_state_replaced(_reason: StringName) -> void:
	_reset_runtime_state()


func _disconnect_state_replacement() -> void:
	if (
			_replacement_state_source != null
			and _replacement_state_source.state_replaced.is_connected(_on_state_replaced)
		):
		_replacement_state_source.state_replaced.disconnect(_on_state_replaced)
	_replacement_state_source = null
