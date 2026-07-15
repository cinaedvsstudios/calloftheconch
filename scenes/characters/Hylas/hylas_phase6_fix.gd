extends "res://scenes/characters/Hylas/hylas_equipment_input.gd"

signal surge_ram_started(origin: Vector2, direction: Vector2, duration: float)

var _death_landing_notification_sent: bool = false


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

	# Greatfin and the return to normal form replace the SpriteFrames resource at
	# runtime. Build death_intro and death_drift into a local copy of whichever
	# frame set Hylas currently owns so the death animation cannot disappear after
	# a transformation or equipment visual change.
	if is_instance_valid(_animated_sprite) and _animated_sprite.sprite_frames != null:
		var local_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
		_animated_sprite.sprite_frames = local_frames
		_configure_death_animations()

	var item_visuals: Node = get_node_or_null("ItemVisuals")
	if item_visuals != null and item_visuals.has_method(&"clear_item_visuals"):
		item_visuals.call(&"clear_item_visuals")

	_death_landing_notification_sent = false
	super.start_death_sequence()


func cancel_death_sequence() -> void:
	_death_landing_notification_sent = false
	super.cancel_death_sequence()


func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_set_animation(DEATH_DRIFT_ANIMATION)


func _update_death_sequence(delta: float) -> void:
	var was_landed: bool = _death_body_landed
	super._update_death_sequence(delta)
	if was_landed or not _death_body_landed or _death_landing_notification_sent:
		return
	_death_landing_notification_sent = true

	# SeaOfPillars currently consumes this compatibility signal to open the death
	# overlay. Emit it only after death_landed, not when frames 7–8 begin drifting.
	death_drift_started.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("death_menu_landing_notified=%s" % str(_death_landing_notification_sent))
	return lines
