extends "res://scenes/enemies/Shark/shark_enemy.gd"

## Keeps ordinary shark behaviour unchanged while adding the shared Phase 6
## equipment hooks. Haliotis hides Hylas from pursuit, and Argonauta refreshes a
## short paralysis while the shark remains inside the ink cloud.

@export_range(0.1, 20.0, 0.1) var conus_dart_stun_seconds: float = 3.5


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
