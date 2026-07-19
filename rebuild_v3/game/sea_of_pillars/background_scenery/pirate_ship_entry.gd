class_name CotcPirateShipEntry
extends Node2D

const HYLAS_FLIP_01: Texture2D = preload("res://assets/characters/hylas-flip_01.webp")
const HYLAS_FLIP_02: Texture2D = preload("res://assets/characters/hylas-flip_02.webp")
const HYLAS_FLIP_04: Texture2D = preload("res://assets/characters/hylas-flip_04.webp")

@export_file("*.tscn") var interior_scene_path: String = (
	"res://rebuild_v3/game/sea_of_pillars/levels/pirate_ship_interior.tscn"
)
@export_range(0.05, 0.50, 0.01) var entry_frame_seconds: float = 0.14
@export_range(0.25, 4.00, 0.05) var retreat_duration: float = 1.40
@export_range(0.10, 1.00, 0.01) var retreat_scale_multiplier: float = 0.75
@export_range(0.00, 1.00, 0.01) var retreat_brightness: float = 0.40
@export_range(0.0, 20.0, 0.5) var retreat_rock_degrees: float = 5.0
@export var retreat_offset: Vector2 = Vector2(0.0, -70.0)

@onready var _action_point: Marker2D = %ShipEntryActionPoint
@onready var _interaction_area: Area2D = %ShipEntryArea
@onready var _entry_visual: Sprite2D = %EntryHylasVisual

var _hylas: Node2D
var _hylas_sprite: AnimatedSprite2D
var _hylas_shadow: CanvasItem
var _hylas_item_visuals: CanvasItem
var _hylas_collision: CollisionShape2D
var _entry_active: bool = false
var _sprite_was_visible: bool = true
var _shadow_was_visible: bool = true
var _item_visuals_were_visible: bool = true


func _on_ship_entry_area_body_entered(body: Node2D) -> void:
	if _entry_active or not _is_hylas(body):
		return
	_hylas = body
	var callback := Callable(self, "_on_hylas_interaction_requested")
	if body.has_signal(&"interaction_requested") and not body.is_connected(
			&"interaction_requested",
			callback,
		):
		body.connect(&"interaction_requested", callback)
	if body.has_method(&"set_interaction_available"):
		body.call(&"set_interaction_available", true)


func _on_ship_entry_area_body_exited(body: Node2D) -> void:
	if body != _hylas or _entry_active:
		return
	_release_hylas_interaction()


func _on_hylas_interaction_requested() -> void:
	if _entry_active or not is_instance_valid(_hylas):
		return
	if not _interaction_area.overlaps_body(_hylas):
		return
	_entry_active = true
	call_deferred(&"_begin_entry_sequence")


func _begin_entry_sequence() -> void:
	if not is_instance_valid(_hylas):
		_entry_active = false
		return

	if _hylas.has_method(&"cancel_pending_interaction"):
		_hylas.call(&"cancel_pending_interaction")
	if _hylas.has_method(&"set_interaction_available"):
		_hylas.call(&"set_interaction_available", false)
	if _hylas.has_method(&"set_play_enabled"):
		_hylas.call(&"set_play_enabled", false)

	_hylas_sprite = _hylas.get_node_or_null(^"%AnimatedSprite") as AnimatedSprite2D
	_hylas_shadow = _hylas.get_node_or_null(^"%ShadowSprite") as CanvasItem
	_hylas_item_visuals = _hylas.get_node_or_null(^"%ItemVisuals") as CanvasItem
	_hylas_collision = _hylas.get_node_or_null(^"%CollisionShape") as CollisionShape2D

	if _hylas_sprite == null:
		push_error("Pirate ship entry requires Hylas to have an AnimatedSprite node.")
		_restore_after_failed_transition()
		return

	_sprite_was_visible = _hylas_sprite.visible
	_shadow_was_visible = _hylas_shadow.visible if _hylas_shadow != null else false
	_item_visuals_were_visible = (
		_hylas_item_visuals.visible if _hylas_item_visuals != null else false
	)

	_entry_visual.global_transform = _hylas_sprite.global_transform
	_entry_visual.flip_h = _hylas_sprite.flip_h
	_entry_visual.modulate = Color.WHITE
	_entry_visual.texture = HYLAS_FLIP_01
	_entry_visual.show()

	_hylas_sprite.hide()
	if _hylas_shadow != null:
		_hylas_shadow.hide()
	if _hylas_item_visuals != null:
		_hylas_item_visuals.hide()
	if _hylas_collision != null:
		_hylas_collision.set_deferred(&"disabled", true)

	for texture: Texture2D in [HYLAS_FLIP_01, HYLAS_FLIP_02, HYLAS_FLIP_04]:
		_entry_visual.texture = texture
		await get_tree().create_timer(entry_frame_seconds, false).timeout

	await _play_retreat_motion()
	var transition_error: Error = get_tree().change_scene_to_file(interior_scene_path)
	if transition_error != OK:
		push_error(
			"Could not enter pirate ship interior '%s' (error %d)."
			% [interior_scene_path, transition_error]
		)
		_restore_after_failed_transition()


func _play_retreat_motion() -> void:
	_entry_visual.texture = HYLAS_FLIP_04
	var starting_scale: Vector2 = _entry_visual.scale
	var starting_rotation: float = _entry_visual.rotation
	var target_position: Vector2 = _action_point.global_position + retreat_offset
	var target_brightness := Color(
		retreat_brightness,
		retreat_brightness,
		retreat_brightness,
		1.0,
	)

	var retreat_tween: Tween = create_tween()
	retreat_tween.set_parallel(true)
	retreat_tween.set_trans(Tween.TRANS_SINE)
	retreat_tween.set_ease(Tween.EASE_IN_OUT)
	retreat_tween.tween_property(
		_entry_visual,
		^"global_position",
		target_position,
		retreat_duration,
	)
	retreat_tween.tween_property(
		_entry_visual,
		^"scale",
		starting_scale * retreat_scale_multiplier,
		retreat_duration,
	)
	retreat_tween.tween_property(
		_entry_visual,
		^"modulate",
		target_brightness,
		retreat_duration,
	)

	var rock_angle: float = deg_to_rad(retreat_rock_degrees)
	var rock_tween: Tween = create_tween()
	rock_tween.set_trans(Tween.TRANS_SINE)
	rock_tween.set_ease(Tween.EASE_IN_OUT)
	rock_tween.tween_property(
		_entry_visual,
		^"rotation",
		starting_rotation + rock_angle,
		retreat_duration * 0.25,
	)
	rock_tween.tween_property(
		_entry_visual,
		^"rotation",
		starting_rotation - rock_angle,
		retreat_duration * 0.50,
	)
	rock_tween.tween_property(
		_entry_visual,
		^"rotation",
		starting_rotation,
		retreat_duration * 0.25,
	)

	await retreat_tween.finished
	if rock_tween.is_running():
		rock_tween.kill()


func _restore_after_failed_transition() -> void:
	_entry_visual.hide()
	if is_instance_valid(_hylas_sprite):
		_hylas_sprite.visible = _sprite_was_visible
	if is_instance_valid(_hylas_shadow):
		_hylas_shadow.visible = _shadow_was_visible
	if is_instance_valid(_hylas_item_visuals):
		_hylas_item_visuals.visible = _item_visuals_were_visible
	if is_instance_valid(_hylas_collision):
		_hylas_collision.set_deferred(&"disabled", false)
	if is_instance_valid(_hylas):
		if _hylas.has_method(&"set_play_enabled"):
			_hylas.call(&"set_play_enabled", true)
		if _interaction_area.overlaps_body(_hylas) and _hylas.has_method(
				&"set_interaction_available"
			):
			_hylas.call(&"set_interaction_available", true)
	_entry_active = false


func _release_hylas_interaction() -> void:
	if not is_instance_valid(_hylas):
		_hylas = null
		return
	if _hylas.has_method(&"set_interaction_available"):
		_hylas.call(&"set_interaction_available", false)
	if _hylas.has_method(&"cancel_pending_interaction"):
		_hylas.call(&"cancel_pending_interaction")
	var callback := Callable(self, "_on_hylas_interaction_requested")
	if _hylas.has_signal(&"interaction_requested") and _hylas.is_connected(
			&"interaction_requested",
			callback,
		):
		_hylas.disconnect(&"interaction_requested", callback)
	_hylas = null


func _is_hylas(body: Node) -> bool:
	return body != null and body.is_in_group(&"hylas")
