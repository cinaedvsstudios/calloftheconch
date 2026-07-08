class_name CotcBoulder
extends RigidBody2D

@export_category("Tail Flip Response")
@export var tail_flip_reach: float = 250.0
@export var tail_flip_lateral_tolerance: float = 135.0
@export var kick_impulse_right: float = 1150.0

var _hylas: CotcHylas
var _has_been_hit: bool = false


func _ready() -> void:
	call_deferred("_connect_to_hylas")


func _connect_to_hylas() -> void:
	_hylas = get_tree().get_first_node_in_group(&"hylas") as CotcHylas
	if _hylas == null:
		return
	if not _hylas.tail_flip_started.is_connected(_on_hylas_tail_flip_started):
		_hylas.tail_flip_started.connect(_on_hylas_tail_flip_started)


func _on_hylas_tail_flip_started(origin: Vector2, direction: Vector2) -> void:
	if _has_been_hit:
		return
	var to_boulder: Vector2 = global_position - origin
	var forward_distance: float = to_boulder.dot(direction)
	var lateral_distance: float = absf(to_boulder.cross(direction))
	if forward_distance < 0.0 or forward_distance > tail_flip_reach:
		return
	if lateral_distance > tail_flip_lateral_tolerance:
		return
	_begin_tail_flip_response()


func _begin_tail_flip_response() -> void:
	_has_been_hit = true
	freeze = false
	if _hylas != null and _hylas.has_method(&"play_land_impact_sound"):
		_hylas.call(&"play_land_impact_sound")
	apply_central_impulse(Vector2(kick_impulse_right, 0.0))
