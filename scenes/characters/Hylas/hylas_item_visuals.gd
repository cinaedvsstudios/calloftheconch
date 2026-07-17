class_name CotcHylasItemVisuals
extends Node2D

const CAMOUFLAGE_SHADER: Shader = preload("res://scenes/characters/Hylas/hylas_camouflage.gdshader")
const SURGE_GLOW_SHADER: Shader = preload("res://scenes/characters/Hylas/hylas_item_glow.gdshader")
const NORMAL_FRAMES: SpriteFrames = preload("res://scenes/characters/Hylas/hylas_v3_sprite_frames.tres")
const GREATFIN_FRAMES: SpriteFrames = preload("res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres")
const GREATFIN_VISUAL_SCALE: float = 1.30
const HELD_SHELL_VISUAL_SCALE: float = 0.504
const SHELL_TEXTURES: Dictionary = {
	&"normal_conch": preload("res://assets/characters/shell_normal_conch.png"),
	&"charonia_tritonis": preload("res://assets/characters/shell_charonia_tritonis.png"),
	&"terebridae": preload("res://assets/characters/shell_terebridae.png"),
	&"conus_textile": preload("res://assets/characters/shell_conus_textile.png"),
}
const HELD_SHELL_SCALE_MULTIPLIERS: Dictionary = {
	&"charonia_tritonis": 1.20,
	&"terebridae": 1.20,
}

@onready var _animated_sprite: AnimatedSprite2D = get_parent().get_node_or_null("AnimatedSprite") as AnimatedSprite2D
@onready var _shell_overlay_anchor: Marker2D = %ConchOverlayAnchor
@onready var _shell_overlay: Sprite2D = %EquippedShellOverlay

var _equipped_item_a: StringName = &"normal_conch"
var _camouflage_active: bool = false
var _surge_glow_active: bool = false
var _transforming_active: bool = false
var _greatfin_active: bool = false
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
	set_process(true)

func _process(_delta: float) -> void:
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
	var state_changed: bool = _greatfin_active != is_active
	_greatfin_active = is_active
	_animated_sprite.scale = _base_sprite_scale * (GREATFIN_VISUAL_SCALE if is_active else 1.0)
	if not state_changed:
		return

	var animation_name: StringName = _animated_sprite.animation
	var frame_index: int = _animated_sprite.frame
	var was_playing: bool = _animated_sprite.is_playing()
	_animated_sprite.sprite_frames = GREATFIN_FRAMES if is_active else NORMAL_FRAMES
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

func clear_item_visuals() -> void:
	_camouflage_active = false
	_surge_glow_active = false
	_transforming_active = false
	_refresh_sprite_material()
	_shell_overlay.hide()

func get_shell_rope_origin() -> Vector2:
	if _animated_sprite == null or _shell_overlay.texture == null:
		return get_parent().global_position
	_sync_shell_overlay()
	return _shell_overlay.global_position

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

func _sync_shell_overlay() -> void:
	if _animated_sprite == null or _shell_overlay.texture == null:
		_shell_overlay.hide()
		return
	var should_show: bool = _animated_sprite.visible and _animated_sprite.animation == &"conch"
	_shell_overlay.visible = should_show
	if not should_show:
		return

	var anchor_offset: Vector2 = _shell_overlay_anchor.position
	if _animated_sprite.animation == &"conch" and _animated_sprite.frame < shell_frame_offsets.size():
		anchor_offset += shell_frame_offsets[_animated_sprite.frame]
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
	_shell_overlay.z_index = _animated_sprite.z_index - 1

func get_debug_lines() -> Array[String]:
	return [
		"[HylasItemVisuals]",
		"equipped_item_a=%s" % String(_equipped_item_a),
		"greatfin_active=%s" % str(_greatfin_active),
		"greatfin_visual_scale=%.2f" % GREATFIN_VISUAL_SCALE,
		"transforming_active=%s" % str(_transforming_active),
		"camouflage_active=%s" % str(_camouflage_active),
		"surge_glow_active=%s" % str(_surge_glow_active),
		"conch_anchor=%s" % str(_shell_overlay_anchor.position),
	]