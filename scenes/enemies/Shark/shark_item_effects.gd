extends "res://scenes/enemies/Shark/shark_enemy.gd"

## Keeps ordinary shark behaviour unchanged while adding the shared Phase 6
## equipment hooks. Haliotis hides Hylas from pursuit, Argonauta refreshes a
## short paralysis while the shark remains inside the ink cloud, and the shared
## Conch pulse applies a restrained movement response through the shark's own
## frozen movement update.

@export_range(0.1, 20.0, 0.1) var conus_dart_stun_seconds: float = 3.5
@export_range(0.0, 500.0, 1.0) var conch_response_speed: float = 165.0
@export_range(1.0, 1600.0, 1.0) var conch_response_decay: float = 260.0

var _conch_response_velocity: Vector2 = Vector2.ZERO


func receive_conch_hit(
		origin: Vector2,
		pulse_direction: Vector2,
		distance: float,
		strength: float,
	) -> void:
	super.receive_conch_hit(origin, pulse_direction, distance, strength)
	_add_conch_response_velocity(origin, pulse_direction, strength)


func _update_frozen(delta: float) -> void:
	super._update_frozen(delta)
	_update_conch_response(delta)
	global_position += _conch_response_velocity * delta


func _finish_frozen_state() -> void:
	_conch_response_velocity = Vector2.ZERO
	super._finish_frozen_state()


func _add_conch_response_velocity(origin: Vector2, pulse_direction: Vector2, strength: float) -> void:
	var away_direction: Vector2 = global_position - origin
	if away_direction.length_squared() <= 0.001:
		away_direction = pulse_direction
	if away_direction.length_squared() <= 0.001:
		return
	var applied_strength: float = clampf(strength, 0.55, 1.35)
	_conch_response_velocity += away_direction.normalized() * conch_response_speed * applied_strength


func _update_conch_response(delta: float) -> void:
	_conch_response_velocity = _conch_response_velocity.move_toward(
		Vector2.ZERO,
		conch_response_decay * delta,
	)


func apply_item_paralysis(duration_seconds: float) -> void:
	var requested_msec: int = maxi(1, roundi(maxf(0.05, duration_seconds) * 1000.0))
	var was_already_frozen: bool = is_frozen()
	_freeze_ends_at_msec = maxi(
		_freeze_ends_at_msec,
		Time.get_ticks_msec() + requested_msec,
	)
	if not was_already_frozen or not _frozen_visual_active:
		_begin_frozen_state()
	else:
		_sprite.play(&"frozen")
		_set_stun_glow_enabled(true)


func receive_conus_dart(_source: Node2D) -> void:
	apply_item_paralysis(conus_dart_stun_seconds)


func _is_hylas_in_detection_range() -> bool:
	if (
			is_instance_valid(_hylas)
			and _hylas.has_method(&"is_camouflage_active")
			and bool(_hylas.call(&"is_camouflage_active"))
		):
		return false
	return super._is_hylas_in_detection_range()