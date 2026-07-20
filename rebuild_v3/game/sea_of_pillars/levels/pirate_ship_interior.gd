class_name CotcPirateShipInterior
extends Node2D

signal exit_requested
signal transition_finished

## Scrollable pirate-ship interior loaded locally by CotcPirateShipCoordinator.
## The ship art remains at its native world size while a magnified Camera2D
## follows Hylas and is clamped to the texture edges.

@export_category("Room")
@export var fallback_interior_size: Vector2 = Vector2(1280.0, 720.0)
@export var interior_waterline_y: float = -10000.0

@export_category("Camera")
@export_range(1.0, 2.5, 0.01) var camera_zoom: float = 1.30
@export_range(0.0, 20.0, 0.1) var camera_smoothing_speed: float = 5.5
@export_range(0.0, 0.5, 0.01) var camera_drag_margin: float = 0.12

@export_category("Exit")
@export var exit_action: StringName = &"move_up"
@export_range(0.05, 1.5, 0.05) var transition_seconds: float = 0.28

@onready var _interior_world: Node2D = %InteriorWorld
@onready var _background: Sprite2D = %ShipwreckBackground
@onready var _hylas: CotcHylas = %Hylas
@onready var _hylas_start: Marker2D = %HylasStart
@onready var _exit_area: Area2D = %ShipExitArea
@onready var _exit_prompt: Control = %ExitPrompt
@onready var _bubble_canvas: CanvasLayer = %BubbleCanvas
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _underwater_ambience: AudioStreamPlayer = %UnderwaterAmbience
@onready var _fade_rect: ColorRect = %FadeRect

var _camera: Camera2D
var _room_size: Vector2 = Vector2.ZERO
var _active: bool = false
var _hylas_in_exit: bool = false
var _exit_pending: bool = false
var _fade_tween: Tween


func _ready() -> void:
	_camera = _hylas.get_node_or_null(^"Camera2D") as Camera2D
	_configure_room_from_background()
	_set_exit_prompt_visible(false)
	_set_interior_visuals_visible(false)
	_fade_rect.modulate.a = 0.0
	set_process_unhandled_input(false)


func _exit_tree() -> void:
	_stop_room_ambience()


func activate() -> void:
	if _active:
		return
	_active = true
	_exit_pending = false
	_hylas_in_exit = false
	if not _hylas.is_in_group(&"hylas"):
		_hylas.add_to_group(&"hylas")
	show()
	_set_interior_visuals_visible(true)
	_configure_room_from_background()
	_configure_hylas()
	_configure_camera()
	_start_room_ambience()
	_set_exit_prompt_visible(false)
	set_process_unhandled_input(true)
	_fade_from_black()


func complete_exit_transition() -> void:
	_stop_room_ambience()
	_set_exit_prompt_visible(false)
	set_process_unhandled_input(false)
	_hylas.set_play_enabled(false)
	if _camera != null:
		_camera.enabled = false
	_set_interior_visuals_visible(false)
	_fade_to_clear_and_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _exit_pending or not _hylas_in_exit:
		return
	if event.is_action_pressed(exit_action, false, true):
		get_viewport().set_input_as_handled()
		_begin_exit()


func _on_ship_exit_area_body_entered(body: Node2D) -> void:
	if body != _hylas or not _active or _exit_pending:
		return
	_hylas_in_exit = true
	_set_exit_prompt_visible(true)


func _on_ship_exit_area_body_exited(body: Node2D) -> void:
	if body != _hylas:
		return
	_hylas_in_exit = false
	_set_exit_prompt_visible(false)


func _begin_exit() -> void:
	if _exit_pending:
		return
	_exit_pending = true
	_hylas.set_play_enabled(false)
	_hylas.velocity = Vector2.ZERO
	_set_exit_prompt_visible(false)
	set_process_unhandled_input(false)
	_kill_fade_tween()
	_fade_rect.show()
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		_fade_rect,
		^"modulate:a",
		1.0,
		maxf(0.01, transition_seconds),
	)
	await _fade_tween.finished
	if _hylas.is_in_group(&"hylas"):
		_hylas.remove_from_group(&"hylas")
	exit_requested.emit()


func _configure_room_from_background() -> void:
	_room_size = fallback_interior_size
	if _background != null and _background.texture != null:
		var texture_size: Vector2 = _background.texture.get_size()
		if texture_size.x > 1.0 and texture_size.y > 1.0:
			_room_size = texture_size


func _configure_hylas() -> void:
	if not is_instance_valid(_hylas) or not is_instance_valid(_hylas_start):
		push_error("Pirate ship interior requires Hylas and HylasStart nodes.")
		return
	_hylas.current_base_velocity = Vector2.ZERO
	_hylas.current_sway_horizontal = 0.0
	_hylas.current_sway_vertical = 0.0
	_hylas.configure_world(
		Rect2(Vector2.ZERO, _room_size),
		interior_waterline_y,
		_hylas_start.global_position,
	)
	_hylas.velocity = Vector2.ZERO
	_hylas.reset_to_start(_hylas_start.global_position)
	_hylas.set_play_enabled(true)


func _configure_camera() -> void:
	if _camera == null:
		push_error("Pirate ship interior Hylas is missing Camera2D.")
		return
	_camera.enabled = true
	_camera.zoom = Vector2.ONE * maxf(1.0, camera_zoom)
	_camera.position_smoothing_enabled = camera_smoothing_speed > 0.0
	_camera.position_smoothing_speed = maxf(0.0, camera_smoothing_speed)
	_camera.drag_horizontal_enabled = true
	_camera.drag_vertical_enabled = true
	_camera.drag_left_margin = camera_drag_margin
	_camera.drag_right_margin = camera_drag_margin
	_camera.drag_top_margin = camera_drag_margin
	_camera.drag_bottom_margin = camera_drag_margin
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(round(_room_size.x))
	_camera.limit_bottom = int(round(_room_size.y))
	_camera.limit_smoothed = true
	_camera.reset_smoothing()
	_camera.make_current()


func _start_room_ambience() -> void:
	if is_instance_valid(_bubble_overlay) and _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()
	if is_instance_valid(_underwater_ambience) and _underwater_ambience.stream != null:
		_underwater_ambience.play()


func _stop_room_ambience() -> void:
	if is_instance_valid(_bubble_overlay):
		_bubble_overlay.stop()
		_bubble_overlay.hide()
	if is_instance_valid(_underwater_ambience):
		_underwater_ambience.stop()


func _set_interior_visuals_visible(is_visible: bool) -> void:
	if is_instance_valid(_interior_world):
		_interior_world.visible = is_visible
	if is_instance_valid(_bubble_canvas):
		_bubble_canvas.visible = is_visible


func _set_exit_prompt_visible(is_visible: bool) -> void:
	if is_instance_valid(_exit_prompt):
		_exit_prompt.visible = is_visible and _active and not _exit_pending


func _fade_from_black() -> void:
	_kill_fade_tween()
	_fade_rect.show()
	_fade_rect.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		_fade_rect,
		^"modulate:a",
		0.0,
		maxf(0.01, transition_seconds),
	)
	_fade_tween.finished.connect(_fade_rect.hide, CONNECT_ONE_SHOT)


func _fade_to_clear_and_finish() -> void:
	_kill_fade_tween()
	_fade_rect.show()
	_fade_rect.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		_fade_rect,
		^"modulate:a",
		0.0,
		maxf(0.01, transition_seconds),
	)
	await _fade_tween.finished
	_fade_rect.hide()
	hide()
	_active = false
	_exit_pending = false
	transition_finished.emit()


func _kill_fade_tween() -> void:
	if is_instance_valid(_fade_tween) and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null


func get_debug_lines() -> Array[String]:
	return [
		"[PirateShipInterior]",
		"active=%s" % str(_active),
		"room_size=%s" % str(_room_size),
		"camera_zoom=%.2f" % camera_zoom,
		"hylas_in_exit=%s" % str(_hylas_in_exit),
		"exit_pending=%s" % str(_exit_pending),
	]
