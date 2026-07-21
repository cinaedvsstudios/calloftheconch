class_name CotcLeafSheep
extends Node2D

## Canonical runtime owner for the permanent Item B companion, its phase timers,
## light, darkness reveal and one-time repair of the broken pre-pickup save state.

signal state_changed(state_name: StringName)
signal phase_changed(phase_name: StringName)
signal activation_changed(is_active: bool)

const ITEM_ID: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"
const PHASE_NONE: StringName = &"none"
const PHASE_BRIGHT: StringName = &"bright"
const PHASE_MID: StringName = &"mid"
const PHASE_LOW: StringName = &"low"

const INVENTORY_RESET_FLAG: StringName = &"leaf_sheep_ship_pickup_inventory_reset_v1"
const SHIP_PICKUP_IDS: Array[StringName] = [
	&"pirate_ship_leaf_sheep",
	&"pirate_ship_leaf_sheep_v2",
	&"pirate_ship_leaf_sheep_v3",
]

const LOW_TEXTURE: Texture2D = preload("res://assets/characters/companion_leaf_sheep0.png")
const MID_TEXTURE: Texture2D = preload("res://assets/characters/companion_leaf_sheep1.png")
const BRIGHT_TEXTURE: Texture2D = preload("res://assets/characters/companion_leaf_sheep2.png")

enum State {
	READY,
	BRIGHT,
	MID,
	LOW,
	COOLDOWN,
}

@export_category("Timing")
@export_range(1.0, 300.0, 1.0) var bright_duration: float = 60.0
@export_range(1.0, 300.0, 1.0) var mid_duration: float = 30.0
@export_range(1.0, 300.0, 1.0) var cooldown_duration: float = 30.0
@export_range(0.05, 5.0, 0.05) var phase_transition_seconds: float = 1.0

@export_category("Display")
@export_range(10.0, 180.0, 1.0) var display_height: float = 54.0
@export var bright_reveal_radius: Vector2 = Vector2(380.0, 280.0)
@export var mid_reveal_radius: Vector2 = Vector2(260.0, 190.0)
@export var low_reveal_radius: Vector2 = Vector2(145.0, 105.0)
@export_range(0.0, 8.0, 0.05) var bright_light_energy: float = 2.2
@export_range(0.0, 8.0, 0.05) var mid_light_energy: float = 1.35
@export_range(0.0, 8.0, 0.05) var low_light_energy: float = 0.65
@export_range(0.05, 1.0, 0.01) var reveal_feather: float = 0.28

@export_category("Environment Darkness")
@export_range(0.0, 1.0, 0.01) var default_environment_darkness: float = 0.0
@export var default_darkness_tint: Color = Color(0.004, 0.012, 0.055, 1.0)

@onready var _previous_sprite: Sprite2D = %PreviousSprite
@onready var _current_sprite: Sprite2D = %CurrentSprite
@onready var _point_light: PointLight2D = %RevealLight
@onready var _darkness_overlay: ColorRect = %DarknessOverlay
@onready var _darkness_material: ShaderMaterial = _darkness_overlay.material as ShaderMaterial

var _context: Node
var _level: Node
var _hylas: CotcHylas
var _game_state: CotcGameState
var _replacement_state_source: CotcGameState

var _state: State = State.READY
var _phase_elapsed: float = 0.0
var _active_elapsed: float = 0.0
var _cooldown_remaining: float = 0.0
var _gameplay_active: bool = false
var _transition_remaining: float = 0.0
var _current_reveal_radius: Vector2 = Vector2.ZERO
var _target_reveal_radius: Vector2 = Vector2.ZERO
var _current_light_energy: float = 0.0
var _target_light_energy: float = 0.0
var _environment_darkness: float = 0.0
var _active_darkness_profile: StringName = &"none"

var _depth_profile_enabled: bool = false
var _depth_start_y: float = 0.0
var _depth_full_y: float = 1.0
var _depth_maximum_darkness: float = 0.0
var _depth_tint: Color = Color(0.004, 0.012, 0.055, 1.0)


func _ready() -> void:
	top_level = true
	_previous_sprite.hide()
	_current_sprite.hide()
	_point_light.hide()
	_environment_darkness = default_environment_darkness
	_apply_darkness_tint(default_darkness_tint)
	_set_overlay_enabled(_environment_darkness > 0.001)
	set_process(true)


func _exit_tree() -> void:
	_disconnect_hylas()
	_disconnect_game_state()
	_disconnect_state_replacement()


func _process(delta: float) -> void:
	_update_depth_darkness()
	_sync_to_hylas()
	_update_visual_transition(delta)
	_update_darkness_shader()
	if not _gameplay_active:
		return
	match _state:
		State.BRIGHT:
			_update_bright(delta)
		State.MID:
			_update_mid(delta)
		State.LOW:
			_active_elapsed += maxf(0.0, delta)
		State.COOLDOWN:
			_update_cooldown(delta)


func configure(context: Node, level: Node, hylas: CotcHylas) -> void:
	_disconnect_hylas()
	_context = context
	_level = level
	_hylas = hylas
	_connect_hylas()
	_read_level_darkness_profile()
	if is_active() and is_instance_valid(_hylas):
		_hylas.call(&"set_leaf_sheep_active", true)
	_sync_to_hylas()


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_state_replacement()
	_disconnect_game_state()
	_game_state = game_state
	_connect_game_state()
	_replacement_state_source = game_state
	if (
			_replacement_state_source != null
			and not _replacement_state_source.state_replaced.is_connected(_on_state_replaced)
		):
		_replacement_state_source.state_replaced.connect(_on_state_replaced)
	_apply_broken_ship_inventory_reset_once()
	_reset_runtime_state()


func set_gameplay_active(is_active: bool) -> void:
	_gameplay_active = is_active
	if not is_active:
		_set_overlay_enabled(false)
		return
	_update_depth_darkness()
	_set_overlay_enabled(_environment_darkness > 0.001)


func toggle_activation() -> bool:
	if is_active():
		_deactivate_to_cooldown(&"manual")
		return true
	if _state != State.READY:
		return false
	if not _can_activate():
		return false
	_activate_bright()
	return true


func force_deactivate(reason: StringName = &"forced") -> void:
	if is_active():
		_deactivate_to_cooldown(reason)


func is_active() -> bool:
	return _state == State.BRIGHT or _state == State.MID or _state == State.LOW


func is_ready() -> bool:
	return _state == State.READY


func is_cooling_down() -> bool:
	return _state == State.COOLDOWN


func get_phase_name() -> StringName:
	match _state:
		State.BRIGHT:
			return PHASE_BRIGHT
		State.MID:
			return PHASE_MID
		State.LOW:
			return PHASE_LOW
		_:
			return PHASE_NONE


func get_state_name() -> StringName:
	match _state:
		State.READY:
			return &"ready"
		State.BRIGHT:
			return &"bright"
		State.MID:
			return &"mid"
		State.LOW:
			return &"low"
		State.COOLDOWN:
			return &"cooldown"
		_:
			return &"unknown"


func get_phase_remaining() -> float:
	match _state:
		State.BRIGHT:
			return maxf(0.0, bright_duration - _phase_elapsed)
		State.MID:
			return maxf(0.0, mid_duration - _phase_elapsed)
		_:
			return 0.0


func get_phase_duration() -> float:
	match _state:
		State.BRIGHT:
			return bright_duration
		State.MID:
			return mid_duration
		_:
			return 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func set_darkness_profile(
		profile_id: StringName,
		darkness_strength: float,
		darkness_tint: Color = Color(0.004, 0.012, 0.055, 1.0),
	) -> void:
	_depth_profile_enabled = false
	_active_darkness_profile = profile_id
	_environment_darkness = clampf(darkness_strength, 0.0, 1.0)
	_apply_darkness_tint(darkness_tint)
	_set_overlay_enabled(_gameplay_active and _environment_darkness > 0.001)


func clear_darkness_profile() -> void:
	_depth_profile_enabled = false
	_active_darkness_profile = &"none"
	_environment_darkness = default_environment_darkness
	_apply_darkness_tint(default_darkness_tint)
	_set_overlay_enabled(_gameplay_active and _environment_darkness > 0.001)


func get_debug_lines() -> Array[String]:
	var sheep_world_position: Vector2 = global_position if is_active() else Vector2.ZERO
	var sheep_screen_position: Vector2 = Vector2.ZERO
	if is_active():
		sheep_screen_position = get_viewport().get_canvas_transform() * global_position
	return [
		"[LeafSheep]",
		"leaf_sheep_owned=%s" % str(_is_owned()),
		"leaf_sheep_equipped=%s" % str(_is_equipped()),
		"leaf_sheep_active=%s" % str(is_active()),
		"leaf_sheep_state=%s" % String(get_state_name()),
		"leaf_sheep_phase=%s" % String(get_phase_name()),
		"leaf_sheep_active_elapsed=%.2f" % _active_elapsed,
		"leaf_sheep_phase_remaining=%.2f" % get_phase_remaining(),
		"leaf_sheep_cooldown_remaining=%.2f" % _cooldown_remaining,
		"leaf_sheep_sprite_path=%s" % _get_current_sprite_path(),
		"leaf_sheep_world_position=%s" % str(sheep_world_position),
		"leaf_sheep_screen_position=%s" % str(sheep_screen_position),
		"leaf_sheep_light_radius=%s" % str(_current_reveal_radius),
		"leaf_sheep_light_strength=%.2f" % _current_light_energy,
		"active_darkness_profile=%s" % String(_active_darkness_profile),
		"current_environment_darkness=%.2f" % _environment_darkness,
		"depth_profile_enabled=%s" % str(_depth_profile_enabled),
		"carry_animation_active=%s" % str(_is_hylas_carry_animation_active()),
		"greatfin_carry_animation_active=%s" % str(_is_greatfin_carry_active()),
	]


func _activate_bright() -> void:
	_state = State.BRIGHT
	_phase_elapsed = 0.0
	_active_elapsed = 0.0
	_cooldown_remaining = 0.0
	_show_phase(BRIGHT_TEXTURE, bright_reveal_radius, bright_light_energy, true)
	if is_instance_valid(_hylas):
		_hylas.call(&"set_leaf_sheep_active", true)
	state_changed.emit(get_state_name())
	phase_changed.emit(PHASE_BRIGHT)
	activation_changed.emit(true)


func _update_bright(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	_phase_elapsed += step
	_active_elapsed += step
	if _phase_elapsed < bright_duration:
		return
	_state = State.MID
	_phase_elapsed = 0.0
	_show_phase(MID_TEXTURE, mid_reveal_radius, mid_light_energy, false)
	state_changed.emit(get_state_name())
	phase_changed.emit(PHASE_MID)


func _update_mid(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	_phase_elapsed += step
	_active_elapsed += step
	if _phase_elapsed < mid_duration:
		return
	_state = State.LOW
	_phase_elapsed = 0.0
	_show_phase(LOW_TEXTURE, low_reveal_radius, low_light_energy, false)
	state_changed.emit(get_state_name())
	phase_changed.emit(PHASE_LOW)


func _update_cooldown(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - maxf(0.0, delta))
	if _cooldown_remaining > 0.0:
		return
	_state = State.READY
	state_changed.emit(get_state_name())


func _deactivate_to_cooldown(_reason: StringName) -> void:
	_state = State.COOLDOWN
	_phase_elapsed = 0.0
	_cooldown_remaining = cooldown_duration
	_target_reveal_radius = Vector2.ZERO
	_target_light_energy = 0.0
	_transition_remaining = phase_transition_seconds
	_previous_sprite.hide()
	_current_sprite.hide()
	_point_light.hide()
	if is_instance_valid(_hylas):
		_hylas.call(&"set_leaf_sheep_active", false)
	state_changed.emit(get_state_name())
	phase_changed.emit(PHASE_NONE)
	activation_changed.emit(false)


func _reset_runtime_state() -> void:
	_state = State.READY
	_phase_elapsed = 0.0
	_active_elapsed = 0.0
	_cooldown_remaining = 0.0
	_transition_remaining = 0.0
	_current_reveal_radius = Vector2.ZERO
	_target_reveal_radius = Vector2.ZERO
	_current_light_energy = 0.0
	_target_light_energy = 0.0
	_previous_sprite.hide()
	_current_sprite.hide()
	_point_light.hide()
	if is_instance_valid(_hylas):
		_hylas.call(&"set_leaf_sheep_active", false)
	state_changed.emit(get_state_name())
	phase_changed.emit(PHASE_NONE)
	activation_changed.emit(false)


func _show_phase(texture: Texture2D, radius: Vector2, energy: float, immediate: bool) -> void:
	if immediate or _current_sprite.texture == null:
		_previous_sprite.hide()
		_current_sprite.texture = texture
		_current_sprite.modulate = Color.WHITE
		_current_sprite.show()
		_current_reveal_radius = radius
		_current_light_energy = energy
	else:
		_previous_sprite.texture = _current_sprite.texture
		_previous_sprite.modulate = Color.WHITE
		_previous_sprite.show()
		_current_sprite.texture = texture
		_current_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_current_sprite.show()
	_target_reveal_radius = radius
	_target_light_energy = energy
	_transition_remaining = 0.0 if immediate else phase_transition_seconds
	_apply_sprite_scale(texture)
	_point_light.show()


func _update_visual_transition(delta: float) -> void:
	var step: float = maxf(0.0, delta)
	if phase_transition_seconds <= 0.0:
		_current_reveal_radius = _target_reveal_radius
		_current_light_energy = _target_light_energy
		_previous_sprite.hide()
		_current_sprite.modulate.a = 1.0
	else:
		var blend_step: float = clampf(step / phase_transition_seconds, 0.0, 1.0)
		_current_reveal_radius = _current_reveal_radius.lerp(_target_reveal_radius, blend_step)
		_current_light_energy = lerpf(_current_light_energy, _target_light_energy, blend_step)
		if _transition_remaining > 0.0:
			_transition_remaining = maxf(0.0, _transition_remaining - step)
			var progress: float = 1.0 - (_transition_remaining / phase_transition_seconds)
			_current_sprite.modulate.a = progress
			_previous_sprite.modulate.a = 1.0 - progress
			if _transition_remaining <= 0.0:
				_previous_sprite.hide()
				_current_sprite.modulate.a = 1.0
	_point_light.energy = _current_light_energy
	_point_light.scale = Vector2(
		maxf(0.001, _current_reveal_radius.x / 256.0),
		maxf(0.001, _current_reveal_radius.y / 256.0),
	)


func _sync_to_hylas() -> void:
	if not is_instance_valid(_hylas) or not is_active():
		return
	if _hylas.has_method(&"get_leaf_sheep_hand_world_position"):
		global_position = _hylas.call(&"get_leaf_sheep_hand_world_position") as Vector2
	else:
		global_position = _hylas.global_position
	if _hylas.has_method(&"get_leaf_sheep_visual_rotation"):
		rotation = float(_hylas.call(&"get_leaf_sheep_visual_rotation"))
	var facing_left: bool = false
	if _hylas.has_method(&"is_leaf_sheep_facing_left"):
		facing_left = bool(_hylas.call(&"is_leaf_sheep_facing_left"))
	_previous_sprite.flip_h = facing_left
	_current_sprite.flip_h = facing_left


func _update_darkness_shader() -> void:
	if _darkness_material == null:
		return
	_darkness_material.set_shader_parameter(&"darkness_strength", _environment_darkness)
	_darkness_material.set_shader_parameter(&"feather", reveal_feather)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var center_screen: Vector2 = viewport_size * 0.5
	if is_active() and is_instance_valid(_hylas):
		center_screen = get_viewport().get_canvas_transform() * global_position
	_darkness_material.set_shader_parameter(
		&"reveal_center",
		Vector2(center_screen.x / viewport_size.x, center_screen.y / viewport_size.y),
	)
	_darkness_material.set_shader_parameter(
		&"reveal_radius",
		Vector2(
			_current_reveal_radius.x / viewport_size.x,
			_current_reveal_radius.y / viewport_size.y,
		),
	)
	_darkness_material.set_shader_parameter(&"reveal_strength", 1.0 if is_active() else 0.0)


func _apply_darkness_tint(tint: Color) -> void:
	if _darkness_material != null:
		_darkness_material.set_shader_parameter(&"darkness_tint", tint)


func _set_overlay_enabled(enabled: bool) -> void:
	if is_instance_valid(_darkness_overlay):
		_darkness_overlay.visible = enabled


func _apply_sprite_scale(texture: Texture2D) -> void:
	if texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(texture.get_height()))
	var resolved_scale: Vector2 = Vector2.ONE * scale_factor
	_previous_sprite.scale = resolved_scale
	_current_sprite.scale = resolved_scale


func _can_activate() -> bool:
	if not _gameplay_active or not _is_owned() or not _is_equipped():
		return false
	if not is_instance_valid(_hylas):
		return false
	if _hylas.has_method(&"can_activate_leaf_sheep"):
		return bool(_hylas.call(&"can_activate_leaf_sheep"))
	return true


func _is_owned() -> bool:
	return _game_state != null and _game_state.is_item_owned(ITEM_ID)


func _is_equipped() -> bool:
	return _game_state != null and _game_state.get_equipped_item(ITEM_SLOT_B) == ITEM_ID


func _connect_hylas() -> void:
	if not is_instance_valid(_hylas):
		return
	var callback: Callable = Callable(self, "_on_hylas_forced_deactivation_requested")
	if _hylas.has_signal(&"leaf_sheep_forced_deactivation_requested"):
		if not _hylas.is_connected(&"leaf_sheep_forced_deactivation_requested", callback):
			_hylas.connect(&"leaf_sheep_forced_deactivation_requested", callback)


func _disconnect_hylas() -> void:
	if not is_instance_valid(_hylas):
		return
	var callback: Callable = Callable(self, "_on_hylas_forced_deactivation_requested")
	if _hylas.has_signal(&"leaf_sheep_forced_deactivation_requested"):
		if _hylas.is_connected(&"leaf_sheep_forced_deactivation_requested", callback):
			_hylas.disconnect(&"leaf_sheep_forced_deactivation_requested", callback)


func _connect_game_state() -> void:
	if _game_state == null:
		return
	if not _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
	if not _game_state.permanent_inventory_changed.is_connected(_on_permanent_inventory_changed):
		_game_state.permanent_inventory_changed.connect(_on_permanent_inventory_changed)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)
	if _game_state.permanent_inventory_changed.is_connected(_on_permanent_inventory_changed):
		_game_state.permanent_inventory_changed.disconnect(_on_permanent_inventory_changed)


func _on_equipped_item_changed(slot_id: StringName, item_id: StringName) -> void:
	if slot_id == ITEM_SLOT_B and item_id != ITEM_ID:
		force_deactivate(&"unequipped")


func _on_permanent_inventory_changed(item_id: StringName, owned: bool) -> void:
	if item_id == ITEM_ID and not owned:
		force_deactivate(&"ownership_removed")


func _on_hylas_forced_deactivation_requested(reason: StringName) -> void:
	force_deactivate(reason)


func _read_level_darkness_profile() -> void:
	_depth_profile_enabled = false
	if not is_instance_valid(_level) or not _level.has_meta(&"leaf_sheep_darkness_profile"):
		clear_darkness_profile()
		return
	var profile_value: Variant = _level.get_meta(&"leaf_sheep_darkness_profile")
	if not (profile_value is Dictionary):
		clear_darkness_profile()
		return
	var profile: Dictionary = profile_value
	if profile.has("start_y") and profile.has("full_y"):
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
		return
	set_darkness_profile(
		StringName(str(profile.get("id", "depths"))),
		float(profile.get("darkness_strength", default_environment_darkness)),
		profile.get("tint", default_darkness_tint) as Color,
	)


func _update_depth_darkness() -> void:
	if not _depth_profile_enabled or not is_instance_valid(_hylas):
		return
	var depth_span: float = _depth_full_y - _depth_start_y
	var depth_ratio: float = 0.0
	if absf(depth_span) > 0.001:
		depth_ratio = clampf(
			(_hylas.global_position.y - _depth_start_y) / depth_span,
			0.0,
			1.0,
		)
	var eased_ratio: float = depth_ratio * depth_ratio * (3.0 - 2.0 * depth_ratio)
	_environment_darkness = _depth_maximum_darkness * eased_ratio
	_apply_darkness_tint(_depth_tint)
	_set_overlay_enabled(_gameplay_active and _environment_darkness > 0.001)


func _apply_broken_ship_inventory_reset_once() -> void:
	if _game_state == null:
		return
	if bool(_game_state.story_flags.get(String(INVENTORY_RESET_FLAG), false)):
		return

	if _game_state.get_equipped_item(ITEM_SLOT_B) == ITEM_ID:
		_game_state.clear_equipped_item(ITEM_SLOT_B)

	var item_key: String = String(ITEM_ID)
	if _game_state.permanent_inventory_items.has(item_key):
		_game_state.permanent_inventory_items.erase(item_key)
		_game_state.permanent_inventory_changed.emit(ITEM_ID, false)

	for pickup_id: StringName in SHIP_PICKUP_IDS:
		var pickup_key: String = String(pickup_id)
		if not _game_state.collected_pickups.has(pickup_key):
			continue
		_game_state.collected_pickups.erase(pickup_key)
		_game_state.pickup_collection_changed.emit(pickup_id, false)

	_game_state.set_story_flag(INVENTORY_RESET_FLAG, true)


func _on_state_replaced(_reason: StringName) -> void:
	_apply_broken_ship_inventory_reset_once()
	_reset_runtime_state()


func _disconnect_state_replacement() -> void:
	if (
			_replacement_state_source != null
			and _replacement_state_source.state_replaced.is_connected(_on_state_replaced)
		):
		_replacement_state_source.state_replaced.disconnect(_on_state_replaced)
	_replacement_state_source = null


func _get_current_sprite_path() -> String:
	return _current_sprite.texture.resource_path if _current_sprite.texture != null else ""


func _is_hylas_carry_animation_active() -> bool:
	return (
		is_instance_valid(_hylas)
		and _hylas.has_method(&"is_leaf_sheep_carry_animation_active")
		and bool(_hylas.call(&"is_leaf_sheep_carry_animation_active"))
	)


func _is_greatfin_carry_active() -> bool:
	return (
		is_instance_valid(_hylas)
		and _hylas.has_method(&"is_leaf_sheep_greatfin_carry_active")
		and bool(_hylas.call(&"is_leaf_sheep_greatfin_carry_active"))
	)
