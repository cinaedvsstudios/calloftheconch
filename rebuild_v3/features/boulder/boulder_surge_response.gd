extends "res://rebuild_v3/features/boulder/boulder.gd"

@export_range(1.0, 3.0, 0.05) var surge_kick_multiplier: float = 1.35

func _connect_to_hylas() -> void:
	super._connect_to_hylas()
	if _hylas == null or not _hylas.has_signal(&"surge_ram_started"):
		return
	var callback: Callable = Callable(self, "_on_hylas_surge_ram_started")
	if not _hylas.is_connected(&"surge_ram_started", callback):
		_hylas.connect(&"surge_ram_started", callback)

func _on_hylas_surge_ram_started(_origin: Vector2, direction: Vector2, duration: float) -> void:
	if direction.length_squared() <= 0.01:
		return
	_active_tail_flip_direction = direction.normalized()
	_tail_flip_active_until = Time.get_ticks_msec() / 1000.0 + maxf(0.3, duration)
	_try_tail_flip_hit()

func _apply_tail_flip_hit() -> void:
	var original_kick_speed: float = kick_speed
	kick_speed *= surge_kick_multiplier if Time.get_ticks_msec() / 1000.0 <= _tail_flip_active_until else 1.0
	super._apply_tail_flip_hit()
	kick_speed = original_kick_speed
