class_name CotcDepthJellyfish
extends CotcDepthStunnableEnemy

## Dark-depth jellyfish: gentle two-frame drift, periodic upward propulsion and bubbles.

enum MotionState {
	DRIFT,
	BOOST,
	RECOVER,
}

@export_category("Display")
@export_range(40.0, 500.0, 1.0) var display_height: float = 150.0
@export_range(0.0, 0.2, 0.005) var pulse_scale_amount: float = 0.05
@export_range(0.05, 2.0, 0.05) var pulse_cycles_per_second: float = 0.28
@export_range(0.0, 80.0, 1.0) var visual_bob_distance: float = 7.0

@export_category("Drift")
@export_range(0.0, 300.0, 1.0) var patrol_half_width: float = 280.0
@export_range(1.0, 200.0, 1.0) var drift_speed: float = 22.0
@export_range(0.0, 1.0, 0.01) var current_influence: float = 0.22

@export_category("Upward Boost")
@export_range(0.2, 30.0, 0.1) var boost_interval_min: float = 3.2
@export_range(0.2, 30.0, 0.1) var boost_interval_max: float = 6.0
@export_range(10.0, 900.0, 5.0) var boost_speed: float = 310.0
@export_range(10.0, 1800.0, 5.0) var boost_deceleration: float = 650.0
@export_range(5.0, 300.0, 1.0) var return_speed: float = 42.0
@export var random_seed: int = 0

@export_category("Bioluminescence")
@export_range(0.0, 8.0, 0.05) var idle_light_energy: float = 1.15
@export_range(0.0, 12.0, 0.05) var boost_light_energy: float = 2.0

@onready var _bubble_burst: GPUParticles2D = %BubbleBurst
@onready var _glow_halo: Sprite2D = %GlowHalo
@onready var _light: PointLight2D = %Bioluminescence

var _home_position: Vector2
var _boost_origin_y: float = 0.0
var _boost_wait: float = 0.0
var _vertical_velocity: float = 0.0
var _drift_direction: float = 1.0
var _elapsed: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _motion_state: MotionState = MotionState.DRIFT
var _external_currents: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_home_position = global_position
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_drift_direction = -1.0 if _rng.randf() < 0.5 else 1.0
	_apply_display_scale()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"idle")
	_schedule_next_boost()
	_light.energy = idle_light_energy


func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_update_visual_pulse()
	if _consume_stun_frame(delta):
		return

	_update_horizontal_drift(delta)
	match _motion_state:
		MotionState.DRIFT:
			_update_drift_state(delta)
		MotionState.BOOST:
			_update_boost_state(delta)
		MotionState.RECOVER:
			_update_recover_state(delta)
	_damage_touching_hylas_if_needed()


func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if is_instance_valid(source):
		_external_currents[source] = current_velocity


func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)


func _update_drift_state(delta: float) -> void:
	_boost_wait -= delta
	if _boost_wait <= 0.0:
		_start_boost()


func _start_boost() -> void:
	if _motion_state != MotionState.DRIFT or is_frozen():
		return
	_motion_state = MotionState.BOOST
	_boost_origin_y = global_position.y
	_vertical_velocity = -boost_speed
	_sprite.play(&"boost")
	_bubble_burst.emitting = true
	_bubble_burst.restart()
	_light.energy = boost_light_energy


func _update_boost_state(delta: float) -> void:
	global_position.y += _vertical_velocity * delta
	_vertical_velocity = move_toward(
		_vertical_velocity,
		0.0,
		boost_deceleration * delta,
	)


func _begin_recovery() -> void:
	if _motion_state != MotionState.BOOST:
		return
	_motion_state = MotionState.RECOVER
	_vertical_velocity = 0.0
	_sprite.play(&"idle")


func _update_recover_state(delta: float) -> void:
	global_position.y = move_toward(global_position.y, _boost_origin_y, return_speed * delta)
	_light.energy = move_toward(_light.energy, idle_light_energy, 1.4 * delta)
	if is_equal_approx(global_position.y, _boost_origin_y):
		_motion_state = MotionState.DRIFT
		_schedule_next_boost()


func _update_horizontal_drift(delta: float) -> void:
	global_position.x += _drift_direction * drift_speed * delta
	var left_limit: float = _home_position.x - patrol_half_width
	var right_limit: float = _home_position.x + patrol_half_width
	if global_position.x <= left_limit:
		global_position.x = left_limit
		_drift_direction = 1.0
	elif global_position.x >= right_limit:
		global_position.x = right_limit
		_drift_direction = -1.0
	global_position += _get_external_current_velocity() * current_influence * delta


func _update_visual_pulse() -> void:
	var wave: float = sin(_elapsed * TAU * pulse_cycles_per_second)
	var pulse_factor: float = 1.0 + wave * pulse_scale_amount
	_sprite.scale = _base_sprite_scale * pulse_factor
	_sprite.position.y = sin(_elapsed * TAU * pulse_cycles_per_second * 0.72) * visual_bob_distance
	_glow_halo.scale = Vector2.ONE * (1.0 + wave * 0.08)
	_glow_halo.modulate.a = 0.42 + wave * 0.08
	if _motion_state == MotionState.DRIFT and not is_frozen():
		_light.energy = idle_light_energy * (1.0 + wave * 0.08)


func _schedule_next_boost() -> void:
	_boost_wait = _rng.randf_range(
		minf(boost_interval_min, boost_interval_max),
		maxf(boost_interval_min, boost_interval_max),
	)


func _on_animation_finished() -> void:
	if _sprite.animation == &"boost":
		_begin_recovery()


func _on_conch_hit_impulse(origin: Vector2, pulse_direction: Vector2, strength: float) -> void:
	var away: Vector2 = global_position - origin
	if away.length_squared() <= 0.001:
		away = pulse_direction
	if away.length_squared() > 0.001:
		global_position += away.normalized() * clampf(strength, 0.55, 1.35) * 18.0


func _on_stun_started() -> void:
	_bubble_burst.emitting = false
	_motion_state = MotionState.DRIFT
	_vertical_velocity = 0.0
	_light.energy = idle_light_energy * 0.45


func _on_stunned_physics(_delta: float) -> void:
	_light.energy = idle_light_energy * 0.45


func _on_stun_finished() -> void:
	_sprite.play(&"idle")
	_motion_state = MotionState.DRIFT
	_light.energy = idle_light_energy
	_schedule_next_boost()


func _on_distance_sleep() -> void:
	_bubble_burst.emitting = false


func _on_distance_wake() -> void:
	if not is_frozen():
		_sprite.play(&"idle")
		_schedule_next_boost()


func _get_external_current_velocity() -> Vector2:
	var total := Vector2.ZERO
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			_external_currents.erase(source)
			continue
		var source_velocity: Vector2 = _external_currents[source]
		total += source_velocity
	return total


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_base_sprite_scale = Vector2.ONE * scale_factor
	_sprite.scale = _base_sprite_scale
	_bubble_burst.position.y = display_height * 0.28
