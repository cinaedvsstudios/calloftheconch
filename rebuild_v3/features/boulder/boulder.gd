class_name CotcBoulder
extends AnimatableBody2D

@export_category("Tail Flip Response")
@export var tail_flip_hit_window: float = 0.55
@export var push_right_distance: float = 250.0
@export var push_duration: float = 0.25

@export_category("Sinking")
@export var sink_speed: float = 55.0
@export var sink_distance: float = 700.0

@onready var _tail_flip_hitbox: Area2D = %TailFlipHitbox

var _hylas: CotcHylas
var _tail_flip_active_until: float = 0.0
var _has_been_hit: bool = false
var _is_sinking: bool = false
var _remaining_sink_distance: float = 0.0


func _ready() -> void:
	call_deferred("_connect_to_hylas")


func _physics_process(delta: float) -> void:
	if _is_sinking:
		_update_sinking(delta)
		return
	if not _has_been_hit:
		_try_tail_flip_hit()


func _connect_to_hylas() -> void:
	_hylas = get_tree().get_first_node_in_group(&"hylas") as CotcHylas
	if _hylas == null:
		return
	if not _hylas.tail_flip_started.is_connected(_on_hylas_tail_flip_started):
		_hylas.tail_flip_started.connect(_on_hylas_tail_flip_started)


func _on_hylas_tail_flip_started(_origin: Vector2, _direction: Vector2) -> void:
	_tail_flip_active_until = Time.get_ticks_msec() / 1000.0 + tail_flip_hit_window
	_try_tail_flip_hit()


func _try_tail_flip_hit() -> void:
	if _has_been_hit or _hylas == null:
		return
	if Time.get_ticks_msec() / 1000.0 > _tail_flip_active_until:
		return
	for body: Node2D in _tail_flip_hitbox.get_overlapping_bodies():
		if body == _hylas:
			_begin_tail_flip_response()
			return


func _begin_tail_flip_response() -> void:
	_has_been_hit = true
	if _hylas.has_method(&"play_land_impact_sound"):
		_hylas.call(&"play_land_impact_sound")
	var push_tween: Tween = create_tween()
	push_tween.set_trans(Tween.TRANS_QUAD)
	push_tween.set_ease(Tween.EASE_OUT)
	push_tween.tween_property(self, "position", position + Vector2(push_right_distance, 0.0), push_duration)
	push_tween.tween_callback(_begin_sinking)


func _begin_sinking() -> void:
	_is_sinking = true
	_remaining_sink_distance = sink_distance


func _update_sinking(delta: float) -> void:
	var movement: float = minf(sink_speed * delta, _remaining_sink_distance)
	position.y += movement
	_remaining_sink_distance -= movement
	if _remaining_sink_distance <= 0.0:
		_is_sinking = false
