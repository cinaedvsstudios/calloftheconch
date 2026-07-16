extends "res://scenes/characters/Hylas/hylas_equipment_input.gd"

signal surge_ram_started(origin: Vector2, direction: Vector2, duration: float)

@export_category("Death Menu Timing")
@export_range(0.5, 10.0, 0.1) var death_menu_drift_seconds: float = 3.0

var _death_menu_notification_sent: bool = false
var _death_menu_drift_elapsed: float = 0.0


func activate_item_surge(duration_seconds: float = 30.0) -> bool:
	var activated: bool = super.activate_item_surge(duration_seconds)
	if not activated:
		return false
	var direction: Vector2 = _burst_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	surge_ram_started.emit(global_position, direction.normalized(), duration_seconds)
	return true


func start_death_sequence() -> void:
	if is_death_sequence_active():
		return

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
	super.start_death_sequence()


func cancel_death_sequence() -> void:
	_death_menu_notification_sent = false
	_death_menu_drift_elapsed = 0.0
	super.cancel_death_sequence()


func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_death_menu_drift_elapsed = 0.0
	_set_animation(DEATH_DRIFT_ANIMATION)


func _update_death_sequence(delta: float) -> void:
	super._update_death_sequence(delta)
	if not _death_drift_active or _death_menu_notification_sent:
		return
	_death_menu_drift_elapsed += maxf(delta, 0.0)
	if _death_menu_drift_elapsed < death_menu_drift_seconds:
		return
	_death_menu_notification_sent = true
	death_drift_started.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("death_menu_notified=%s" % str(_death_menu_notification_sent))
	lines.append("death_menu_drift_elapsed=%.2f" % _death_menu_drift_elapsed)
	lines.append("death_menu_drift_seconds=%.2f" % death_menu_drift_seconds)
	return lines
