class_name CotcVacuumVentPair
extends Node2D

## Locally owns one intake-to-output route. The intake requests capture upward;
## this pair validates the request, animates Hylas through the route, snaps the
## camera locally, and returns control inside the linked strong output stream.

signal transport_started(hylas: Node2D)
signal transport_completed(hylas: Node2D)

const TRANSPORT_LOCK_META: StringName = &"vacuum_transport_locked_until_msec"

@export_category("Capture Transition")
@export_range(0.15, 2.0, 0.05) var capture_duration: float = 0.55
@export_range(0.02, 0.80, 0.01) var captured_scale_multiplier: float = 0.18
@export_range(0.0, 1.0, 0.01) var captured_brightness: float = 0.20
@export_range(0.0, 1.0, 0.01) var captured_alpha: float = 0.12
@export_range(-3.0, 3.0, 0.05) var capture_spin_turns: float = 0.70

@export_category("Output Transition")
@export_range(0.15, 2.0, 0.05) var emergence_duration: float = 0.42
@export_range(0.10, 4.0, 0.05) var recapture_lock_seconds: float = 1.00

@onready var _intake: CotcVacuumVentIntake = %Intake
@onready var _output: CotcVacuumVentOutput = %Output

var _transport_active: bool = false
var _hylas: Node2D
var _hylas_sprite: AnimatedSprite2D
var _hylas_shadow: CanvasItem
var _hylas_item_visuals: CanvasItem
var _hylas_collision: CollisionShape2D
var _hylas_camera: Camera2D
var _hylas_start_position: Vector2 = Vector2.ZERO
var _sprite_original_scale: Vector2 = Vector2.ONE
var _sprite_original_modulate: Color = Color.WHITE
var _sprite_original_rotation: float = 0.0
var _sprite_original_flip_h: bool = false
var _sprite_was_visible: bool = true
var _shadow_was_visible: bool = true
var _item_visuals_were_visible: bool = true
var _collision_was_disabled: bool = false


func _ready() -> void:
	if not _intake.capture_requested.is_connected(_on_intake_capture_requested):
		_intake.capture_requested.connect(_on_intake_capture_requested)


func _exit_tree() -> void:
	if _transport_active and is_instance_valid(_hylas):
		_restore_hylas_after_failure()


func _on_intake_capture_requested(hylas: Node2D) -> void:
	if _transport_active or not is_instance_valid(hylas):
		_intake.cancel_capture(hylas)
		return
	_transport_active = true
	_hylas = hylas
	call_deferred(&"_run_transport", hylas)


func _run_transport(hylas: Node2D) -> void:
	if not is_instance_valid(hylas) or not is_instance_valid(_output):
		_cancel_transport_before_animation(hylas)
		return
	if not _capture_hylas_presentation_state(hylas):
		_cancel_transport_before_animation(hylas)
		return

	transport_started.emit(hylas)
	_intake.release_receiver(hylas)
	_lock_hylas_from_vacuum_capture(
		hylas,
		capture_duration + emergence_duration + recapture_lock_seconds,
	)

	if hylas.has_method(&"cancel_pending_interaction"):
		hylas.call(&"cancel_pending_interaction")
	if hylas.has_method(&"set_interaction_available"):
		hylas.call(&"set_interaction_available", false)
	if hylas.has_method(&"set_play_enabled"):
		hylas.call(&"set_play_enabled", false)

	_hylas_sprite.show()
	_hylas_sprite.pause()
	if is_instance_valid(_hylas_shadow):
		_hylas_shadow.hide()
	if is_instance_valid(_hylas_item_visuals):
		_hylas_item_visuals.hide()
	if is_instance_valid(_hylas_collision):
		_hylas_collision.set_deferred(&"disabled", true)

	var dark_colour: Color = Color(
		captured_brightness,
		captured_brightness,
		captured_brightness,
		captured_alpha,
	)
	var capture_tween: Tween = create_tween()
	capture_tween.set_parallel(true)
	capture_tween.set_trans(Tween.TRANS_SINE)
	capture_tween.set_ease(Tween.EASE_IN)
	capture_tween.tween_property(
		hylas,
		^"global_position",
		_intake.get_capture_mouth_global_position(),
		capture_duration,
	)
	capture_tween.tween_property(
		_hylas_sprite,
		^"scale",
		_sprite_original_scale * captured_scale_multiplier,
		capture_duration,
	)
	capture_tween.tween_property(
		_hylas_sprite,
		^"modulate",
		dark_colour,
		capture_duration,
	)
	capture_tween.tween_property(
		_hylas_sprite,
		^"rotation",
		_sprite_original_rotation + TAU * capture_spin_turns,
		capture_duration,
	)
	await capture_tween.finished

	if not is_instance_valid(hylas) or not is_instance_valid(_output):
		_restore_hylas_after_failure()
		return

	await _snap_hylas_to_output(hylas, dark_colour)
	if not is_instance_valid(hylas):
		_clear_transport_state()
		return

	_restore_hylas_after_success()
	_lock_hylas_from_vacuum_capture(hylas, recapture_lock_seconds)
	_intake.complete_capture(hylas)
	transport_completed.emit(hylas)
	_clear_transport_state()


func _capture_hylas_presentation_state(hylas: Node2D) -> bool:
	_hylas_sprite = hylas.get_node_or_null(^"%AnimatedSprite") as AnimatedSprite2D
	_hylas_shadow = hylas.get_node_or_null(^"%ShadowSprite") as CanvasItem
	_hylas_item_visuals = hylas.get_node_or_null(^"%ItemVisuals") as CanvasItem
	_hylas_collision = hylas.get_node_or_null(^"%CollisionShape") as CollisionShape2D
	_hylas_camera = hylas.get_node_or_null(^"%Camera2D") as Camera2D
	if _hylas_sprite == null:
		push_error("Vacuum vent transport requires Hylas to have an AnimatedSprite node.")
		return false

	_hylas_start_position = hylas.global_position
	_sprite_original_scale = _hylas_sprite.scale
	_sprite_original_modulate = _hylas_sprite.modulate
	_sprite_original_rotation = _hylas_sprite.rotation
	_sprite_original_flip_h = _hylas_sprite.flip_h
	_sprite_was_visible = _hylas_sprite.visible
	_shadow_was_visible = _hylas_shadow.visible if _hylas_shadow != null else false
	_item_visuals_were_visible = (
		_hylas_item_visuals.visible if _hylas_item_visuals != null else false
	)
	_collision_was_disabled = (
		_hylas_collision.disabled if _hylas_collision != null else false
	)
	return true


func _snap_hylas_to_output(hylas: Node2D, dark_colour: Color) -> void:
	var launch_direction: Vector2 = _output.get_launch_direction()
	var camera_smoothing_was_enabled: bool = false
	if is_instance_valid(_hylas_camera):
		camera_smoothing_was_enabled = _hylas_camera.position_smoothing_enabled
		_hylas_camera.position_smoothing_enabled = false

	hylas.global_position = _output.get_exit_global_position()
	_hylas_sprite.scale = _sprite_original_scale * captured_scale_multiplier
	_hylas_sprite.modulate = dark_colour
	_hylas_sprite.rotation = launch_direction.angle()
	if absf(launch_direction.x) > 0.05:
		_hylas_sprite.flip_h = launch_direction.x < 0.0

	if is_instance_valid(_hylas_camera):
		_hylas_camera.reset_smoothing()
	await get_tree().process_frame
	if is_instance_valid(_hylas_camera):
		_hylas_camera.reset_smoothing()
		_hylas_camera.position_smoothing_enabled = camera_smoothing_was_enabled

	var emergence_tween: Tween = create_tween()
	emergence_tween.set_parallel(true)
	emergence_tween.set_trans(Tween.TRANS_SINE)
	emergence_tween.set_ease(Tween.EASE_OUT)
	emergence_tween.tween_property(
		hylas,
		^"global_position",
		_output.get_emergence_target_global_position(emergence_duration),
		emergence_duration,
	)
	emergence_tween.tween_property(
		_hylas_sprite,
		^"scale",
		_sprite_original_scale,
		emergence_duration,
	)
	emergence_tween.tween_property(
		_hylas_sprite,
		^"modulate",
		_sprite_original_modulate,
		emergence_duration,
	)
	await emergence_tween.finished


func _restore_hylas_after_success() -> void:
	if not is_instance_valid(_hylas):
		return
	_restore_hylas_presentation()
	if _hylas.has_method(&"set_play_enabled"):
		_hylas.call(&"set_play_enabled", true)
	if is_instance_valid(_hylas_camera):
		_hylas_camera.reset_smoothing()


func _restore_hylas_after_failure() -> void:
	if not is_instance_valid(_hylas):
		_clear_transport_state()
		return
	_hylas.global_position = _hylas_start_position
	_restore_hylas_presentation()
	if _hylas.has_method(&"set_play_enabled"):
		_hylas.call(&"set_play_enabled", true)
	if _hylas.has_meta(TRANSPORT_LOCK_META):
		_hylas.remove_meta(TRANSPORT_LOCK_META)
	_intake.cancel_capture(_hylas)
	_intake.release_receiver(_hylas)
	_clear_transport_state()


func _restore_hylas_presentation() -> void:
	if is_instance_valid(_hylas_sprite):
		_hylas_sprite.scale = _sprite_original_scale
		_hylas_sprite.modulate = _sprite_original_modulate
		_hylas_sprite.rotation = 0.0
		_hylas_sprite.flip_h = _sprite_original_flip_h
		_hylas_sprite.visible = _sprite_was_visible
		if _hylas_sprite.sprite_frames != null and _hylas_sprite.sprite_frames.has_animation(&"idle"):
			_hylas_sprite.animation = &"idle"
			_hylas_sprite.speed_scale = 1.0
			_hylas_sprite.play()
	if is_instance_valid(_hylas_shadow):
		_hylas_shadow.rotation = 0.0
		_hylas_shadow.visible = _shadow_was_visible
	if is_instance_valid(_hylas_item_visuals):
		_hylas_item_visuals.visible = _item_visuals_were_visible
	if is_instance_valid(_hylas_collision):
		_hylas_collision.rotation = 0.0
		_hylas_collision.set_deferred(&"disabled", _collision_was_disabled)


func _cancel_transport_before_animation(hylas: Node2D) -> void:
	_intake.cancel_capture(hylas)
	_clear_transport_state()


func _lock_hylas_from_vacuum_capture(hylas: Node, duration_seconds: float) -> void:
	if not is_instance_valid(hylas):
		return
	var lock_duration_msec: int = ceili(maxf(0.0, duration_seconds) * 1000.0)
	hylas.set_meta(
		TRANSPORT_LOCK_META,
		Time.get_ticks_msec() + lock_duration_msec,
	)


func _clear_transport_state() -> void:
	_transport_active = false
	_hylas = null
	_hylas_sprite = null
	_hylas_shadow = null
	_hylas_item_visuals = null
	_hylas_collision = null
	_hylas_camera = null


func get_debug_lines() -> Array[String]:
	return [
		"vacuum_pair_transport_active=%s" % str(_transport_active),
		"vacuum_pair_hylas=%s" % (
			String(_hylas.name) if is_instance_valid(_hylas) else "none"
		),
		"vacuum_pair_capture_duration=%.2f" % capture_duration,
		"vacuum_pair_emergence_duration=%.2f" % emergence_duration,
		"vacuum_pair_recapture_lock=%.2f" % recapture_lock_seconds,
	]
