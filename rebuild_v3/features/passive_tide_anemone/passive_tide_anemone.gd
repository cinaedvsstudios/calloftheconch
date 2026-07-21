class_name CotcPassiveTideAnemone
extends Area2D

## A reusable passive sea creature with a continuous pulse, occasional full
## bubble-burst playback, and a soft outward water drift for Hylas.

@export_category("Pulse")
@export_range(0.10, 2.00, 0.01) var pulse_min_scale: float = 0.90
@export_range(0.10, 2.00, 0.01) var pulse_max_scale: float = 1.12
@export_range(0.10, 20.00, 0.05) var pulse_duration_min: float = 1.80
@export_range(0.10, 20.00, 0.05) var pulse_duration_max: float = 3.00

@export_category("Bubble Burst")
@export_range(0.10, 60.00, 0.05) var bubble_delay_min: float = 2.75
@export_range(0.10, 60.00, 0.05) var bubble_delay_max: float = 6.00

@export_category("Outward Drift")
@export_range(1.00, 1000.00, 1.00) var drift_radius: float = 350.00
@export_range(0.00, 500.00, 1.00) var drift_max_speed: float = 55.00

@onready var _visual_root: Node2D = %VisualRoot
@onready var _bubble_burst: CotcBubbleBurst = %BubbleBurst
@onready var _drift_collision: CollisionShape2D = %DriftCollision

var _hylas: CotcHylas
var _pulse_tween: Tween
var _pulse_growing: bool = true
var _visual_base_scale: Vector2 = Vector2.ONE
var _bubble_timer: float = 0.0
var _centre_fallback_direction: Vector2 = Vector2.RIGHT
var _distance_active: bool = true


func _ready() -> void:
	_configure_drift_collision()
	_centre_fallback_direction = Vector2.from_angle(randf_range(0.0, TAU))
	_visual_base_scale = _visual_root.scale
	var initial_pulse_multiplier: float = randf_range(pulse_min_scale, pulse_max_scale)
	_visual_root.scale = _visual_base_scale * initial_pulse_multiplier
	_pulse_growing = initial_pulse_multiplier < (pulse_min_scale + pulse_max_scale) * 0.5
	_bubble_timer = randf_range(1.00, 2.50)
	monitoring = true
	set_process(true)
	set_physics_process(true)
	_start_pulse()


func _exit_tree() -> void:
	_stop_pulse()
	_remove_drift_from_hylas()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_process(_distance_active)
	set_physics_process(_distance_active)
	monitoring = _distance_active
	if _distance_active:
		if _bubble_timer <= 0.0:
			_bubble_timer = randf_range(bubble_delay_min, bubble_delay_max)
		_start_pulse()
		return
	_stop_pulse()
	_bubble_burst.stop_burst()
	_remove_drift_from_hylas()
	_hylas = null


func _process(delta: float) -> void:
	_bubble_timer = maxf(0.0, _bubble_timer - delta)
	if _bubble_timer <= 0.0:
		_bubble_burst.display_duration = _get_full_bubble_duration()
		_bubble_burst.trigger()
		_bubble_timer = randf_range(bubble_delay_min, bubble_delay_max)


func _physics_process(_delta: float) -> void:
	var detected_hylas: CotcHylas = _find_hylas_in_drift_area()
	if detected_hylas != _hylas:
		_remove_drift_from_hylas()
		_hylas = detected_hylas
	if is_instance_valid(_hylas):
		_hylas.set_external_current(self, _get_outward_drift_velocity())


func _start_pulse() -> void:
	if not _distance_active:
		return
	_stop_pulse()
	var target_scale: float = pulse_max_scale if _pulse_growing else pulse_min_scale
	var pulse_duration: float = randf_range(pulse_duration_min, pulse_duration_max)
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(
		_visual_root,
		^"scale",
		_visual_base_scale * target_scale,
		pulse_duration,
	)
	_pulse_tween.tween_callback(_continue_pulse)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _continue_pulse() -> void:
	if not _distance_active:
		return
	_pulse_growing = not _pulse_growing
	_start_pulse()


func _get_full_bubble_duration() -> float:
	var bubble_video: VideoStreamPlayer = _bubble_burst.get_node_or_null("BubbleVideo") as VideoStreamPlayer
	if bubble_video == null:
		return 0.40
	return maxf(0.40, bubble_video.get_stream_length())


func _find_hylas_in_drift_area() -> CotcHylas:
	for body: Node2D in get_overlapping_bodies():
		if body is CotcHylas:
			return body as CotcHylas
	return null


func _get_outward_drift_velocity() -> Vector2:
	var offset_from_centre: Vector2 = _hylas.global_position - global_position
	var distance_from_centre: float = offset_from_centre.length()
	var direction: Vector2 = _centre_fallback_direction
	if distance_from_centre > 0.01:
		direction = offset_from_centre / distance_from_centre
	var strength_ratio: float = clampf(1.0 - distance_from_centre / drift_radius, 0.0, 1.0)
	return direction * drift_max_speed * strength_ratio


func _configure_drift_collision() -> void:
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = drift_radius
	_drift_collision.shape = circle_shape


func _remove_drift_from_hylas() -> void:
	if is_instance_valid(_hylas):
		_hylas.remove_external_current(self)
