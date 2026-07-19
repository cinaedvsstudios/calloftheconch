extends "res://scenes/characters/Hylas/hylas_vent_surface_jump.gd"

## Adds Leaf Sheep carry presentation and movement restrictions to Hylas.

signal leaf_sheep_forced_deactivation_requested(reason: StringName)

const CARRY_ANIMATION: StringName = &"carry"
const NORMAL_CARRY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/hylas-carry01.webp"),
	preload("res://assets/characters/hylas-carry02.webp"),
	preload("res://assets/characters/hylas-carry03.webp"),
	preload("res://assets/characters/hylas-carry04.webp"),
]
const GREATFIN_CARRY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/hylas-greatfin-carry01.webp"),
	preload("res://assets/characters/hylas-greatfin-carry02.webp"),
	preload("res://assets/characters/hylas-greatfin-carry03.webp"),
	preload("res://assets/characters/hylas-greatfin-carry04.webp"),
]
const GREATFIN_FRAMES: SpriteFrames = preload(
	"res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres"
)

@export_category("Leaf Sheep Carry")
@export_range(0.1, 30.0, 0.1) var leaf_sheep_carry_fps: float = 6.0
@export var leaf_sheep_hand_offset: Vector2 = Vector2(45.0, -24.0)
@export var leaf_sheep_carry_frame_offsets: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, -1.0),
	Vector2(2.0, -1.0),
	Vector2(1.0, 0.0),
]
@export var leaf_sheep_conch_frame_offsets: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(1.0, -1.0),
	Vector2(2.0, -2.0),
	Vector2(3.0, -3.0),
	Vector2(4.0, -3.0),
	Vector2(4.0, -2.0),
	Vector2(3.0, -1.0),
	Vector2(2.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, 0.0),
]

var _leaf_sheep_active: bool = false


func _ready() -> void:
	super._ready()
	_install_carry_animation(_animated_sprite.sprite_frames, NORMAL_CARRY_TEXTURES)
	_install_carry_animation(GREATFIN_FRAMES, GREATFIN_CARRY_TEXTURES)


func set_leaf_sheep_active(is_active: bool) -> void:
	if _leaf_sheep_active == is_active:
		return
	_leaf_sheep_active = is_active
	if _leaf_sheep_active:
		_cancel_blocked_leaf_sheep_actions()
		if _conch_remaining <= 0.0:
			_set_animation(CARRY_ANIMATION)
	elif _animated_sprite.animation == CARRY_ANIMATION:
		_set_animation(&"idle")


func is_leaf_sheep_active() -> bool:
	return _leaf_sheep_active


func can_activate_leaf_sheep() -> bool:
	return (
		_play_enabled
		and not _death_sequence_active
		and not crawl_active
		and not airborne_active
		and not _conus_climb_active
	)


func get_leaf_sheep_hand_world_position() -> Vector2:
	var local_offset: Vector2 = leaf_sheep_hand_offset + _get_leaf_sheep_frame_offset()
	if _animated_sprite.flip_h:
		local_offset.x = -local_offset.x
	return to_global(_animated_sprite.position + local_offset.rotated(_animated_sprite.rotation))


func get_leaf_sheep_visual_rotation() -> float:
	return _animated_sprite.rotation


func is_leaf_sheep_facing_left() -> bool:
	return _animated_sprite.flip_h


func is_leaf_sheep_carry_animation_active() -> bool:
	return _leaf_sheep_active and _animated_sprite.animation == CARRY_ANIMATION


func is_leaf_sheep_greatfin_carry_active() -> bool:
	return is_leaf_sheep_carry_animation_active() and _item_visuals != null and bool(
		_item_visuals.get("_greatfin_active")
	)


func activate_item_surge(duration_seconds: float = 0.90) -> bool:
	if _leaf_sheep_active:
		return false
	return super.activate_item_surge(duration_seconds)


func begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if _leaf_sheep_active:
		return
	super.begin_conus_wall_climb(anchor_position, tether)


func begin_crawl() -> void:
	if _leaf_sheep_active:
		leaf_sheep_forced_deactivation_requested.emit(&"land")
	super.begin_crawl()


func start_death_sequence() -> void:
	if _leaf_sheep_active:
		leaf_sheep_forced_deactivation_requested.emit(&"death")
	super.start_death_sequence()


func _can_start_burst(input_direction: Vector2) -> bool:
	if _leaf_sheep_active:
		return false
	return super._can_start_burst(input_direction)


func _start_burst(input_direction: Vector2) -> void:
	if _leaf_sheep_active:
		return
	super._start_burst(input_direction)


func _start_tail_flip() -> void:
	if _leaf_sheep_active:
		return
	super._start_tail_flip()


func _set_animation(animation_name: StringName) -> void:
	var resolved_animation: StringName = animation_name
	if _leaf_sheep_active and animation_name in [
		&"idle",
		&"swim",
		&"stop",
		&"stop_release",
	]:
		resolved_animation = CARRY_ANIMATION
	super._set_animation(resolved_animation)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaf_sheep_active and (crawl_active or airborne_active):
		leaf_sheep_forced_deactivation_requested.emit(&"left_water")


func _cancel_blocked_leaf_sheep_actions() -> void:
	_burst_active = false
	_burst_remaining = 0.0
	_pending_surface_jump = false
	_tail_flip_remaining = 0.0
	_stop_burst_audio()
	if _conus_climb_active:
		end_conus_wall_climb()


func _install_carry_animation(
		sprite_frames: SpriteFrames,
		textures: Array[Texture2D],
	) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(CARRY_ANIMATION):
		sprite_frames.clear(CARRY_ANIMATION)
	else:
		sprite_frames.add_animation(CARRY_ANIMATION)
	for texture: Texture2D in textures:
		sprite_frames.add_frame(CARRY_ANIMATION, texture)
	sprite_frames.set_animation_speed(CARRY_ANIMATION, leaf_sheep_carry_fps)
	sprite_frames.set_animation_loop(CARRY_ANIMATION, true)


func _get_leaf_sheep_frame_offset() -> Vector2:
	var offsets: Array[Vector2] = leaf_sheep_carry_frame_offsets
	if _animated_sprite.animation == &"conch":
		offsets = leaf_sheep_conch_frame_offsets
	if offsets.is_empty():
		return Vector2.ZERO
	return offsets[clampi(_animated_sprite.frame, 0, offsets.size() - 1)]


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("leaf_sheep_hylas_active=%s" % str(_leaf_sheep_active))
	lines.append("leaf_sheep_carry_animation=%s" % str(_animated_sprite.animation == CARRY_ANIMATION))
	lines.append("leaf_sheep_hand_position=%s" % str(get_leaf_sheep_hand_world_position()))
	return lines
