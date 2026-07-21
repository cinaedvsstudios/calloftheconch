class_name CotcHylasItemVisuals
extends Node2D

const CAMOUFLAGE_SHADER: Shader = preload("res://scenes/characters/Hylas/hylas_camouflage.gdshader")
const SURGE_GLOW_SHADER: Shader = preload("res://scenes/characters/Hylas/hylas_item_glow.gdshader")
const GREATFIN_FRAMES: SpriteFrames = preload("res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres")
const NORMAL_IDLE_ANIMATION: StringName = &"idle"
const NORMAL_IDLE_SCALE_MULTIPLIER: float = 0.92
const GREATFIN_VISUAL_SCALE: float = 1.30
const HELD_SHELL_VISUAL_SCALE: float = 0.504
const NORMAL_CONCH_ID: StringName = &"normal_conch"
const SUPER_CONCH_ID: StringName = &"charonia_tritonis"
const TEREBRIDAE_ID: StringName = &"terebridae"
const CONUS_TEXTILE_ID: StringName = &"conus_textile"
const SHELL_TEXTURES: Dictionary = {
	NORMAL_CONCH_ID: preload("res://assets/characters/shell_normal_conch.png"),
	SUPER_CONCH_ID: preload("res://assets/characters/shell_charonia_tritonis.png"),
	TEREBRIDAE_ID: preload("res://assets/characters/shell_terebridae.png"),
	CONUS_TEXTILE_ID: preload("res://assets/characters/shell_conus_textile.png"),
}
const HELD_SHELL_SCALE_MULTIPLIERS: Dictionary = {
	SUPER_CONCH_ID: 1.20,
	TEREBRIDAE_ID: 1.20,
}
const HELD_SHELL_POSITION_OFFSETS: Dictionary = {
	SUPER_CONCH_ID: Vector2(0.0, -1.0),
	TEREBRIDAE_ID: Vector2(0.0, -10.0),
	CONUS_TEXTILE_ID: Vector2(0.0, -12.0),
}

@onready var _animated_sprite: AnimatedSprite2D = get_parent().get_node_or_null("AnimatedSprite") as AnimatedSprite2D
@onready var _shell_overlay_anchor: Marker2D = %ConchOverlayAnchor
@onready var _shell_overlay: Sprite2D = %EquippedShellOverlay

var _equipped_item_a: StringName = NORMAL_CONCH_ID
var _camouflage_active: bool = false
var _surge_glow_active: bool = false
var _transforming_active: bool = false
var _greatfin_active: bool = false
var _normal_idle_scale_applied: bool = false
var _normal_runtime_frames: SpriteFrames
var _greatfin_runtime_frames: SpriteFrames
@export var shell_frame_offsets: Array[Vector2] = [
	Vector2(-6.0, 4.0),
	Vector2(-2.0, 1.0),
	Vector2(3.0, -2.0),
	Vector2(7.0, -4.0),
	Vector2(10.0, -3.0),
	Vector2(12.0, 0.0),
]

var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_material: Material
var _camouflage_material: ShaderMaterial
var _surge_glow_material: ShaderMaterial
var _transform_material: ShaderMaterial

func _ready() -> void:
	if _animated_sprite == null:
		push_error("Hylas ItemVisuals requires the sibling AnimatedSprite node.")
		set_process(false)
		return
	_base_sprite_scale = _animated_sprite.scale
	_base_sprite_material = _animated_sprite.material
	_camouflage_material = ShaderMaterial.new()
	_camouflage_material.shader = CAMOUFLAGE_SHADER
	_camouflage_material.resource_local_to_scene = true
	_surge_glow_material = ShaderMaterial.new()
	_surge_glow_material.shader = SURGE_GLOW_SHADER
	_surge_glow_material.resource_local_to_scene = true
	_transform_material = ShaderMaterial.new()
	_transform_material.shader = CAMOUFLAGE_SHADER
	_transform_material.resource_local_to_scene = true
	_transform_material.set_shader_parameter(&"rainbow_mix", 0.0)
	_transform_material.set_shader_parameter(&"glow_color", Color(0.05, 0.95, 1.0, 1.0))
	_transform_material.set_shader_parameter(&"glow_strength", 2.2)
	_transform_material.set_shader_parameter(&"warp_strength", 0.016)
	_transform_material.set_shader_parameter(&"opacity_min", 0.38)
	_transform_material.set_shader_parameter(&"opacity_max", 1.0)
	_transform_material.set_shader_parameter(&"opacity_pulse_speed", 3.2)
	_shell_overlay.texture_filter = _animated_sprite.texture_filter
	_shell_overlay.hide()
	_refresh_shell_texture()
	_refresh_sprite_material()
	_sync_normal_idle_scale()
	set_process(true)

func _process(_delta: float) -> void:
	_sync_normal_idle_scale()
	_sync_shell_overlay()

func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id
	_refresh_shell_texture()
	_sync_shell_overlay()

func set_camouflage_active(is_active: bool) -> void:
	_camouflage_active = is_active
	_refresh_sprite_material()

func is_camouflage_active() -> bool:
	return _camouflage_active

func set_surge_glow_active(is_active: bool) -> void:
	_surge_glow_active = is_active
	_refresh_sprite_material()

func set_transforming_active(is_active: bool) -> void:
	_transforming_active = is_active
	_refresh_sprite_material()

func set_greatfin_active(is_active: bool) -> void:
	if _animated_sprite == null:
		return
	_prepare_runtime_sprite_frames()
	_remove_normal_idle_scale()
	var state_changed: bool = _greatfin_active != is_active
	_greatfin_active = is_active
	_animated_sprite.scale = _base_sprite_scale * (GREATFIN_VISUAL_SCALE if is_active else 1.0)
	if not state_changed:
		_sync_normal_idle_scale()
		return

	var animation_name: StringName = _animated_sprite.animation
	var frame_index: int = _animated_sprite.frame
	var was_playing: bool = _animated_sprite.is_playing()
	_animated_sprite.sprite_frames = _greatfin_runtime_frames if is_active else _normal_runtime_frames
	if _animated_sprite.sprite_frames.has_animation(animation_name):
		_animated_sprite.animation = animation_name
		_animated_sprite.frame = mini(
			frame_index,
			_animated_sprite.sprite_frames.get_frame_count(animation_name) - 1,
		)
		if was_playing:
			_animated_sprite.play(animation_name)
	else:
		_animated_sprite.play(&"idle")
	_sync_normal_idle_scale()

func clear_item_visuals() -> void:
	_camouflage_active = false
	_surge_glow_active = false
	_transforming_active = false
	_refresh_sprite_material()
	_shell_overlay.hide()

func get_shell_rope_origin() -> Vector2:
	if _animated_sprite == null or _shell_overlay.texture == null:
		return global_position
	_sync_shell_overlay()
	var opening_direction: float = -1.0 if _shell_overlay.flip_h else 1.0
	var opening_offset: Vector2 = Vector2(
		float(_shell_overlay.texture.get_width()) * 0.42 * opening_direction,
		0.0,
	)
	return _shell_overlay.to_global(opening_offset)

func _refresh_shell_texture() -> void:
	_shell_overlay.texture = SHELL_TEXTURES.get(_equipped_item_a, null) as Texture2D

func _refresh_sprite_material() -> void:
	var resolved_material: Material = _base_sprite_material
	if _transforming_active:
		resolved_material = _transform_material
	elif _camouflage_active:
		resolved_material = _camouflage_material
	elif _surge_glow_active:
		resolved_material = _surge_glow_material
	_animated_sprite.material = resolved_material
	_shell_overlay.material = resolved_material

func _prepare_runtime_sprite_frames() -> void:
	if _normal_runtime_frames == null:
		_normal_runtime_frames = _animated_sprite.sprite_frames
	if _greatfin_runtime_frames != null:
		return
	_greatfin_runtime_frames = GREATFIN_FRAMES.duplicate(true) as SpriteFrames
	if (
			_normal_runtime_frames.has_animation(NORMAL_IDLE_ANIMATION)
			and _greatfin_runtime_frames.has_animation(NORMAL_IDLE_ANIMATION)
		):
		_greatfin_runtime_frames.set_animation_speed(
			NORMAL_IDLE_ANIMATION,
			_normal_runtime_frames.get_animation_speed(NORMAL_IDLE_ANIMATION),
		)

func _sync_normal_idle_scale() -> void:
	if not is_instance_valid(_animated_sprite):
		return
	var should_enlarge: bool = (
		not _greatfin_active
		and _animated_sprite.animation == NORMAL_IDLE_ANIMATION
	)
	if should_enlarge and not _normal_idle_scale_applied:
		_animated_sprite.scale *= NORMAL_IDLE_SCALE_MULTIPLIER
		_normal_idle_scale_applied = true
	elif not should_enlarge and _normal_idle_scale_applied:
		_remove_normal_idle_scale()

func _remove_normal_idle_scale() -> void:
	if not _normal_idle_scale_applied or not is_instance_valid(_animated_sprite):
		return
	_animated_sprite.scale /= NORMAL_IDLE_SCALE_MULTIPLIER
	_normal_idle_scale_applied = false

func _sync_shell_overlay() -> void:
	if _animated_sprite == null or _shell_overlay.texture == null:
		_shell_overlay.hide()
		return
	var should_show: bool = _animated_sprite.visible and _animated_sprite.animation == &"conch"
	_shell_overlay.visible = should_show
	if not should_show:
		return

	var anchor_offset: Vector2 = _shell_overlay_anchor.position
	var item_position_offset: Variant = HELD_SHELL_POSITION_OFFSETS.get(
		_equipped_item_a,
		Vector2.ZERO,
	)
	if item_position_offset is Vector2:
		anchor_offset += item_position_offset
	var source_frame_index: int = _get_source_conch_frame_index()
	if source_frame_index >= 0 and source_frame_index < shell_frame_offsets.size():
		anchor_offset += shell_frame_offsets[source_frame_index]
	anchor_offset *= _get_live_visual_scale_ratio()
	if _animated_sprite.flip_h:
		anchor_offset.x = -anchor_offset.x
	_shell_overlay.position = anchor_offset.rotated(_animated_sprite.rotation)
	_shell_overlay.rotation = _animated_sprite.rotation
	var item_scale: float = float(
		HELD_SHELL_SCALE_MULTIPLIERS.get(_equipped_item_a, 1.0)
	)
	_shell_overlay.scale = _animated_sprite.scale * HELD_SHELL_VISUAL_SCALE * item_scale
	_shell_overlay.flip_h = _animated_sprite.flip_h
	_shell_overlay.flip_v = _animated_sprite.flip_v
	_shell_overlay.modulate = _animated_sprite.modulate
	_shell_overlay.self_modulate = _animated_sprite.self_modulate
	_shell_overlay.modulate.a *= _get_shell_frame_alpha()
	_shell_overlay.z_index = _animated_sprite.z_index - 1

func _get_live_visual_scale_ratio() -> Vector2:
	return Vector2(
		absf(_animated_sprite.scale.x) / maxf(absf(_base_sprite_scale.x), 0.001),
		absf(_animated_sprite.scale.y) / maxf(absf(_base_sprite_scale.y), 0.001),
	)

func _get_source_conch_frame_index() -> int:
	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"conch")
	if frame_count >= 10:
		return clampi(_animated_sprite.frame - 2, 0, 5)
	return clampi(_animated_sprite.frame, 0, 5)

func _get_shell_frame_alpha() -> float:
	if _equipped_item_a != NORMAL_CONCH_ID and _equipped_item_a != SUPER_CONCH_ID:
		return 1.0
	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"conch")
	if frame_count <= 1:
		return 1.0
	var fade_frame: int = 6 if frame_count >= 10 else maxi(0, frame_count - 2)
	var hidden_frame: int = 7 if frame_count >= 10 else maxi(0, frame_count - 1)
	if _animated_sprite.frame >= hidden_frame:
		return 0.0
	if _animated_sprite.frame == fade_frame:
		return 1.0 - clampf(_animated_sprite.frame_progress, 0.0, 1.0)
	return 1.0

func get_debug_lines() -> Array[String]:
	return [
		"[HylasItemVisuals]",
		"equipped_item_a=%s" % String(_equipped_item_a),
		"greatfin_active=%s" % str(_greatfin_active),
		"greatfin_visual_scale=%.2f" % GREATFIN_VISUAL_SCALE,
		"normal_idle_scale=%.2f" % NORMAL_IDLE_SCALE_MULTIPLIER,
		"transforming_active=%s" % str(_transforming_active),
		"camouflage_active=%s" % str(_camouflage_active),
		"surge_glow_active=%s" % str(_surge_glow_active),
		"conch_anchor=%s" % str(_shell_overlay_anchor.position),
	]