class_name CotcHylas
extends CharacterBody2D

signal normal_conch_used(origin: Vector2, direction: Vector2)
signal surface_splash_requested(origin: Vector2, is_exit: bool)
signal burst_started(origin: Vector2, direction: Vector2)
signal tail_flip_started(origin: Vector2, direction: Vector2)

@export_category("World Clamping")
@export var player_edge_padding: float = 105.0

@export_category("Swimming")
@export var swim_speed: float = 320.0
@export var swim_acceleration: float = 1600.0
@export var idle_momentum_deceleration: float = 300.0
@export var brake_deceleration: float = 2800.0
@export_range(10.0, 89.0, 1.0) var normal_swim_vertical_angle_degrees: float = 45.0
@export var idle_sink_speed: float = 14.0
@export var current_base_velocity: Vector2 = Vector2(10.0, 0.0)
@export var current_sway_horizontal: float = 7.0
@export var current_sway_vertical: float = 2.0
@export var current_sway_frequency: float = 0.24

@export_category("Speed Swim")
@export var burst_speed: float = 1120.0
@export_range(0.10, 10.0, 0.05) var burst_max_duration: float = 3.0
@export var burst_coast_deceleration: float = 700.0
@export var burst_cooldown: float = 0.0
@export_range(1, 5, 1) var burst_max_charges: int = 3
@export var burst_charge_recovery: float = 1.20
@export_range(10.0, 89.0, 1.0) var vertical_burst_angle_degrees: float = 75.0

@export_category("Tail Flip")
@export var tail_flip_speed: float = 860.0
@export var tail_flip_duration: float = 0.46
@export var tail_flip_cooldown: float = 0.30
@export var double_conch_tap_window: float = 0.20

@export_category("Conch")
@export var conch_cooldown: float = 0.80
@export var conch_duration: float = 0.34
@export_range(10.0, 89.0, 1.0) var conch_direction_angle_degrees: float = 45.0

@export_category("Surface Jump")
@export var jump_trigger_depth: float = 300.0
@export var jump_forward_distance: float = 430.0
@export var jump_arc_height: float = 240.0
@export var jump_duration: float = 0.60

@export_category("Presentation")
@export var display_height: float = 205.0
@export var camera_shake_strength: float = 10.0
@export var camera_shake_duration: float = 0.13

@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _shadow_sprite: Sprite2D = %ShadowSprite
@onready var _collision_shape: CollisionShape2D = %CollisionShape
@onready var _camera: Camera2D = %Camera2D
@onready var _tail_bubble_burst: CotcBubbleBurst = %TailBubbleBurst
@onready var _swim_audio: AudioStreamPlayer = %SwimAudio
@onready var _burst_audio: AudioStreamPlayer = %BurstAudio
@onready var _conch_audio: AudioStreamPlayer = %ConchAudio

# Level-owned markers provide these values through configure_world().
var _world_bounds: Rect2 = Rect2()
var _swim_ceiling_y: float = 0.0

var _play_enabled: bool = false
var _facing_left: bool = false
var _visual_rotation: float = 0.0
var _current_time: float = 0.0
var _brake_active: bool = false

# Standard movement is deliberately split so normal swimming can be added to
# residual speed-swim momentum instead of replacing it.
var _swim_velocity: Vector2 = Vector2.ZERO
var _burst_coast_velocity: Vector2 = Vector2.ZERO
var _special_velocity: Vector2 = Vector2.ZERO
var _external_currents: Dictionary[Node, Vector2] = {}

var _burst_direction: Vector2 = Vector2.RIGHT
var _burst_active: bool = false
var _burst_elapsed: float = 0.0
var _burst_remaining: float = 0.0
var _burst_requires_release: bool = false
var _burst_cooldown_remaining: float = 0.0
var _burst_charges: int = 0
var _burst_charge_timer: float = 0.0

var _tail_flip_direction: Vector2 = Vector2.RIGHT
var _tail_flip_remaining: float = 0.0
var _tail_flip_cooldown_remaining: float = 0.0
var _conch_remaining: float = 0.0
var _conch_cooldown_remaining: float = 0.0
var _pending_conch_remaining: float = 0.0
var _pending_conch_direction: Vector2 = Vector2.RIGHT
var _pending_surface_jump: bool = false
var _jump_elapsed: float = 0.0
var _jump_start: Vector2 = Vector2.ZERO
var _jump_end: Vector2 = Vector2.ZERO
var _camera_rest_offset: Vector2 = Vector2.ZERO
var _camera_shake_remaining: float = 0.0


# -----------------------------------------------------------------------------
# Consolidated Hylas controller
# Former inheritance layers are embedded below as private implementation helpers.
# Public and engine callback names remain on the highest implementation only.
# -----------------------------------------------------------------------------


# === Action presentation declarations ===

## Presentation-only control for the timing-sensitive Hylas actions.
## Gameplay movement remains in the inherited CotcHylas script.

signal tail_flip_impact(contact_position: Vector2, normal: Vector2, target: Node)

const NORMAL_TAIL_FLIP_STRIKE_TEXTURE: String = "hylas-flip_06.webp"
const GREATFIN_TAIL_FLIP_STRIKE_TEXTURE: String = "hylas-greatfin-tailflip05.webp"

@export_category("Action Gameplay Timing")
@export_range(0.10, 10.0, 0.01) var speed_run_gameplay_duration: float = 1.50
@export_range(0.10, 5.0, 0.01) var tail_flip_gameplay_duration: float = 1.00
@export_range(0.10, 5.0, 0.01) var conch_gameplay_duration: float = 0.5555556

@export_category("Animation Speeds")
@export_range(0.1, 60.0, 0.1) var idle_animation_fps: float = 2.0
@export_range(0.1, 60.0, 0.1) var tail_flip_animation_fps: float = 10.0
@export_range(0.1, 60.0, 0.1) var conch_animation_fps: float = 18.0
@export_range(0.1, 60.0, 0.1) var stop_animation_fps: float = 9.0

@export_category("Speed Run Animation Timing")
@export_range(0.01, 2.0, 0.01) var speed_run_startup_frame_duration: float = 0.10
@export_range(0.01, 10.0, 0.01) var speed_run_hold_start: float = 0.20
@export_range(0.01, 10.0, 0.01) var speed_run_hold_end: float = 1.20
@export_range(0.01, 2.0, 0.01) var speed_run_finish_frame_duration: float = 0.10

@export_category("Collision Profiles")
@export var default_collision_shape: Shape2D
@export var tail_flip_collision_shape: Shape2D
@export var conch_collision_shape: Shape2D
@export var stop_collision_shape: Shape2D

@export_category("Conch Steering")
@export_range(10.0, 180.0, 1.0) var conch_steer_speed_degrees: float = 90.0

var _stop_pose_held: bool = false
var _collision_profile_name: StringName = &"default"
var _tail_flip_impact_target_ids: Dictionary = {}



# === Land movement declarations ===

@export_category("Land Movement")
@export var land_gravity := 5800.0
@export var jump_horizontal_speed := 720.0
@export var jump_launch_upward_speed := 1665.0
@export var crawl_speed := 170.0
@export var crawl_water_reentry_depth := 36.0

@onready var splash: AudioStreamPlayer = %SplashAudio
@onready var hurt_audio: AudioStreamPlayer = %HurtAudio
@onready var land_impact_audio: AudioStreamPlayer = %LandImpactAudio
@onready var fin_loss_audio: AudioStreamPlayer = %FinLossAudio

var crawl_active := false
var airborne_active := false
var left_water := false
var entry_splash_done := false
var _tail_flip_combo_frame: bool = false



# === Reliable input and death declarations ===

## Owns the timing-sensitive Space input rules. A single Space press uses the
## nearby interaction, while a second press inside the short window ignores the
## interaction and fires the conch. Shift+Space remains reserved for Tail Flip.
## This top-level Hylas controller also owns the animation-driven death state so
## normal swimming code cannot interfere while the body drifts to the seabed.

const DEATH_INTRO_ANIMATION: StringName = &"death_intro"
const DEATH_DRIFT_ANIMATION: StringName = &"death_drift"
const DIE_01: Texture2D = preload("res://assets/characters/die01.webp")
const DIE_02: Texture2D = preload("res://assets/characters/die02.webp")
const DIE_03: Texture2D = preload("res://assets/characters/die03.webp")
const DIE_04: Texture2D = preload("res://assets/characters/die04.webp")
const DIE_05: Texture2D = preload("res://assets/characters/die05.webp")
const DIE_06: Texture2D = preload("res://assets/characters/die06.webp")
const DIE_07: Texture2D = preload("res://assets/characters/die07.webp")
const DIE_08: Texture2D = preload("res://assets/characters/die08.webp")
const DIE_09: Texture2D = preload("res://assets/characters/die09.webp")

signal interaction_requested
signal interaction_availability_changed(is_available: bool)
signal death_drift_started
signal death_landed

@export_range(0.0, 200.0, 1.0) var brake_minimum_speed: float = 5.0
@export_range(0.05, 0.5, 0.01) var interaction_double_tap_window: float = 0.20

@export_category("Pickup Feedback")
@export var pickup_feedback_hand_offset: Vector2 = Vector2(48.0, -18.0)

@export_category("Death Sequence")
@export_range(1.0, 30.0, 0.5) var death_intro_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var death_drift_fps: float = 3.0
@export_range(1.0, 500.0, 1.0) var death_drift_speed: float = 85.0
@export_range(-400.0, 0.0, 1.0) var death_camera_vertical_offset: float = -130.0
@export_range(0.05, 5.0, 0.05) var death_camera_recenter_seconds: float = 1.20

var _shift_space_tail_flip_requested: bool = false
var _tail_flip_chord_active: bool = false
var _space_action_pressed_this_frame: bool = false
var _interaction_available: bool = false
var _pending_interaction_remaining: float = 0.0
var _death_sequence_active: bool = false
var _death_drift_active: bool = false
var _death_body_landed: bool = false
var _normal_camera_rest_offset: Vector2 = Vector2.ZERO
var _death_camera_start_offset: Vector2 = Vector2.ZERO
var _death_camera_elapsed: float = 0.0



# === Equipment input declarations ===

## Equipment-aware action layer for Hylas.
##
## Input is matched through InputMap actions so remapped controls retain the
## same conflict rules. The first Item A binding shares the nearby interaction
## timing, while alternate Item A bindings continue to activate directly.

signal item_a_requested(item_id: StringName, origin: Vector2, direction: Vector2)

const NORMAL_CONCH_ID: StringName = &"normal_conch"
const SUPER_CONCH_ID: StringName = &"charonia_tritonis"
const CONUS_TEXTILE_ID: StringName = &"conus_textile"
const CONUS_CLIMB_ANIMATION: StringName = &"climb"
const TRIDACNA_SURFACE_LAUNCH_VELOCITY_SCALE: float = 1.41421356237
const NORMAL_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Conch_noise.mp3")
const SUPER_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Super Conch_noise.mp3")

@export_category("Conus Wall Climb")
@export_range(40.0, 900.0, 5.0) var conus_climb_speed: float = 260.0
@export_range(40.0, 240.0, 1.0) var conus_climb_minimum_distance: float = 100.0
@export_range(0.01, 0.90, 0.01) var conus_climb_input_deadzone: float = 0.16
@export_range(0.0, 180.0, 1.0) var conus_rope_hand_offset: float = 62.0
@export_range(-120.0, 120.0, 1.0) var normal_conus_climb_sprite_perpendicular_offset: float = -24.0

@onready var _item_visuals: CotcHylasItemVisuals = %ItemVisuals

var _equipped_item_a: StringName = NORMAL_CONCH_ID
var _utility_item_pressed_this_frame: bool = false
var _item_surge_remaining: float = 0.0
var _purple_shield_active: bool = false
var _camouflage_active: bool = false
var _normal_collision_layer: int = 1
var _conus_climb_active: bool = false
var _conus_climb_anchor: Vector2 = Vector2.ZERO
var _conus_climb_maximum_distance: float = 0.0
var _conus_climb_tether: Node
var _conus_climb_previous_facing_left: bool = false
var _conus_climb_wait_for_conch_release: bool = false
var _conus_climb_sprite_base_position: Vector2 = Vector2.ZERO
var _conus_climb_normal_sprite_scale: Vector2 = Vector2.ONE



# === Phase 6 corrections declarations ===

signal surge_ram_started(origin: Vector2, direction: Vector2, duration: float)

const NORMAL_TEREBRIDAE_HOLD_FRAME_INDEX: int = 6
const NORMAL_TEREBRIDAE_RELEASE_FRAME_INDEX: int = 7
const CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER: float = 1.15

@export_category("Death Menu Timing")
@export_range(0.5, 10.0, 0.1) var death_menu_drift_seconds: float = 3.0

@export_category("Conch Recoil")
@export_range(0.0, 300.0, 1.0) var normal_conch_recoil_speed: float = 72.0
@export_range(0.0, 300.0, 1.0) var super_conch_recoil_speed: float = 108.0
@export_range(0.0, 300.0, 1.0) var terebridae_recoil_speed: float = 86.0

var _death_menu_notification_sent: bool = false
var _death_menu_drift_elapsed: float = 0.0
var _terebridae_pose_active: bool = false
var _terebridae_release_active: bool = false
var _terebridae_stream_remaining: float = 0.0
var _terebridae_release_remaining: float = 0.0
var _conus_climb_previous_visual_scale: Vector2 = Vector2.ONE
var _conus_climb_previous_animation: StringName = &"idle"
var _conus_climb_previous_frame: int = 0
var _conus_climb_started: bool = false
var _conus_wait_for_direction_release: bool = false



# === Vent and seaweed movement declarations ===

## Carries active vent tiers into Speed Run surface jumps and applies local
## seaweed movement modifiers without weakening environmental currents.

const SUPER_JUMP_AUDIO: AudioStream = preload("res://assets/audio/superjump.mp3")
const PRESSURE_JUMP_THRESHOLD: float = 1.99

@export_category("Vent Surface Jump")
@export_range(-30.0, 6.0, 1.0) var super_jump_volume_db: float = -4.0

var _active_jump_arc_height: float = 0.0
var _active_jump_duration: float = 0.0
var _active_vent_jump_multiplier: float = 1.0
var _pressure_jump_active: bool = false
var _super_jump_audio: AudioStreamPlayer
var _seaweed_slow_sources: Dictionary[Node, float] = {}



# === Leaf Sheep carry declarations ===

## Adds Leaf Sheep carry presentation and movement restrictions to Hylas.

signal leaf_sheep_forced_deactivation_requested(reason: StringName)

const CARRY_ANIMATION: StringName = &"carry"
const NORMAL_CARRY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/hylas-carry01.webp"),
	preload("res://assets/characters/hylas-carry02.webp"),
	preload("res://assets/characters/hylas-carry03.webp"),
	preload("res://assets/characters/hylas-carry04.webp"),
]
const GREATFIN_CARRY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/hylas-greatfin-carry01.webp"),
	preload("res://assets/characters/hylas-greatfin-carry02.webp"),
	preload("res://assets/characters/hylas-greatfin-carry03.webp"),
	preload("res://assets/characters/hylas-greatfin-carry04.webp"),
]
const GREATFIN_FRAMES: SpriteFrames = preload(
	"res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres"
)

@export_category("Leaf Sheep Carry")
@export_range(0.1, 30.0, 0.1) var leaf_sheep_carry_fps: float = 6.0
@export var leaf_sheep_hand_offset: Vector2 = Vector2(45.0, -24.0)
@export var leaf_sheep_carry_frame_offsets: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, -1.0),
	Vector2(2.0, -1.0),
	Vector2(1.0, 0.0),
]
@export var leaf_sheep_conch_frame_offsets: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, -1.0),
	Vector2(2.0, -2.0),
	Vector2(3.0, -3.0),
	Vector2(4.0, -3.0),
	Vector2(4.0, -2.0),
	Vector2(3.0, -1.0),
	Vector2(2.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, 0.0),
]

var _leaf_sheep_active: bool = false




# =============================================================================
# Core movement
# =============================================================================

func _phase3_base_ready() -> void:
	_camera_rest_offset = _camera.offset
	_burst_charges = burst_max_charges
	_swim_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_burst_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_conch_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_display_scale()
	_tail_bubble_burst.stop_burst()
	_set_animation(&"idle")
	set_physics_process(false)



func configure_world(bounds: Rect2, waterline_y: float, start_position: Vector2) -> void:
	_world_bounds = bounds
	_swim_ceiling_y = waterline_y
	global_position = _clamp_to_world(start_position)
	_camera.limit_left = floori(bounds.position.x)
	_camera.limit_top = floori(bounds.position.y)
	_camera.limit_right = ceili(bounds.end.x)
	_camera.limit_bottom = ceili(bounds.end.y)



func _phase3_base_set_play_enabled(enabled: bool) -> void:
	_play_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		_reset_motion_state()
		_stop_movement_audio()



func _phase3_base_reset_to_start(start_position: Vector2) -> void:
	global_position = _clamp_to_world(start_position)
	_reset_motion_state()
	_tail_flip_remaining = 0.0
	_conch_remaining = 0.0
	_pending_conch_remaining = 0.0
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_burst_charges = burst_max_charges
	_tail_bubble_burst.stop_burst()
	_stop_movement_audio()
	_set_visual_rotation(0.0)
	_set_animation(&"idle")



func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if not is_instance_valid(source):
		return
	_external_currents[source] = current_velocity



func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)



func _phase3_base_physics_process(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()

	if _jump_elapsed > 0.0:
		_update_surface_jump(delta)
		return

	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_update_burst_release_latch(input_direction)

	if _brake_active:
		if Input.is_action_pressed(&"action_a"):
			_apply_motion(Vector2.ZERO, false)
			return
		_brake_active = false

	if _is_braking(input_direction):
		_start_brake()
		_apply_motion(Vector2.ZERO, false)
		return

	if Input.is_action_just_pressed(&"conch"):
		_handle_conch_pressed(input_direction)
	_update_pending_conch(delta)

	if _tail_flip_remaining > 0.0:
		_update_tail_flip(delta)
		_apply_motion(_special_velocity, false)
		return
	if _conch_remaining > 0.0:
		_update_conch(delta)
		_apply_motion(_special_velocity, true)
		return
	if _burst_active:
		_update_active_burst(input_direction, delta)
		_apply_motion(_swim_velocity + _burst_coast_velocity, false)
		if _pending_surface_jump and global_position.y <= _swim_ceiling_y:
			_begin_surface_jump()
		return

	_update_burst_coast(delta)
	if _burst_requires_release and Input.is_action_pressed(&"action_a"):
		_update_idle(delta)
	elif _can_start_burst(input_direction):
		_start_burst(input_direction)
	elif input_direction != Vector2.ZERO:
		_update_swim(input_direction, delta)
	else:
		_update_idle(delta)
	_apply_motion(_swim_velocity + _burst_coast_velocity, input_direction == Vector2.ZERO and not _has_burst_coast())



func _update_cooldowns(delta: float) -> void:
	_burst_cooldown_remaining = maxf(0.0, _burst_cooldown_remaining - delta)
	_tail_flip_cooldown_remaining = maxf(0.0, _tail_flip_cooldown_remaining - delta)
	_conch_cooldown_remaining = maxf(0.0, _conch_cooldown_remaining - delta)
	if _burst_charges < burst_max_charges:
		_burst_charge_timer = maxf(0.0, _burst_charge_timer - delta)
		if _burst_charge_timer <= 0.0:
			_burst_charges += 1
			_burst_charge_timer = burst_charge_recovery if _burst_charges < burst_max_charges else 0.0



func _update_burst_release_latch(input_direction: Vector2) -> void:
	if not Input.is_action_pressed(&"action_a") or input_direction == Vector2.ZERO:
		_burst_requires_release = false



func _phase3_base_can_start_burst(input_direction: Vector2) -> bool:
	return _pending_conch_remaining <= 0.0 and not _burst_requires_release and Input.is_action_pressed(&"action_a") and input_direction != Vector2.ZERO and _burst_charges > 0 and _burst_cooldown_remaining <= 0.0



func _phase3_base_start_burst(input_direction: Vector2) -> void:
	var vertical_axis: float = _vertical_axis(input_direction)
	if vertical_axis != 0.0:
		_update_facing_from_held_horizontal_input()
	if vertical_axis == 0.0 and _is_backward_input(input_direction):
		return
	if vertical_axis != 0.0:
		_burst_direction = _facing_tilted_direction(vertical_axis, vertical_burst_angle_degrees)
	else:
		_facing_left = input_direction.x < 0.0
		_burst_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_burst_active = true
	_burst_elapsed = 0.0
	_burst_remaining = burst_max_duration
	_burst_cooldown_remaining = burst_cooldown
	_burst_charges -= 1
	_burst_charge_timer = burst_charge_recovery
	_pending_surface_jump = vertical_axis < 0.0 and global_position.y <= _swim_ceiling_y + jump_trigger_depth
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = _burst_direction * burst_speed
	_special_velocity = Vector2.ZERO
	_set_visual_rotation(_direction_rotation(_burst_direction, vertical_burst_angle_degrees))
	_set_animation(&"burst")
	_play_burst_audio()
	if not _pending_surface_jump:
		_play_tail_bubble_burst()
	_trigger_camera_shake()
	burst_started.emit(global_position, _burst_direction)



func _update_active_burst(input_direction: Vector2, delta: float) -> void:
	_burst_elapsed += delta
	_burst_remaining = maxf(0.0, burst_max_duration - _burst_elapsed)
	if not _is_burst_input_held(input_direction):
		_finish_burst_to_coast(false)
		return
	if _burst_elapsed >= burst_max_duration:
		_finish_burst_to_coast(true)



func _phase3_base_is_burst_input_held(input_direction: Vector2) -> bool:
	return Input.is_action_pressed(&"action_a") and input_direction != Vector2.ZERO



func _finish_burst_to_coast(requires_release: bool) -> void:
	_burst_active = false
	_burst_remaining = 0.0
	_pending_surface_jump = false
	_burst_requires_release = requires_release
	_stop_burst_audio()
	_set_animation(&"swim")



func _update_burst_coast(delta: float) -> void:
	_burst_coast_velocity = _burst_coast_velocity.move_toward(Vector2.ZERO, burst_coast_deceleration * delta)



func _phase3_base_handle_conch_pressed(input_direction: Vector2) -> void:
	if _burst_active or _tail_flip_remaining > 0.0 or _jump_elapsed > 0.0:
		return
	if _pending_conch_remaining > 0.0 and _tail_flip_cooldown_remaining <= 0.0:
		_pending_conch_remaining = 0.0
		_start_tail_flip()
		return
	if _conch_cooldown_remaining <= 0.0:
		_pending_conch_direction = _conch_direction(input_direction)
		_pending_conch_remaining = double_conch_tap_window



func _update_pending_conch(delta: float) -> void:
	if _pending_conch_remaining <= 0.0:
		return
	_pending_conch_remaining = maxf(0.0, _pending_conch_remaining - delta)
	if _pending_conch_remaining <= 0.0 and _conch_cooldown_remaining <= 0.0:
		_start_conch(_pending_conch_direction)



func _phase3_base_start_tail_flip() -> void:
	_tail_flip_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_tail_flip_remaining = tail_flip_duration
	_tail_flip_cooldown_remaining = tail_flip_cooldown
	_special_velocity = _tail_flip_direction * tail_flip_speed
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	_set_animation(&"tail_flip")
	_play_burst_audio()
	_play_tail_bubble_burst()
	_trigger_camera_shake()
	tail_flip_started.emit(global_position, _tail_flip_direction)



func _update_tail_flip(delta: float) -> void:
	_tail_flip_remaining = maxf(0.0, _tail_flip_remaining - delta)
	_special_velocity = _special_velocity.move_toward(Vector2.ZERO, brake_deceleration * delta)
	if _tail_flip_remaining <= 0.0:
		_stop_burst_audio()
		_set_animation(&"idle")



func _start_conch(direction: Vector2) -> void:
	_conch_remaining = conch_duration
	_conch_cooldown_remaining = conch_cooldown
	_special_velocity = (_swim_velocity + _burst_coast_velocity).move_toward(Vector2.ZERO, brake_deceleration * 0.08)
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_set_visual_rotation(_direction_rotation(direction, conch_direction_angle_degrees))
	_set_animation(&"conch")
	_stop_movement_audio()
	_play_one_shot_audio(_conch_audio)
	_trigger_camera_shake()
	normal_conch_used.emit(global_position, direction)



func _phase3_base_update_conch(delta: float) -> void:
	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_special_velocity = _special_velocity.move_toward(Vector2.ZERO, idle_momentum_deceleration * delta)
	if _conch_remaining <= 0.0:
		_set_visual_rotation(0.0)
		_set_animation(&"idle")



func _update_swim(input_direction: Vector2, delta: float) -> void:
	var swim_direction: Vector2 = _normal_swim_direction(input_direction)
	_swim_velocity = _swim_velocity.move_toward(swim_direction * swim_speed, swim_acceleration * delta)
	_set_visual_rotation(_direction_rotation(swim_direction, normal_swim_vertical_angle_degrees))
	_set_animation(&"swim")
	_play_swim_audio()



func _normal_swim_direction(input_direction: Vector2) -> Vector2:
	var vertical_axis: float = _vertical_axis(input_direction)
	if vertical_axis != 0.0:
		_update_facing_from_held_horizontal_input()
		return _facing_tilted_direction(vertical_axis, normal_swim_vertical_angle_degrees)
	if absf(input_direction.x) > 0.01:
		_facing_left = input_direction.x < 0.0
	return Vector2.LEFT if _facing_left else Vector2.RIGHT



func _update_idle(delta: float) -> void:
	_swim_velocity = _swim_velocity.move_toward(Vector2.ZERO, idle_momentum_deceleration * delta)
	if _has_burst_coast():
		_set_visual_rotation(_direction_rotation(_burst_direction, vertical_burst_angle_degrees))
		_set_animation(&"swim")
		_stop_movement_audio()
		return
	_set_visual_rotation(0.0)
	_set_animation(&"idle")
	_stop_movement_audio()



func _has_burst_coast() -> bool:
	return _burst_coast_velocity.length_squared() > 0.01



func _start_brake() -> void:
	_brake_active = true
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_burst_active = false
	_burst_elapsed = 0.0
	_burst_remaining = 0.0
	_pending_surface_jump = false
	_tail_flip_remaining = 0.0
	_conch_remaining = 0.0
	_pending_conch_remaining = 0.0
	_set_visual_rotation(0.0)
	_set_animation(&"stop")
	_stop_movement_audio()



func _phase3_base_apply_motion(motion_velocity: Vector2, idle: bool) -> void:
	var current_velocity: Vector2 = Vector2(
		current_base_velocity.x + sin(_current_time * current_sway_frequency * TAU) * current_sway_horizontal,
		current_base_velocity.y + cos(_current_time * current_sway_frequency * TAU * 0.67) * current_sway_vertical,
	)
	if idle:
		current_velocity.y += idle_sink_speed
	velocity = motion_velocity + current_velocity + _get_external_current_velocity()
	move_and_slide()
	global_position = _clamp_to_world(global_position)



func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	for source: Node in _external_currents:
		if not is_instance_valid(source):
			_external_currents.erase(source)
			continue
		total_velocity += _external_currents[source]
	return total_velocity



func _phase3_base_begin_surface_jump() -> void:
	_pending_surface_jump = false
	_burst_active = false
	_burst_elapsed = 0.0
	_burst_remaining = 0.0
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_jump_elapsed = 0.0001
	_jump_start = Vector2(global_position.x, _swim_ceiling_y)
	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end = Vector2(_jump_start.x + facing_sign * jump_forward_distance, _swim_ceiling_y + 40.0)
	global_position = _jump_start
	_set_visual_rotation(0.0)
	_set_animation(&"jump")
	_stop_movement_audio()
	surface_splash_requested.emit(_jump_start, true)



func _phase3_base_update_surface_jump(delta: float) -> void:
	_jump_elapsed += delta
	var progress: float = clampf(_jump_elapsed / maxf(0.01, jump_duration), 0.0, 1.0)
	var base_position: Vector2 = _jump_start.lerp(_jump_end, progress)
	global_position = Vector2(base_position.x, base_position.y - sin(progress * PI) * jump_arc_height)
	if progress >= 0.80 and _jump_elapsed - delta < jump_duration * 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
	if progress >= 1.0:
		_jump_elapsed = 0.0
		global_position = _clamp_to_world(_jump_end)
		_set_animation(&"idle")



func _phase3_base_set_animation(animation_name: StringName) -> void:
	if _animated_sprite.animation == animation_name:
		_animated_sprite.flip_h = _facing_left
		return
	_animated_sprite.animation = animation_name
	_animated_sprite.play()
	_animated_sprite.flip_h = _facing_left
	_update_shadow()



func _set_visual_rotation(rotation_value: float) -> void:
	_visual_rotation = rotation_value
	_animated_sprite.rotation = rotation_value
	_collision_shape.rotation = rotation_value
	_shadow_sprite.rotation = rotation_value



func _apply_display_scale() -> void:
	var first_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_animated_sprite.scale = Vector2.ONE * scale_factor
	# The shadow follows Hylas's body scale only. Its position remains the ShadowSprite node's own Inspector control.
	_shadow_sprite.scale = Vector2.ONE * scale_factor



func _update_shadow() -> void:
	var texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(_animated_sprite.animation, _animated_sprite.frame)
	_shadow_sprite.texture = texture
	_shadow_sprite.flip_h = _facing_left



func _play_tail_bubble_burst() -> void:
	_tail_bubble_burst.global_position = _get_tail_bubble_origin()
	_tail_bubble_burst.trigger()



func _get_tail_bubble_origin() -> Vector2:
	var tail_offset: Vector2 = Vector2(-120.0, 15.0)
	if _facing_left:
		tail_offset.x = -tail_offset.x
	tail_offset = tail_offset.rotated(_visual_rotation)
	return global_position + tail_offset



func _play_swim_audio() -> void:
	_stop_burst_audio()
	if _swim_audio.stream != null and not _swim_audio.playing:
		_swim_audio.play()



func _play_burst_audio() -> void:
	if _swim_audio.playing:
		_swim_audio.stop()
	if _burst_audio.stream != null and not _burst_audio.playing:
		_burst_audio.play()



func _play_one_shot_audio(player: AudioStreamPlayer) -> void:
	if player.stream == null:
		return
	player.stop()
	player.play()



func _stop_burst_audio() -> void:
	if _burst_audio.playing:
		_burst_audio.stop()



func _stop_movement_audio() -> void:
	if _swim_audio.playing:
		_swim_audio.stop()
	_stop_burst_audio()



func _trigger_camera_shake() -> void:
	_camera_shake_remaining = camera_shake_duration



func _update_camera_shake(delta: float) -> void:
	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_rest_offset
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	var ratio: float = _camera_shake_remaining / maxf(0.01, camera_shake_duration)
	var amplitude: float = camera_shake_strength * ratio
	_camera.offset = _camera_rest_offset + Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))



func _phase3_base_is_braking(input_direction: Vector2) -> bool:
	return Input.is_action_pressed(&"action_a") and (input_direction == Vector2.ZERO or _is_backward_input(input_direction))



func _is_backward_input(input_direction: Vector2) -> bool:
	if absf(input_direction.x) < 0.15:
		return false
	var facing_direction: Vector2 = Vector2.LEFT if _facing_left else Vector2.RIGHT
	return input_direction.dot(facing_direction) < -0.15



func _vertical_axis(input_direction: Vector2) -> float:
	if input_direction.y < -0.15:
		return -1.0
	if input_direction.y > 0.15:
		return 1.0
	return 0.0



func _update_facing_from_held_horizontal_input() -> void:
	var left_pressed: bool = Input.is_action_pressed(&"move_left")
	var right_pressed: bool = Input.is_action_pressed(&"move_right")
	if left_pressed == right_pressed:
		return
	_facing_left = left_pressed



func _facing_tilted_direction(vertical_axis: float, degrees: float) -> Vector2:
	var facing_axis: float = -1.0 if _facing_left else 1.0
	var radians: float = deg_to_rad(degrees)
	return Vector2(facing_axis * cos(radians), vertical_axis * sin(radians)).normalized()



func _conch_direction(input_direction: Vector2) -> Vector2:
	var vertical_axis: float = _vertical_axis(input_direction)
	if vertical_axis == 0.0:
		return Vector2.LEFT if _facing_left else Vector2.RIGHT
	_update_facing_from_held_horizontal_input()
	return _facing_tilted_direction(vertical_axis, conch_direction_angle_degrees)



func _direction_rotation(direction: Vector2, degrees: float) -> float:
	if absf(direction.y) < 0.01:
		return 0.0
	var vertical_axis: float = -1.0 if direction.y < 0.0 else 1.0
	var facing_axis: float = -1.0 if _facing_left else 1.0
	return vertical_axis * facing_axis * deg_to_rad(degrees)



func _phase3_base_clamp_to_world(position_value: Vector2) -> Vector2:
	var minimum_y: float = _world_bounds.position.y + player_edge_padding
	if _jump_elapsed <= 0.0:
		minimum_y = maxf(minimum_y, _swim_ceiling_y)
	return Vector2(
		clampf(position_value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding),
		clampf(position_value.y, minimum_y, _world_bounds.end.y - player_edge_padding),
	)



func _reset_motion_state() -> void:
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_external_currents.clear()
	_burst_active = false
	_burst_elapsed = 0.0
	_burst_remaining = 0.0
	_burst_requires_release = false
	_brake_active = false



func _phase3_base_get_debug_lines() -> Array[String]:
	return [
		"[Hylas]",
		"position=%s" % str(global_position),
		"velocity=%s" % str(velocity),
		"burst_active=%s" % str(_burst_active),
		"burst_charges=%d/%d" % [_burst_charges, burst_max_charges],
		"external_currents=%d" % _external_currents.size(),
	]





# =============================================================================
# Action presentation
# =============================================================================

func _phase3_presentation_ready() -> void:
	burst_max_duration = speed_run_gameplay_duration
	tail_flip_duration = tail_flip_gameplay_duration
	conch_duration = conch_gameplay_duration
	_phase3_base_ready()
	_configure_action_animations()
	_animated_sprite.sprite_frames.set_animation_speed(&"idle", idle_animation_fps)
	_apply_collision_profile(_animated_sprite.animation)



func _configure_action_animations() -> void:
	# Use a local copy so rebuilding Hylas's action animations does not modify
	# any other scene that happens to reference the shared SpriteFrames resource.
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
	_animated_sprite.sprite_frames = sprite_frames

	var flip_01: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 0)
	var flip_02: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 1)
	var flip_03: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 2)
	var flip_04: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 3)
	var flip_05: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 4)
	var flip_06: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 5)
	var flip_07: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 6)
	var stop_01: Texture2D = sprite_frames.get_frame_texture(&"stop", 0)
	var stop_02: Texture2D = sprite_frames.get_frame_texture(&"stop", 1)
	var stop_03: Texture2D = sprite_frames.get_frame_texture(&"stop", 2)
	var stop_04: Texture2D = sprite_frames.get_frame_texture(&"stop", 3)
	var stop_05: Texture2D = sprite_frames.get_frame_texture(&"stop", 4)
	var stop_06: Texture2D = sprite_frames.get_frame_texture(&"stop", 5)
	var stop_07: Texture2D = sprite_frames.get_frame_texture(&"stop_release", 0)

	var tail_flip_sequence: Array[Texture2D] = [
		flip_01,
		flip_02,
		flip_03,
		flip_04,
		flip_05,
		flip_06,
		flip_07,
		flip_02,
		flip_01,
		stop_06,
	]
	if not _replace_animation_frames(
			sprite_frames,
			&"tail_flip",
			tail_flip_sequence,
			tail_flip_animation_fps,
		):
		return

	var conch_01: Texture2D = sprite_frames.get_frame_texture(&"conch", 0)
	var conch_02: Texture2D = sprite_frames.get_frame_texture(&"conch", 1)
	var conch_03: Texture2D = sprite_frames.get_frame_texture(&"conch", 2)
	var conch_04: Texture2D = sprite_frames.get_frame_texture(&"conch", 3)
	var conch_05: Texture2D = sprite_frames.get_frame_texture(&"conch", 4)
	var conch_06: Texture2D = sprite_frames.get_frame_texture(&"conch", 5)

	var conch_sequence: Array[Texture2D] = [
		stop_07,
		stop_06,
		conch_01,
		conch_02,
		conch_03,
		conch_04,
		conch_05,
		conch_06,
		stop_06,
		stop_07,
	]
	if not _replace_animation_frames(
			sprite_frames,
			&"conch",
			conch_sequence,
			conch_animation_fps,
		):
		return

	var stop_sequence: Array[Texture2D] = [
		stop_07,
		stop_06,
		stop_01,
		stop_02,
		stop_03,
		stop_04,
		stop_05,
		stop_06,
	]
	_replace_animation_frames(
		sprite_frames,
		&"stop",
		stop_sequence,
		stop_animation_fps,
	)



func _replace_animation_frames(
		sprite_frames: SpriteFrames,
		animation_name: StringName,
		sequence: Array[Texture2D],
		animation_fps: float,
	) -> bool:
	for texture: Texture2D in sequence:
		if texture == null:
			push_error("%s animation is missing a required source frame." % animation_name)
			return false

	sprite_frames.clear(animation_name)
	for texture: Texture2D in sequence:
		sprite_frames.add_frame(animation_name, texture, 1.0)
	sprite_frames.set_animation_loop(animation_name, false)
	sprite_frames.set_animation_speed(animation_name, animation_fps)
	return true



func _phase3_presentation_physics_process(delta: float) -> void:
	var tail_flip_was_active: bool = (
		_tail_flip_remaining > 0.0
		and _animated_sprite.animation == &"tail_flip"
	)
	_phase3_base_physics_process(delta)
	var tail_flip_is_active: bool = (
		_tail_flip_remaining > 0.0
		and _animated_sprite.animation == &"tail_flip"
	)
	_apply_collision_profile(_animated_sprite.animation)
	if tail_flip_was_active or tail_flip_is_active:
		_report_tail_flip_slide_impacts()
	_update_stop_pose_hold()
	_update_burst_presentation()



func _phase3_presentation_start_tail_flip() -> void:
	_tail_flip_impact_target_ids.clear()
	_phase3_base_start_tail_flip()



func report_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	if _tail_flip_remaining <= 0.0 or _animated_sprite.animation != &"tail_flip":
		return
	_emit_tail_flip_impact(contact_position, normal, target)



func _is_tail_flip_strike_frame() -> bool:
	if _animated_sprite.sprite_frames == null:
		return false
	var frame_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(
		&"tail_flip",
		_animated_sprite.frame,
	)
	if frame_texture == null:
		return false
	var texture_name: String = frame_texture.resource_path.get_file()
	return (
		texture_name == NORMAL_TAIL_FLIP_STRIKE_TEXTURE
		or texture_name == GREATFIN_TAIL_FLIP_STRIKE_TEXTURE
	)



func _report_tail_flip_slide_impacts() -> void:
	if not _is_tail_flip_strike_frame():
		return
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var target: Node = collision.get_collider() as Node
		if target == null:
			continue
		_emit_tail_flip_impact(
			collision.get_position(),
			collision.get_normal(),
			target,
		)

	if _collision_shape.shape == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _collision_shape.shape
	query.transform = _collision_shape.global_transform
	query.motion = Vector2.ZERO
	query.margin = 4.0
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var rest_info: Dictionary = get_world_2d().direct_space_state.get_rest_info(query)
	if rest_info.is_empty():
		return
	var resting_target: Node = rest_info.get("collider") as Node
	if resting_target == null:
		return
	var contact_position: Vector2 = rest_info.get("point", global_position)
	var contact_normal: Vector2 = rest_info.get("normal", -_tail_flip_direction)
	_emit_tail_flip_impact(contact_position, contact_normal, resting_target)



func _emit_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if _tail_flip_impact_target_ids.has(target_id):
		return
	_tail_flip_impact_target_ids[target_id] = true
	var impact_normal: Vector2 = normal.normalized()
	if impact_normal.length_squared() <= 0.0001:
		impact_normal = -_tail_flip_direction
	tail_flip_impact.emit(contact_position, impact_normal, target)



func _phase3_presentation_update_conch(delta: float) -> void:
	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_special_velocity = _special_velocity.move_toward(
		Vector2.ZERO,
		idle_momentum_deceleration * delta,
	)

	var vertical_input: float = Input.get_axis(&"move_up", &"move_down")
	if absf(vertical_input) > 0.01:
		var vertical_axis: float = -1.0 if vertical_input < 0.0 else 1.0
		var facing_axis: float = -1.0 if _facing_left else 1.0
		var target_rotation: float = (
			vertical_axis
			* facing_axis
			* deg_to_rad(conch_direction_angle_degrees)
		)
		var rotation_step: float = deg_to_rad(conch_steer_speed_degrees) * delta
		_set_visual_rotation(move_toward(_visual_rotation, target_rotation, rotation_step))

	if _conch_remaining <= 0.0:
		_set_visual_rotation(0.0)
		_set_animation(&"idle")



func _phase3_presentation_set_animation(animation_name: StringName) -> void:
	_phase3_base_set_animation(animation_name)
	_apply_collision_profile(animation_name)



func _apply_collision_profile(animation_name: StringName) -> void:
	var target_shape: Shape2D = default_collision_shape
	var target_profile: StringName = &"default"

	if animation_name == &"tail_flip":
		target_shape = tail_flip_collision_shape
		target_profile = &"tail_flip"
	elif animation_name == &"conch":
		target_shape = conch_collision_shape
		target_profile = &"conch"
	elif animation_name == &"stop" or animation_name == &"stop_release":
		target_shape = stop_collision_shape
		target_profile = &"stop"

	if target_shape == null:
		return
	if _collision_shape.shape != target_shape:
		_collision_shape.shape = target_shape
	_collision_profile_name = target_profile



func _update_stop_pose_hold() -> void:
	# Shift can remain held while another action starts. Never let the retained
	# stop pose overwrite an active Tail Flip, conch, burst, or jump animation.
	if _tail_flip_remaining > 0.0 or _conch_remaining > 0.0 or _burst_active or _jump_elapsed > 0.0:
		_stop_pose_held = false
		return

	if _animated_sprite.animation == &"stop":
		_stop_pose_held = true
	if not Input.is_action_pressed(&"action_a"):
		_stop_pose_held = false
		return
	if not _stop_pose_held:
		return

	var last_stop_frame: int = _animated_sprite.sprite_frames.get_frame_count(&"stop") - 1
	if _animated_sprite.animation != &"stop":
		_animated_sprite.animation = &"stop"
		_animated_sprite.frame = last_stop_frame
		_animated_sprite.pause()
		return
	if _animated_sprite.frame >= last_stop_frame:
		_animated_sprite.frame = last_stop_frame
		_animated_sprite.pause()



func _update_burst_presentation() -> void:
	if not _burst_active or _animated_sprite.animation != &"burst":
		return

	var burst_frame: int = 0
	if _burst_elapsed < speed_run_startup_frame_duration:
		burst_frame = 0 # hylas-speed_02.webp
	elif _burst_elapsed < speed_run_hold_start:
		burst_frame = 1 # hylas-speed_03.webp
	elif _burst_elapsed < speed_run_hold_end:
		burst_frame = 2 # hylas-speed_04.webp
	else:
		var finish_elapsed: float = _burst_elapsed - speed_run_hold_end
		var finish_step: int = floori(finish_elapsed / maxf(0.01, speed_run_finish_frame_duration))
		burst_frame = 3 + (finish_step % 2) # Alternates hylas-speed_05 and _06.

	_animated_sprite.frame = burst_frame
	_animated_sprite.pause()





# =============================================================================
# Land movement
# =============================================================================

func _phase3_land_ready() -> void:
	_phase3_presentation_ready()
	splash.process_mode = Node.PROCESS_MODE_ALWAYS
	hurt_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	land_impact_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	fin_loss_audio.process_mode = Node.PROCESS_MODE_ALWAYS



func _phase3_land_physics_process(delta: float) -> void:
	if crawl_active:
		crawl_update(delta)
		return
	if airborne_active:
		airborne_update(delta)
		return

	_tail_flip_combo_frame = Input.is_action_just_pressed(&"tail_flip")
	if _tail_flip_combo_frame:
		_try_start_tail_flip_combo()

	_phase3_presentation_physics_process(delta)
	_tail_flip_combo_frame = false



func _try_start_tail_flip_combo() -> void:
	if _burst_active or _tail_flip_remaining > 0.0 or _conch_remaining > 0.0 or _jump_elapsed > 0.0:
		return
	if _tail_flip_cooldown_remaining > 0.0:
		return
	_brake_active = false
	_pending_conch_remaining = 0.0
	_start_tail_flip()



func _phase3_land_is_braking(input_direction: Vector2) -> bool:
	if _tail_flip_combo_frame:
		return false
	return _phase3_base_is_braking(input_direction)



func _phase3_land_handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_combo_frame:
		return
	if _burst_active or _tail_flip_remaining > 0.0 or _jump_elapsed > 0.0:
		return
	if _conch_cooldown_remaining <= 0.0:
		_pending_conch_remaining = 0.0
		_start_conch(_conch_direction(input_direction))



func _phase3_land_begin_surface_jump() -> void:
	crawl_active = false
	airborne_active = true
	left_water = false
	entry_splash_done = false
	_phase3_base_begin_surface_jump()
	var facing_sign := -1.0 if _facing_left else 1.0
	velocity = Vector2(facing_sign * jump_horizontal_speed, -jump_launch_upward_speed)
	play_splash()



func airborne_update(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()
	_jump_elapsed += delta
	velocity.y += land_gravity * delta
	var was_descending := velocity.y > 0.0
	move_and_slide()
	global_position = clamp_airborne_position(global_position)

	if global_position.y < _swim_ceiling_y:
		left_water = true
	if was_descending and _has_ground_collision():
		begin_crawl()
		return
	if left_water and velocity.y > 0.0 and global_position.y >= _swim_ceiling_y:
		enter_water()



func _has_ground_collision() -> bool:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision != null and collision.get_normal().y < -0.2:
			return true
	return false



func _phase3_land_begin_crawl() -> void:
	airborne_active = false
	crawl_active = true
	_jump_elapsed = 0.0
	_pending_surface_jump = false
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	_set_animation(&"crawl")
	_stop_movement_audio()
	play_hurt_sound()
	play_land_impact_sound()



func enter_water() -> void:
	airborne_active = false
	_jump_elapsed = 0.0
	velocity = Vector2.ZERO
	global_position.y = _swim_ceiling_y + crawl_water_reentry_depth
	if not entry_splash_done:
		entry_splash_done = true
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
		play_splash()
	_set_visual_rotation(0.0)
	_set_animation(&"idle")



func crawl_update(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var floor_normal := get_floor_normal()
	var ground_tangent := Vector2(-floor_normal.y, floor_normal.x)
	var crawl_axis := direction.dot(ground_tangent)
	if absf(crawl_axis) > 0.01:
		_facing_left = crawl_axis < 0.0
	velocity = ground_tangent * crawl_axis * crawl_speed
	velocity.y += land_gravity * delta
	_set_visual_rotation(0.0)
	_stop_movement_audio()
	_set_animation(&"crawl")
	if absf(crawl_axis) <= 0.01:
		_animated_sprite.frame = 0
		_animated_sprite.pause()
	else:
		_animated_sprite.play()
	move_and_slide()
	global_position = _clamp_to_world(global_position)
	if not is_on_floor():
		crawl_active = false
		airborne_active = true
		_set_animation(&"jump")
		_animated_sprite.frame = _animated_sprite.sprite_frames.get_frame_count(&"jump") - 1
		_animated_sprite.pause()
		return
	if global_position.y >= _swim_ceiling_y + crawl_water_reentry_depth:
		crawl_active = false
		velocity = Vector2.ZERO
		_set_animation(&"idle")



func clamp_airborne_position(value: Vector2) -> Vector2:
	return Vector2(
		clampf(value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding),
		clampf(value.y, _world_bounds.position.y + player_edge_padding, _world_bounds.end.y - player_edge_padding),
	)



func _clamp_to_world(value: Vector2) -> Vector2:
	var minimum_y := _world_bounds.position.y + player_edge_padding
	if not crawl_active and not airborne_active and _jump_elapsed <= 0.0:
		minimum_y = maxf(minimum_y, _swim_ceiling_y)
	return Vector2(
		clampf(value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding),
		clampf(value.y, minimum_y, _world_bounds.end.y - player_edge_padding),
	)



func play_splash() -> void:
	if splash.stream != null:
		splash.stop()
		splash.play()



func play_hurt_sound() -> void:
	if hurt_audio.stream != null:
		hurt_audio.stop()
		hurt_audio.play()



func play_fin_loss_sound() -> void:
	play_hurt_sound()
	if fin_loss_audio.stream != null:
		fin_loss_audio.stop()
		fin_loss_audio.play()



func play_land_impact_sound() -> void:
	if land_impact_audio.stream != null:
		land_impact_audio.stop()
		land_impact_audio.play()





# =============================================================================
# Reliable input and death
# =============================================================================

func _phase3_input_ready() -> void:
	_phase3_land_ready()
	_normal_camera_rest_offset = _camera_rest_offset
	_configure_death_animations()
	if not _animated_sprite.animation_finished.is_connected(_on_animation_finished):
		_animated_sprite.animation_finished.connect(_on_animation_finished)



func _phase3_input_input(event: InputEvent) -> void:
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var is_space: bool = (
		key_event.keycode == KEY_SPACE
		or key_event.physical_keycode == KEY_SPACE
		or key_event.unicode == 32
	)
	if not is_space:
		return

	var shift_is_held: bool = (
		key_event.shift_pressed
		or Input.is_action_pressed(&"action_a")
		or Input.is_key_pressed(KEY_SHIFT)
	)
	if shift_is_held:
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	_space_action_pressed_this_frame = true



func _phase3_input_physics_process(delta: float) -> void:
	if _death_sequence_active:
		_update_death_sequence(delta)
		return

	_tail_flip_chord_active = _shift_space_tail_flip_requested
	_shift_space_tail_flip_requested = false

	if _tail_flip_chord_active:
		_brake_active = false
		_pending_conch_remaining = 0.0
		_pending_interaction_remaining = 0.0
		if (
			not _burst_active
			and _tail_flip_remaining <= 0.0
			and _conch_remaining <= 0.0
			and _jump_elapsed <= 0.0
			and _tail_flip_cooldown_remaining <= 0.0
		):
			_start_tail_flip()

	# Shift by itself owns the stop pose. As soon as any movement direction is
	# held, that same Shift press becomes the speed-run modifier regardless of
	# which input was pressed first.
	var movement_input: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	if (
		_brake_active
		and Input.is_action_pressed(&"action_a")
		and movement_input.length_squared() > 0.0001
	):
		_brake_active = false

	_phase3_land_physics_process(delta)
	_update_pending_interaction(delta)
	_space_action_pressed_this_frame = false
	_tail_flip_chord_active = false



func reset_to_start(start_position: Vector2) -> void:
	_clear_death_state(false)
	_phase3_base_reset_to_start(start_position)



func _phase3_input_start_death_sequence() -> void:
	if _death_sequence_active:
		return
	_death_sequence_active = true
	_death_drift_active = false
	_death_body_landed = false
	_death_camera_elapsed = 0.0
	_death_camera_start_offset = _camera_rest_offset
	_play_enabled = false
	crawl_active = false
	airborne_active = false
	left_water = false
	entry_splash_done = false
	_pending_interaction_remaining = 0.0
	_space_action_pressed_this_frame = false
	_shift_space_tail_flip_requested = false
	_tail_flip_chord_active = false
	_reset_motion_state()
	velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	_stop_movement_audio()
	_set_animation(DEATH_INTRO_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.play()
	set_physics_process(true)



func _phase3_input_cancel_death_sequence() -> void:
	_clear_death_state(true)



func is_death_sequence_active() -> bool:
	return _death_sequence_active



func has_death_body_landed() -> bool:
	return _death_body_landed



func get_pickup_feedback_anchor_position() -> Vector2:
	var local_offset: Vector2 = pickup_feedback_hand_offset
	if _facing_left:
		local_offset.x = -local_offset.x
	return global_position + local_offset.rotated(_visual_rotation)



func set_interaction_available(is_available: bool) -> void:
	if _interaction_available == is_available:
		return
	_interaction_available = is_available
	if not _interaction_available:
		_pending_interaction_remaining = 0.0
	interaction_availability_changed.emit(_interaction_available)



func is_interaction_available() -> bool:
	return _interaction_available



func cancel_pending_interaction() -> void:
	_pending_interaction_remaining = 0.0



func _is_braking(input_direction: Vector2) -> bool:
	if _tail_flip_chord_active or _tail_flip_remaining > 0.0:
		return false
	if not _has_brakeable_motion():
		return false
	return _phase3_land_is_braking(input_direction)



func _has_brakeable_motion() -> bool:
	if _burst_active:
		return true
	var controlled_motion: Vector2 = _swim_velocity + _burst_coast_velocity + _special_velocity
	return controlled_motion.length() >= brake_minimum_speed



func _phase3_input_handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active:
		return

	# J and other direct conch bindings bypass interaction routing. Only the raw
	# Space press recorded in _input() participates in this single/double rule.
	if not _space_action_pressed_this_frame or not _interaction_available:
		_phase3_land_handle_conch_pressed(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		_phase3_land_handle_conch_pressed(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window



func _update_pending_interaction(delta: float) -> void:
	if _pending_interaction_remaining <= 0.0:
		return
	_pending_interaction_remaining = maxf(0.0, _pending_interaction_remaining - delta)
	if _pending_interaction_remaining <= 0.0 and _interaction_available:
		interaction_requested.emit()



func _configure_death_animations() -> void:
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames
	if sprite_frames.has_animation(DEATH_INTRO_ANIMATION):
		sprite_frames.remove_animation(DEATH_INTRO_ANIMATION)
	if sprite_frames.has_animation(DEATH_DRIFT_ANIMATION):
		sprite_frames.remove_animation(DEATH_DRIFT_ANIMATION)

	sprite_frames.add_animation(DEATH_INTRO_ANIMATION)
	for texture: Texture2D in [DIE_01, DIE_02, DIE_03, DIE_04, DIE_05, DIE_06]:
		sprite_frames.add_frame(DEATH_INTRO_ANIMATION, texture)
	sprite_frames.set_animation_speed(DEATH_INTRO_ANIMATION, death_intro_fps)
	sprite_frames.set_animation_loop(DEATH_INTRO_ANIMATION, false)

	sprite_frames.add_animation(DEATH_DRIFT_ANIMATION)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_07)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_08)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_09)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_08)
	sprite_frames.set_animation_speed(DEATH_DRIFT_ANIMATION, death_drift_fps)
	sprite_frames.set_animation_loop(DEATH_DRIFT_ANIMATION, true)



func _phase3_input_update_death_sequence(delta: float) -> void:
	_current_time += delta
	_update_death_camera(delta)
	_update_camera_shake(delta)
	_update_shadow()
	if not _death_drift_active or _death_body_landed:
		velocity = Vector2.ZERO
		return

	velocity = Vector2.DOWN * death_drift_speed
	move_and_slide()
	global_position = _clamp_to_world(global_position)
	if _has_death_floor_collision() or global_position.y >= _world_bounds.end.y - player_edge_padding:
		_death_body_landed = true
		velocity = Vector2.ZERO
		death_landed.emit()



func _update_death_camera(delta: float) -> void:
	_death_camera_elapsed = minf(
		death_camera_recenter_seconds,
		_death_camera_elapsed + delta,
	)
	var progress: float = clampf(
		_death_camera_elapsed / maxf(0.05, death_camera_recenter_seconds),
		0.0,
		1.0,
	)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var target_offset: Vector2 = _normal_camera_rest_offset + Vector2(
		0.0,
		death_camera_vertical_offset,
	)
	_camera_rest_offset = _death_camera_start_offset.lerp(target_offset, eased_progress)



func _has_death_floor_collision() -> bool:
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision != null and collision.get_normal().y < -0.2:
			return true
	return false



func _phase3_input_on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_set_animation(DEATH_DRIFT_ANIMATION)
	death_drift_started.emit()



func _clear_death_state(reset_visual: bool) -> void:
	_death_sequence_active = false
	_death_drift_active = false
	_death_body_landed = false
	_death_camera_elapsed = 0.0
	velocity = Vector2.ZERO
	_camera_rest_offset = _normal_camera_rest_offset
	if is_instance_valid(_camera):
		_camera.offset = _normal_camera_rest_offset
	if reset_visual and is_instance_valid(_animated_sprite):
		_set_visual_rotation(0.0)
		_set_animation(&"idle")
	set_physics_process(_play_enabled)



func _phase3_input_get_debug_lines() -> Array[String]:
	var lines: Array[String] = _phase3_base_get_debug_lines()
	lines.append("tail_flip_remaining=%.2f" % _tail_flip_remaining)
	lines.append("tail_flip_chord_active=%s" % str(_tail_flip_chord_active))
	lines.append("brakeable_motion=%s" % str(_has_brakeable_motion()))
	lines.append("interaction_available=%s" % str(_interaction_available))
	lines.append("pending_interaction=%.2f" % _pending_interaction_remaining)
	lines.append("death_sequence_active=%s" % str(_death_sequence_active))
	lines.append("death_drift_active=%s" % str(_death_drift_active))
	lines.append("death_body_landed=%s" % str(_death_body_landed))
	lines.append("death_camera_offset=%s" % str(_camera_rest_offset))
	return lines





# =============================================================================
# Equipment input
# =============================================================================

func _phase3_equipment_ready() -> void:
	_phase3_input_ready()
	_normal_collision_layer = collision_layer
	_conus_climb_sprite_base_position = _animated_sprite.position
	_conus_climb_normal_sprite_scale = _animated_sprite.scale
	_item_visuals.set_equipped_item_a(_equipped_item_a)
	_sync_equipped_conch_audio()



func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id if not String(item_id).is_empty() else NORMAL_CONCH_ID
	if is_instance_valid(_item_visuals):
		_item_visuals.set_equipped_item_a(_equipped_item_a)
	_sync_equipped_conch_audio()



func get_equipped_item_a() -> StringName:
	return _equipped_item_a



func _sync_equipped_conch_audio() -> void:
	if not is_instance_valid(_conch_audio):
		return
	_conch_audio.stop()
	match _equipped_item_a:
		NORMAL_CONCH_ID:
			_conch_audio.stream = NORMAL_CONCH_AUDIO_STREAM
		SUPER_CONCH_ID:
			_conch_audio.stream = SUPER_CONCH_AUDIO_STREAM
		_:
			# Terebridae and Conus play their dedicated audio from the item controller.
			_conch_audio.stream = null



func _phase3_equipment_activate_normal_conch(direction: Vector2) -> bool:
	if not _can_begin_item_pose():
		return false
	if _conch_cooldown_remaining > 0.0:
		return false

	var resolved_direction: Vector2 = _resolve_item_direction(direction)
	_pending_conch_remaining = 0.0
	_start_conch(resolved_direction)
	return true



func _phase3_equipment_activate_item_a_pose(direction: Vector2) -> bool:
	if not _can_begin_item_pose() or _conch_cooldown_remaining > 0.0:
		return false
	var resolved_direction: Vector2 = _resolve_item_direction(direction)
	_pending_conch_remaining = 0.0
	_start_item_a_pose(resolved_direction)
	return true



func _phase3_equipment_activate_item_surge(duration_seconds: float = 0.90) -> bool:
	if (
			_death_sequence_active
			or not _play_enabled
			or crawl_active
			or airborne_active
			or _tail_flip_remaining > 0.0
			or _jump_elapsed > 0.0
			or _conch_remaining > 0.0
			or _burst_active
		):
		return false

	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	if input_direction.length_squared() <= 0.0001:
		input_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT

	var previous_charges: int = _burst_charges
	var previous_charge_timer: float = _burst_charge_timer
	_burst_charges = maxi(1, _burst_charges)
	_item_surge_remaining = maxf(0.05, duration_seconds)
	_start_burst(input_direction)
	_burst_charges = previous_charges
	_burst_charge_timer = previous_charge_timer
	if not _burst_active:
		_item_surge_remaining = 0.0
		return false
	return true



func is_item_surge_active() -> bool:
	return _item_surge_remaining > 0.0 and _burst_active



func _phase3_equipment_begin_surface_jump() -> void:
	var use_tridacna_launch: bool = _item_surge_remaining > 0.0
	_phase3_land_begin_surface_jump()
	if use_tridacna_launch and airborne_active:
		velocity *= TRIDACNA_SURFACE_LAUNCH_VELOCITY_SCALE



func _phase3_equipment_begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if _death_sequence_active or not _play_enabled or not is_instance_valid(tether):
		return
	_conus_climb_active = true
	_conus_climb_anchor = anchor_position
	_conus_climb_tether = tether
	_conus_climb_wait_for_conch_release = Input.is_action_pressed(&"conch")
	_conus_climb_maximum_distance = maxf(
		conus_climb_minimum_distance,
		global_position.distance_to(anchor_position),
	)
	_conus_climb_previous_facing_left = _facing_left
	_facing_left = false
	_brake_active = false
	_burst_active = false
	_burst_remaining = 0.0
	_tail_flip_remaining = 0.0
	_conch_remaining = 0.0
	_pending_conch_remaining = 0.0
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_stop_movement_audio()
	_animated_sprite.speed_scale = 1.0
	_set_animation(CONUS_CLIMB_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.pause()
	_align_to_conus_rope()



func _phase3_equipment_end_conus_wall_climb(tether: Node = null) -> void:
	if not _conus_climb_active:
		return
	if tether != null and is_instance_valid(_conus_climb_tether) and tether != _conus_climb_tether:
		return
	_conus_climb_active = false
	_conus_climb_tether = null
	_conus_climb_wait_for_conch_release = false
	_conus_climb_maximum_distance = 0.0
	_facing_left = _conus_climb_previous_facing_left
	_animated_sprite.speed_scale = 1.0
	velocity = Vector2.ZERO
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_animated_sprite.position = _conus_climb_sprite_base_position
	_set_visual_rotation(0.0)
	if _play_enabled and not _death_sequence_active:
		_set_animation(&"idle")



func is_conus_wall_climbing() -> bool:
	return _conus_climb_active



func _phase3_equipment_get_conus_rope_origin() -> Vector2:
	if _conus_climb_active:
		var rope_vector: Vector2 = _conus_climb_anchor - global_position
		if rope_vector.length_squared() > 0.0001:
			return global_position + rope_vector.normalized() * conus_rope_hand_offset
	var marker: Node2D = get_node_or_null("ConchPulseOrigin") as Node2D
	return marker.global_position if marker != null else global_position



func set_purple_shield_active(is_active: bool) -> void:
	_purple_shield_active = is_active



func is_purple_shield_active() -> bool:
	return _purple_shield_active



func set_camouflage_active(is_active: bool) -> void:
	_camouflage_active = is_active
	collision_layer = 0 if is_active else _normal_collision_layer
	if is_instance_valid(_item_visuals):
		_item_visuals.set_camouflage_active(is_active)



func is_camouflage_active() -> bool:
	return _camouflage_active



func is_contact_immune() -> bool:
	return _purple_shield_active or _camouflage_active



func set_surge_glow_active(is_active: bool) -> void:
	if is_instance_valid(_item_visuals):
		_item_visuals.set_surge_glow_active(is_active)



func _phase3_equipment_clear_item_effect_state() -> void:
	end_conus_wall_climb()
	_item_surge_remaining = 0.0
	_purple_shield_active = false
	_camouflage_active = false
	collision_layer = _normal_collision_layer
	if is_instance_valid(_item_visuals):
		_item_visuals.clear_item_visuals()



func set_play_enabled(enabled: bool) -> void:
	_phase3_base_set_play_enabled(enabled)
	if not enabled:
		clear_item_effect_state()



func _input(event: InputEvent) -> void:
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return

	if _conus_climb_active:
		# Climb retraction is owned by _physics_process so firing and retraction
		# read the same Input action state.
		return

	# Exact matching is essential because Item A, Item B and Tail Flip can share
	# the same base key while differing only by their modifiers.
	if event.is_action_pressed(&"utility_item", false, true):
		_utility_item_pressed_this_frame = true
		_space_action_pressed_this_frame = false
		_pending_interaction_remaining = 0.0
		_pending_conch_remaining = 0.0
		return

	if event.is_action_pressed(&"tail_flip", false, true):
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"conch", false, true):
		_space_action_pressed_this_frame = _is_primary_item_a_binding(event)



func _physics_process(delta: float) -> void:
	_item_surge_remaining = maxf(0.0, _item_surge_remaining - delta)
	if _conus_climb_active:
		if _conus_climb_wait_for_conch_release:
			if not Input.is_action_pressed(&"conch"):
				_conus_climb_wait_for_conch_release = false
		elif Input.is_action_just_pressed(&"conch"):
			_space_action_pressed_this_frame = false
			_pending_conch_remaining = 0.0
			_pending_interaction_remaining = 0.0
			_utility_item_pressed_this_frame = false
			if is_instance_valid(_conus_climb_tether) and _conus_climb_tether.has_method(&"retract"):
				_conus_climb_tether.call(&"retract")
			else:
				end_conus_wall_climb()
			return
		_update_conus_wall_climb(delta)
		_utility_item_pressed_this_frame = false
		return
	_phase3_input_physics_process(delta)
	_utility_item_pressed_this_frame = false



func _is_burst_input_held(input_direction: Vector2) -> bool:
	if _item_surge_remaining > 0.0:
		return true
	return _phase3_base_is_burst_input_held(input_direction)



func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active or _utility_item_pressed_this_frame:
		return

	if not _space_action_pressed_this_frame or not _interaction_available:
		_request_equipped_item_a(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		_request_equipped_item_a(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window



func _is_primary_item_a_binding(event: InputEvent) -> bool:
	var bindings: Array[InputEvent] = InputMap.action_get_events(&"conch")
	if bindings.is_empty():
		return true
	return event.is_match(bindings[0], true)



func _request_equipped_item_a(input_direction: Vector2) -> bool:
	if not _can_begin_item_pose():
		return false

	var direction: Vector2 = _conch_direction(input_direction)
	if _equipped_item_a == NORMAL_CONCH_ID:
		return activate_normal_conch(direction)

	if String(_equipped_item_a).is_empty():
		return false

	_pending_conch_remaining = 0.0
	item_a_requested.emit(_equipped_item_a, global_position, direction)
	return true



func _can_begin_item_pose() -> bool:
	return not (
		_death_sequence_active
		or not _play_enabled
		or crawl_active
		or airborne_active
		or _conus_climb_active
		or _burst_active
		or _tail_flip_remaining > 0.0
		or _jump_elapsed > 0.0
	)



func _phase3_equipment_update_conus_wall_climb(delta: float) -> void:
	if (
			not is_instance_valid(_conus_climb_tether)
			or not _conus_climb_tether.has_method(&"is_wall_tethered")
			or not bool(_conus_climb_tether.call(&"is_wall_tethered"))
		):
		end_conus_wall_climb()
		return
	if _conus_climb_tether.has_method(&"get_anchor_position"):
		var anchor_value: Variant = _conus_climb_tether.call(&"get_anchor_position")
		if anchor_value is Vector2:
			_conus_climb_anchor = anchor_value

	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()

	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		end_conus_wall_climb(_conus_climb_tether)
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	var rope_distance: float = rope_vector.length()
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	var climb_axis: float = input_direction.dot(rope_direction)
	if absf(climb_axis) < conus_climb_input_deadzone:
		climb_axis = 0.0
	if climb_axis > 0.0 and rope_distance <= conus_climb_minimum_distance:
		climb_axis = 0.0
	elif climb_axis < 0.0 and rope_distance >= _conus_climb_maximum_distance:
		climb_axis = 0.0

	velocity = rope_direction * climb_axis * conus_climb_speed
	if climb_axis != 0.0:
		move_and_slide()
		global_position = _clamp_to_world(global_position)

	var corrected_vector: Vector2 = _conus_climb_anchor - global_position
	var corrected_distance: float = corrected_vector.length()
	if corrected_distance > 0.0001:
		var corrected_direction: Vector2 = corrected_vector / corrected_distance
		if corrected_distance > _conus_climb_maximum_distance:
			global_position = _conus_climb_anchor - corrected_direction * _conus_climb_maximum_distance
		elif corrected_distance < conus_climb_minimum_distance:
			global_position = _conus_climb_anchor - corrected_direction * conus_climb_minimum_distance

	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_align_to_conus_rope()
	_update_conus_climb_animation(climb_axis)



func _phase3_equipment_align_to_conus_rope() -> void:
	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	_set_visual_rotation(rope_direction.angle() + PI * 0.5)
	var normal_scale_x: float = maxf(absf(_conus_climb_normal_sprite_scale.x), 0.001)
	var greatfin_active: bool = absf(_animated_sprite.scale.x) > normal_scale_x * 1.15
	if greatfin_active:
		_animated_sprite.position = _conus_climb_sprite_base_position
	else:
		var rope_perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
		_animated_sprite.position = (
			_conus_climb_sprite_base_position
			+ rope_perpendicular * normal_conus_climb_sprite_perpendicular_offset
		)



func _phase3_equipment_update_conus_climb_animation(climb_axis: float) -> void:
	if _animated_sprite.animation != CONUS_CLIMB_ANIMATION:
		_set_animation(CONUS_CLIMB_ANIMATION)
	if climb_axis == 0.0:
		_animated_sprite.speed_scale = 1.0
		_animated_sprite.frame = 0
		_animated_sprite.pause()
		return
	var desired_speed: float = 1.0 if climb_axis > 0.0 else -1.0
	if not _animated_sprite.is_playing() or not is_equal_approx(_animated_sprite.speed_scale, desired_speed):
		_animated_sprite.speed_scale = desired_speed
		if desired_speed < 0.0 and _animated_sprite.frame == 0:
			_animated_sprite.frame = _animated_sprite.sprite_frames.get_frame_count(CONUS_CLIMB_ANIMATION) - 1
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)



func _resolve_item_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return _conch_direction(Vector2.ZERO)
	return direction.normalized()



func _start_item_a_pose(direction: Vector2) -> void:
	_conch_remaining = conch_duration
	_conch_cooldown_remaining = conch_cooldown
	_special_velocity = (_swim_velocity + _burst_coast_velocity).move_toward(
		Vector2.ZERO,
		brake_deceleration * 0.08,
	)
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_set_visual_rotation(_direction_rotation(direction, conch_direction_angle_degrees))
	_set_animation(&"conch")
	_stop_movement_audio()
	_play_one_shot_audio(_conch_audio)
	_trigger_camera_shake()



func _phase3_equipment_get_debug_lines() -> Array[String]:
	var lines: Array[String] = _phase3_input_get_debug_lines()
	lines.append("equipped_item_a=%s" % String(_equipped_item_a))
	lines.append("utility_item_pressed_this_frame=%s" % str(_utility_item_pressed_this_frame))
	lines.append("item_surge_remaining=%.2f" % _item_surge_remaining)
	lines.append("purple_shield_active=%s" % str(_purple_shield_active))
	lines.append("camouflage_active=%s" % str(_camouflage_active))
	lines.append("conus_climb_active=%s" % str(_conus_climb_active))
	lines.append("conus_climb_anchor=%s" % str(_conus_climb_anchor))
	if is_instance_valid(_item_visuals):
		lines.append_array(_item_visuals.get_debug_lines())
	return lines





# =============================================================================
# Phase 6 corrections
# =============================================================================

func activate_normal_conch(direction: Vector2) -> bool:
	var activated: bool = _phase3_equipment_activate_normal_conch(direction)
	if activated:
		_apply_conch_recoil(_resolve_item_direction(direction), normal_conch_recoil_speed)
	return activated



func activate_item_a_pose(direction: Vector2) -> bool:
	var activated: bool = _phase3_equipment_activate_item_a_pose(direction)
	if activated:
		_apply_conch_recoil(_resolve_item_direction(direction), _get_equipped_conch_recoil_speed())
	return activated



func _phase3_phase6_activate_item_surge(duration_seconds: float = 30.0) -> bool:
	var activated: bool = _phase3_equipment_activate_item_surge(duration_seconds)
	if not activated:
		return false
	var direction: Vector2 = _burst_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	surge_ram_started.emit(global_position, direction.normalized(), duration_seconds)
	return true



func _get_equipped_conch_recoil_speed() -> float:
	match _equipped_item_a:
		SUPER_CONCH_ID:
			return super_conch_recoil_speed
		&"terebridae":
			return terebridae_recoil_speed
		_:
			return 0.0



func _apply_conch_recoil(direction: Vector2, recoil_speed: float) -> void:
	if recoil_speed <= 0.0:
		return
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return
	if _conus_climb_active:
		return
	var recoil_direction: Vector2 = direction
	if recoil_direction.length_squared() <= 0.0001:
		recoil_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_special_velocity += -recoil_direction.normalized() * recoil_speed



func hold_current_item_pose_for_duration(duration_seconds: float) -> void:
	if duration_seconds <= 0.0 or not is_instance_valid(_animated_sprite):
		return
	if _animated_sprite.animation != &"conch":
		return
	_terebridae_pose_active = true
	_terebridae_release_active = false
	_terebridae_stream_remaining = duration_seconds
	_terebridae_release_remaining = 0.0
	var release_duration: float = 1.0 / maxf(0.1, conch_animation_fps)
	_conch_remaining = maxf(_conch_remaining, duration_seconds + release_duration)
	if not _animated_sprite.is_playing():
		_animated_sprite.play(&"conch")



func _update_conch(delta: float) -> void:
	if not _terebridae_pose_active:
		_phase3_presentation_update_conch(delta)
		return

	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_update_terebridae_motion(delta)

	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"conch")
	var hold_frame: int = _get_terebridae_hold_frame(frame_count)
	var release_frame: int = _get_terebridae_release_frame(frame_count)

	if _terebridae_stream_remaining > 0.0:
		_terebridae_stream_remaining = maxf(0.0, _terebridae_stream_remaining - delta)
		if _animated_sprite.animation != &"conch":
			_set_animation(&"conch")
		if _animated_sprite.frame >= hold_frame:
			_animated_sprite.frame = hold_frame
			_animated_sprite.pause()
		return

	if not _terebridae_release_active:
		_terebridae_release_active = true
		_terebridae_release_remaining = 1.0 / maxf(0.1, conch_animation_fps)
		_animated_sprite.animation = &"conch"
		_animated_sprite.frame = release_frame
		_animated_sprite.pause()
		return

	_terebridae_release_remaining = maxf(0.0, _terebridae_release_remaining - delta)
	_animated_sprite.animation = &"conch"
	_animated_sprite.frame = release_frame
	_animated_sprite.pause()
	if _terebridae_release_remaining <= 0.0:
		_finish_terebridae_pose()



func _update_terebridae_motion(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	if input_direction.length_squared() <= 0.0001:
		_special_velocity = _special_velocity.move_toward(
			Vector2.ZERO,
			idle_momentum_deceleration * delta,
		)
		return

	var swim_direction: Vector2 = _normal_swim_direction(input_direction)
	_special_velocity = _special_velocity.move_toward(
		swim_direction * swim_speed,
		swim_acceleration * delta,
	)
	_set_visual_rotation(
		_direction_rotation(swim_direction, normal_swim_vertical_angle_degrees)
	)
	_animated_sprite.flip_h = _facing_left



func _get_terebridae_hold_frame(frame_count: int) -> int:
	if frame_count >= 10:
		return NORMAL_TEREBRIDAE_HOLD_FRAME_INDEX
	return maxi(0, frame_count - 2)



func _get_terebridae_release_frame(frame_count: int) -> int:
	if frame_count >= 10:
		return NORMAL_TEREBRIDAE_RELEASE_FRAME_INDEX
	return maxi(0, frame_count - 1)



func _finish_terebridae_pose() -> void:
	_clear_terebridae_pose_state()
	_conch_remaining = 0.0
	_set_visual_rotation(0.0)
	if _play_enabled and not _death_sequence_active:
		_set_animation(&"idle")



func _clear_terebridae_pose_state() -> void:
	_terebridae_pose_active = false
	_terebridae_release_active = false
	_terebridae_stream_remaining = 0.0
	_terebridae_release_remaining = 0.0



func _phase3_phase6_begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if is_instance_valid(_animated_sprite):
		_conus_climb_previous_visual_scale = _animated_sprite.scale
		_conus_climb_previous_animation = _animated_sprite.animation
		_conus_climb_previous_frame = _animated_sprite.frame
	_conus_climb_started = false
	_conus_wait_for_direction_release = true
	_phase3_equipment_begin_conus_wall_climb(anchor_position, tether)
	if not _conus_climb_active or not is_instance_valid(_animated_sprite):
		return

	_facing_left = _conus_climb_previous_facing_left
	_animated_sprite.scale = _conus_climb_previous_visual_scale
	var conch_frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"conch")
	_animated_sprite.animation = &"conch"
	_animated_sprite.frame = _get_terebridae_hold_frame(conch_frame_count)
	_animated_sprite.flip_h = _facing_left
	_animated_sprite.pause()



func end_conus_wall_climb(tether: Node = null) -> void:
	var was_climbing: bool = _conus_climb_active
	var restore_scale: Vector2 = _conus_climb_previous_visual_scale
	_phase3_equipment_end_conus_wall_climb(tether)
	if was_climbing and not _conus_climb_active and is_instance_valid(_animated_sprite):
		_animated_sprite.scale = restore_scale
		_conus_climb_started = false
		_conus_wait_for_direction_release = false



func get_conus_rope_origin() -> Vector2:
	if (
			_conus_climb_active
			and not _conus_climb_started
			and is_instance_valid(_item_visuals)
		):
		return _item_visuals.get_shell_rope_origin()
	if (
			not _conus_climb_active
			and is_instance_valid(_animated_sprite)
			and _animated_sprite.animation == &"conch"
			and is_instance_valid(_item_visuals)
		):
		return _item_visuals.get_shell_rope_origin()
	if _conus_climb_active:
		var rope_vector: Vector2 = _conus_climb_anchor - global_position
		if rope_vector.length_squared() > 0.0001:
			return (
				global_position
				+ rope_vector.normalized()
				* conus_rope_hand_offset
				* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
			)
	return _phase3_equipment_get_conus_rope_origin()



func _update_conus_wall_climb(delta: float) -> void:
	if (
			not is_instance_valid(_conus_climb_tether)
			or not _conus_climb_tether.has_method(&"is_wall_tethered")
			or not bool(_conus_climb_tether.call(&"is_wall_tethered"))
		):
		end_conus_wall_climb()
		return
	if _conus_climb_tether.has_method(&"get_anchor_position"):
		var anchor_value: Variant = _conus_climb_tether.call(&"get_anchor_position")
		if anchor_value is Vector2:
			_conus_climb_anchor = anchor_value

	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()

	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		end_conus_wall_climb(_conus_climb_tether)
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	var rope_distance: float = rope_vector.length()
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	if _conus_wait_for_direction_release:
		if input_direction.length_squared() <= conus_climb_input_deadzone * conus_climb_input_deadzone:
			_conus_wait_for_direction_release = false
		input_direction = Vector2.ZERO

	var climb_axis: float = input_direction.dot(rope_direction)
	if absf(climb_axis) < conus_climb_input_deadzone:
		climb_axis = 0.0
	if climb_axis > 0.0 and rope_distance <= conus_climb_minimum_distance:
		climb_axis = 0.0
	elif climb_axis < 0.0 and rope_distance >= _conus_climb_maximum_distance:
		climb_axis = 0.0

	velocity = rope_direction * climb_axis * conus_climb_speed
	if climb_axis != 0.0:
		move_and_slide()
		global_position = _clamp_to_world(global_position)

	var corrected_vector: Vector2 = _conus_climb_anchor - global_position
	var corrected_distance: float = corrected_vector.length()
	if corrected_distance > 0.0001:
		var corrected_direction: Vector2 = corrected_vector / corrected_distance
		if corrected_distance > _conus_climb_maximum_distance:
			global_position = _conus_climb_anchor - corrected_direction * _conus_climb_maximum_distance
		elif corrected_distance < conus_climb_minimum_distance:
			global_position = _conus_climb_anchor - corrected_direction * conus_climb_minimum_distance

	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_align_to_conus_rope()
	_update_conus_climb_animation(climb_axis)



func _align_to_conus_rope() -> void:
	if _conus_climb_active and not _conus_climb_started:
		return
	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	_set_visual_rotation(rope_direction.angle() + PI * 0.5)
	var normal_scale_x: float = maxf(absf(_conus_climb_normal_sprite_scale.x), 0.001)
	var greatfin_active: bool = (
		absf(_conus_climb_previous_visual_scale.x)
		> normal_scale_x * 1.15
	)
	if greatfin_active:
		_animated_sprite.position = _conus_climb_sprite_base_position
	else:
		var rope_perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
		_animated_sprite.position = (
			_conus_climb_sprite_base_position
			+ rope_perpendicular
			* normal_conus_climb_sprite_perpendicular_offset
			* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
		)



func _update_conus_climb_animation(climb_axis: float) -> void:
	if climb_axis == 0.0:
		_animated_sprite.speed_scale = 1.0
		_animated_sprite.pause()
		return

	if not _conus_climb_started:
		_conus_climb_started = true
		_facing_left = false
		_animated_sprite.scale = (
			_conus_climb_previous_visual_scale
			* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
		)
		_align_to_conus_rope()

	var desired_speed: float = 1.0 if climb_axis > 0.0 else -1.0
	if _animated_sprite.animation != CONUS_CLIMB_ANIMATION:
		_set_animation(CONUS_CLIMB_ANIMATION)
		_animated_sprite.frame = (
			0
			if desired_speed > 0.0
			else _animated_sprite.sprite_frames.get_frame_count(
				CONUS_CLIMB_ANIMATION
			) - 1
		)
		_animated_sprite.speed_scale = desired_speed
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)
		return

	if (
			not _animated_sprite.is_playing()
			or not is_equal_approx(_animated_sprite.speed_scale, desired_speed)
		):
		_animated_sprite.speed_scale = desired_speed
		if desired_speed < 0.0 and _animated_sprite.frame == 0:
			_animated_sprite.frame = (
				_animated_sprite.sprite_frames.get_frame_count(
					CONUS_CLIMB_ANIMATION
				) - 1
			)
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)



func clear_item_effect_state() -> void:
	_clear_terebridae_pose_state()
	_phase3_equipment_clear_item_effect_state()
	_conus_climb_started = false
	_conus_wait_for_direction_release = false



func _phase3_phase6_start_death_sequence() -> void:
	if is_death_sequence_active():
		return
	_clear_terebridae_pose_state()
	_conus_climb_started = false
	_conus_wait_for_direction_release = false

	# Greatfin and equipment visuals can replace SpriteFrames at runtime. Build the
	# death animations into a local copy of the currently active frame set.
	if is_instance_valid(_animated_sprite) and _animated_sprite.sprite_frames != null:
		var local_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
		_animated_sprite.sprite_frames = local_frames
		_configure_death_animations()

	var item_visuals: Node = get_node_or_null("ItemVisuals")
	if item_visuals != null and item_visuals.has_method(&"clear_item_visuals"):
		item_visuals.call(&"clear_item_visuals")

	_death_menu_notification_sent = false
	_death_menu_drift_elapsed = 0.0
	_phase3_input_start_death_sequence()



func cancel_death_sequence() -> void:
	_death_menu_notification_sent = false
	_death_menu_drift_elapsed = 0.0
	_phase3_input_cancel_death_sequence()



func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_death_menu_drift_elapsed = 0.0
	_set_animation(DEATH_DRIFT_ANIMATION)



func _update_death_sequence(delta: float) -> void:
	_phase3_input_update_death_sequence(delta)
	if not _death_drift_active or _death_menu_notification_sent:
		return
	_death_menu_drift_elapsed += maxf(delta, 0.0)
	if _death_menu_drift_elapsed < death_menu_drift_seconds:
		return
	_death_menu_notification_sent = true
	death_drift_started.emit()



func _phase3_phase6_get_debug_lines() -> Array[String]:
	var lines: Array[String] = _phase3_equipment_get_debug_lines()
	lines.append("death_menu_notified=%s" % str(_death_menu_notification_sent))
	lines.append("death_menu_drift_elapsed=%.2f" % _death_menu_drift_elapsed)
	lines.append("death_menu_drift_seconds=%.2f" % death_menu_drift_seconds)
	lines.append("terebridae_pose_active=%s" % str(_terebridae_pose_active))
	lines.append("terebridae_stream_remaining=%.2f" % _terebridae_stream_remaining)
	lines.append("conch_recoil_normal=%.1f" % normal_conch_recoil_speed)
	lines.append("conch_recoil_super=%.1f" % super_conch_recoil_speed)
	lines.append("conch_recoil_terebridae=%.1f" % terebridae_recoil_speed)
	lines.append("conus_climb_visual_scale=%.2f" % CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER)
	lines.append("conus_climb_started=%s" % str(_conus_climb_started))
	lines.append("conus_wait_for_direction_release=%s" % str(_conus_wait_for_direction_release))
	return lines





# =============================================================================
# Vent and seaweed movement
# =============================================================================

func _phase3_vent_ready() -> void:
	_phase3_equipment_ready()
	_super_jump_audio = AudioStreamPlayer.new()
	_super_jump_audio.name = "SuperJumpAudio"
	_super_jump_audio.stream = SUPER_JUMP_AUDIO
	_super_jump_audio.volume_db = super_jump_volume_db
	add_child(_super_jump_audio)



func set_seaweed_slow_source(
		source: Node,
		movement_multiplier: float = 0.5,
	) -> void:
	if not is_instance_valid(source):
		return
	_seaweed_slow_sources[source] = clampf(movement_multiplier, 0.05, 1.0)



func remove_seaweed_slow_source(source: Node) -> void:
	_seaweed_slow_sources.erase(source)



func is_seaweed_slowed() -> bool:
	return get_seaweed_movement_multiplier() < 0.999



func get_seaweed_movement_multiplier() -> float:
	_remove_invalid_seaweed_sources()
	if is_item_surge_active() or is_conus_wall_climbing():
		return 1.0

	var strongest_slow: float = 1.0
	for source: Node in _seaweed_slow_sources.keys():
		strongest_slow = minf(strongest_slow, _seaweed_slow_sources[source])
	return strongest_slow



func _apply_motion(motion_velocity: Vector2, idle: bool) -> void:
	var movement_multiplier: float = get_seaweed_movement_multiplier()
	_phase3_base_apply_motion(motion_velocity * movement_multiplier, idle)



func _remove_invalid_seaweed_sources() -> void:
	for source: Node in _seaweed_slow_sources.keys():
		if not is_instance_valid(source):
			_seaweed_slow_sources.erase(source)



func _begin_surface_jump() -> void:
	var jump_multiplier: float = _resolve_active_vent_jump_multiplier()
	var duration_multiplier: float = _resolve_active_vent_jump_duration_multiplier()

	_phase3_equipment_begin_surface_jump()
	if _jump_elapsed <= 0.0:
		return

	_active_vent_jump_multiplier = maxf(1.0, jump_multiplier)
	_active_jump_arc_height = jump_arc_height * _active_vent_jump_multiplier
	_active_jump_duration = jump_duration * maxf(1.0, duration_multiplier)
	_pressure_jump_active = _active_vent_jump_multiplier >= PRESSURE_JUMP_THRESHOLD

	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end = Vector2(
		_jump_start.x + facing_sign * jump_forward_distance * _active_vent_jump_multiplier,
		_swim_ceiling_y + 40.0,
	)

	if _pressure_jump_active:
		_animated_sprite.pause()
		if is_instance_valid(_super_jump_audio):
			_super_jump_audio.stop()
			_super_jump_audio.play()



func _update_surface_jump(delta: float) -> void:
	_jump_elapsed += delta
	var active_duration: float = maxf(
		0.01,
		_active_jump_duration if _active_jump_duration > 0.0 else jump_duration,
	)
	var active_arc_height: float = (
		_active_jump_arc_height if _active_jump_arc_height > 0.0 else jump_arc_height
	)
	var progress: float = clampf(_jump_elapsed / active_duration, 0.0, 1.0)
	var base_position: Vector2 = _jump_start.lerp(_jump_end, progress)
	global_position = Vector2(
		base_position.x,
		base_position.y - sin(progress * PI) * active_arc_height,
	)

	if _pressure_jump_active:
		_update_pressure_jump_frame(progress)

	if progress >= 0.80 and _jump_elapsed - delta < active_duration * 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
	if progress < 1.0:
		return

	_jump_elapsed = 0.0
	global_position = _clamp_to_world(_jump_end)
	_active_jump_arc_height = 0.0
	_active_jump_duration = 0.0
	_active_vent_jump_multiplier = 1.0
	_pressure_jump_active = false
	_animated_sprite.speed_scale = 1.0
	_set_animation(&"idle")



func _resolve_active_vent_jump_multiplier() -> float:
	var strongest_multiplier: float = 1.0
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			continue
		if not source.has_method(&"get_surface_jump_multiplier"):
			continue
		strongest_multiplier = maxf(
			strongest_multiplier,
			float(source.call(&"get_surface_jump_multiplier")),
		)
	return strongest_multiplier



func _resolve_active_vent_jump_duration_multiplier() -> float:
	var longest_multiplier: float = 1.0
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			continue
		if not source.has_method(&"get_surface_jump_duration_multiplier"):
			continue
		longest_multiplier = maxf(
			longest_multiplier,
			float(source.call(&"get_surface_jump_duration_multiplier")),
		)
	return longest_multiplier



func _update_pressure_jump_frame(progress: float) -> void:
	if _animated_sprite.animation != &"jump":
		_animated_sprite.animation = &"jump"
	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"jump")
	if frame_count <= 0:
		return

	var frame_index: int = 0
	if progress < 0.12:
		frame_index = 0
	elif progress < 0.26:
		frame_index = 1
	elif progress < 0.42:
		frame_index = 2
	elif progress < 0.68:
		frame_index = 3
	elif progress < 0.84:
		frame_index = 4
	else:
		frame_index = 5

	_animated_sprite.frame = mini(frame_index, frame_count - 1)
	_animated_sprite.pause()



func _phase3_vent_get_debug_lines() -> Array[String]:
	var lines: Array[String] = _phase3_phase6_get_debug_lines()
	lines.append("seaweed_sources=%d" % _seaweed_slow_sources.size())
	lines.append("seaweed_multiplier=%.2f" % get_seaweed_movement_multiplier())
	lines.append("seaweed_bypassed_by_surge=%s" % str(is_item_surge_active()))
	lines.append("seaweed_bypassed_by_conus=%s" % str(is_conus_wall_climbing()))
	return lines





# =============================================================================
# Leaf Sheep carry
# =============================================================================

func _ready() -> void:
	_phase3_vent_ready()
	_install_carry_animation(_animated_sprite.sprite_frames, NORMAL_CARRY_TEXTURES)
	_install_carry_animation(GREATFIN_FRAMES, GREATFIN_CARRY_TEXTURES)



func set_leaf_sheep_active(is_active: bool) -> void:
	if _leaf_sheep_active == is_active:
		return
	_leaf_sheep_active = is_active
	if _leaf_sheep_active:
		_cancel_blocked_leaf_sheep_actions()
		if _conch_remaining <= 0.0:
			_set_animation(CARRY_ANIMATION)
	elif _animated_sprite.animation == CARRY_ANIMATION:
		_set_animation(&"idle")



func is_leaf_sheep_active() -> bool:
	return _leaf_sheep_active



func can_activate_leaf_sheep() -> bool:
	return (
		_play_enabled
		and not _death_sequence_active
		and not crawl_active
		and not airborne_active
		and not _conus_climb_active
	)



func get_leaf_sheep_hand_world_position() -> Vector2:
	var local_offset: Vector2 = leaf_sheep_hand_offset + _get_leaf_sheep_frame_offset()
	if _animated_sprite.flip_h:
		local_offset.x = -local_offset.x
	return to_global(_animated_sprite.position + local_offset.rotated(_animated_sprite.rotation))



func get_leaf_sheep_visual_rotation() -> float:
	return _animated_sprite.rotation



func is_leaf_sheep_facing_left() -> bool:
	return _animated_sprite.flip_h



func is_leaf_sheep_carry_animation_active() -> bool:
	return _leaf_sheep_active and _animated_sprite.animation == CARRY_ANIMATION



func is_leaf_sheep_greatfin_carry_active() -> bool:
	return is_leaf_sheep_carry_animation_active() and _item_visuals != null and bool(
		_item_visuals.get("_greatfin_active")
	)



func activate_item_surge(duration_seconds: float = 0.90) -> bool:
	if _leaf_sheep_active:
		return false
	return _phase3_phase6_activate_item_surge(duration_seconds)



func begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if _leaf_sheep_active:
		return
	_phase3_phase6_begin_conus_wall_climb(anchor_position, tether)



func begin_crawl() -> void:
	if _leaf_sheep_active:
		leaf_sheep_forced_deactivation_requested.emit(&"land")
	_phase3_land_begin_crawl()



func start_death_sequence() -> void:
	if _leaf_sheep_active:
		leaf_sheep_forced_deactivation_requested.emit(&"death")
	_phase3_phase6_start_death_sequence()



func _can_start_burst(input_direction: Vector2) -> bool:
	if _leaf_sheep_active:
		return false
	return _phase3_base_can_start_burst(input_direction)



func _start_burst(input_direction: Vector2) -> void:
	if _leaf_sheep_active:
		return
	_phase3_base_start_burst(input_direction)



func _start_tail_flip() -> void:
	if _leaf_sheep_active:
		return
	_phase3_presentation_start_tail_flip()



func _set_animation(animation_name: StringName) -> void:
	var resolved_animation: StringName = animation_name
	if _leaf_sheep_active and animation_name in [
		&"idle",
		&"swim",
		&"stop",
		&"stop_release",
	]:
		resolved_animation = CARRY_ANIMATION
	_phase3_presentation_set_animation(resolved_animation)



func _cancel_blocked_leaf_sheep_actions() -> void:
	_burst_active = false
	_burst_remaining = 0.0
	_pending_surface_jump = false
	_tail_flip_remaining = 0.0
	_stop_burst_audio()
	if _conus_climb_active:
		end_conus_wall_climb()



func _install_carry_animation(
		sprite_frames: SpriteFrames,
		textures: Array[Texture2D],
	) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(CARRY_ANIMATION):
		sprite_frames.clear(CARRY_ANIMATION)
	else:
		sprite_frames.add_animation(CARRY_ANIMATION)
	for texture: Texture2D in textures:
		sprite_frames.add_frame(CARRY_ANIMATION, texture)
	sprite_frames.set_animation_speed(CARRY_ANIMATION, leaf_sheep_carry_fps)
	sprite_frames.set_animation_loop(CARRY_ANIMATION, true)



func _get_leaf_sheep_frame_offset() -> Vector2:
	var offsets: Array[Vector2] = leaf_sheep_carry_frame_offsets
	if _animated_sprite.animation == &"conch":
		offsets = leaf_sheep_conch_frame_offsets
	if offsets.is_empty():
		return Vector2.ZERO
	return offsets[clampi(_animated_sprite.frame, 0, offsets.size() - 1)]



func get_debug_lines() -> Array[String]:
	var lines: Array[String] = _phase3_vent_get_debug_lines()
	lines.append("leaf_sheep_hylas_active=%s" % str(_leaf_sheep_active))
	lines.append("leaf_sheep_carry_animation=%s" % str(_animated_sprite.animation == CARRY_ANIMATION))
	lines.append("leaf_sheep_hand_position=%s" % str(get_leaf_sheep_hand_world_position()))
	return lines
