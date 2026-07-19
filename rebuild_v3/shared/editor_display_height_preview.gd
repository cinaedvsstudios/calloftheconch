@tool
class_name CotcEditorDisplayHeightPreview
extends Node

## Mirrors a runtime display_height property onto an AnimatedSprite2D in the
## editor, so placed instances have the same visible size before and during play.

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
	var sprite: AnimatedSprite2D = get_node_or_null(target_sprite_path) as AnimatedSprite2D
	if source == null or sprite == null or sprite.sprite_frames == null:
		return

	var requested_height_variant: Variant = source.get(source_property)
	if requested_height_variant == null:
		return
	var requested_height: float = maxf(1.0, float(requested_height_variant))

	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if texture == null:
		return
	var texture_height: float = maxf(1.0, float(texture.get_height()))
	var intended_scale: Vector2 = Vector2.ONE * (requested_height / texture_height)
	if not sprite.scale.is_equal_approx(intended_scale):
		sprite.scale = intended_scale
