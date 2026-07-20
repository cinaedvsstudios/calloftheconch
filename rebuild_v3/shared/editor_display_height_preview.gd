@tool
class_name CotcEditorDisplayHeightPreview
extends Node

## Applies a display_height property to either a Sprite2D or AnimatedSprite2D.
## The same calculation runs in the editor and once at runtime, so the editor
## shows the final visual size before any level-instance scale is applied.

@export var source_node_path: NodePath = ^".."
@export var source_property: StringName = &"display_height"
@export var target_sprite_path: NodePath = ^"../AnimatedSprite"
@export var animation_name: StringName = &"idle"
@export_range(0.05, 1.0, 0.05) var editor_refresh_seconds: float = 0.20

var _refresh_elapsed: float = 0.0


func _ready() -> void:
	_apply_display_scale()
	set_process(Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_elapsed += maxf(0.0, delta)
	if _refresh_elapsed < editor_refresh_seconds:
		return
	_refresh_elapsed = 0.0
	_apply_display_scale()


func _apply_display_scale() -> void:
	var source: Object = get_node_or_null(source_node_path)
	var target_sprite: Node2D = get_node_or_null(target_sprite_path) as Node2D
	if source == null or target_sprite == null:
		return

	var requested_height_variant: Variant = source.get(source_property)
	if requested_height_variant == null:
		return
	var requested_height: float = maxf(1.0, float(requested_height_variant))

	var texture: Texture2D = _get_reference_texture(target_sprite)
	if texture == null:
		return
	var texture_height: float = maxf(1.0, float(texture.get_height()))
	var intended_scale: Vector2 = Vector2.ONE * (requested_height / texture_height)
	if not target_sprite.scale.is_equal_approx(intended_scale):
		target_sprite.scale = intended_scale


func _get_reference_texture(target_sprite: Node2D) -> Texture2D:
	var static_sprite: Sprite2D = target_sprite as Sprite2D
	if static_sprite != null:
		return static_sprite.texture

	var animated_sprite: AnimatedSprite2D = target_sprite as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return null
	return animated_sprite.sprite_frames.get_frame_texture(animation_name, 0)
