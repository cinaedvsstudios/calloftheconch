class_name CotcPassiveTideAnemone
extends Area2D

## A reusable passive sea creature with a visible slow pulse, occasional bubbles,
## and a soft outward water drift for Hylas.

@export_category("Pulse")
@export_range(0.10, 2.00, 0.01) var pulse_min_scale: float = 0.90
@export_range(0.10, 2.00, 0.01) var pulse_max_scale: float = 1.12
@export_range(0.10, 20.00, 0.05) var pulse_duration_min: float = 1.80
@export_range(0.10, 20.00, 0.05) var pulse_duration_max: float = 3.00
@export_range(0.00, 20.00, 0.05) var pulse_rest_duration_min: float = 0.20
@export_range(0.00, 20.00, 0.05) var pulse_rest_duration_max: float = 0.80

@export_category("Bubble Burst")
@export_range(0.10, 60.00, 0.05) var bubble_delay_min: float = 2.75
@export_range(0.10, 60.00, 0.05) var bubble_delay_max: float = 6.00

@export_category("Outward Drift")
@export_range(1.00, 1000.00, 1.00) var drift_radius: float = 200.00
@export_range(0.00, 500.00, 1.00) var drift_max_speed: float = 45.00

@onready var _visual_root: Node2D = %VisualRoot
@onready var _bubble_burst: CotcBubbleBurst = %BubbleBurst
@onready var _drift_collision: CollisionShape2D = %DriftCollision

var _hylas: CotcHylas
var _pulse_tween: Tween
var _pulse_timer: float = 0.0
var _bubble_timer: float = 0.0
var _centre_fallback_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_configure_drift_collision()
	_centre_fallback_direction = Vector2.from_angle(randf_range(0.0, TAU))
	_pulse_timer = randf_range(0.15, 0.60)
	_bubble_timer = randf_range(1.00, 2.50)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _exit_tree() -> void:
	_remove_drift_from_hylas()


func _process(delta: float) -> void:
	_pulse_timer = maxf(0.0, _pulse_timer - delta)
	if _pulse_timer <= 0.0:
		_start_pulse()

	_bubble_timer = maxf(0.0, _bubble_timer - delta)
	if _bubble_timer <= 0.0:
		_bubble_burst.trigger()
		_bubble_timer = randf_range(bubble_delay_min, bubble_delay_max)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_hylas) or not overlaps_body(_hylas):
		_remove_drift_from_hylas()
		_hylas = null
		set_physics_process(false)
		return
	_hylas.set_external_current(self, _get_outward_drift_velocity())


func _start_pulse() -> void:
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_visual_root.scale = Vector2.ONE * pulse_min_scale
	var pulse_duration: float = randf_range(pulse_duration_min, pulse_duration_max)
	_pulse_tween = create_tween()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_visual_root, "scale", Vector2.ONE * pulse_max_scale, pulse_duration * 0.5)
	_pulse_tween.tween_property(_visual_root, "scale", Vector2.ONE, pulse_duration * 0.5)
	_pulse_timer = pulse_duration + randf_range(pulse_rest_duration_min, pulse_rest_duration_max)


func _get_outward_drift_velocity() -> Vector2:
	var offset_from_centre: Vector2 = _hylas.global_position - global_position
	var distance_from_centre: float = offset_from_centre.length()
	var direction: Vector2 = _centre_fallback_direction
	if distance_from_centre > 0.01:
		direction = offset_from_centre / distance_from_centre
	var strength_ratio: float = clampf(1.0 - distance_from_centre / drift_radius, 0.0, 1.0)
	return direction * drift_max_speed * strength_ratio * strength_ratio


func _configure_drift_collision() -> void:
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = drift_radius
	_drift_collision.shape = circle_shape


func _on_body_entered(body: Node2D) -> void:
	if body is CotcHylas:
		_hylas = body
		set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	if body == _hylas:
		_remove_drift_from_hylas()
		_hylas = null
		set_physics_process(false)


func _remove_drift_from_hylas() -> void:
	if is_instance_valid(_hylas):
		_hylas.remove_external_current(self)
