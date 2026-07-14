@tool
class_name CotcAlphaCollisionLandscape
extends StaticBody2D

## Lightweight editor-safe wrapper for one reusable landscape scene.
## It only assigns the scene's source texture to its Sprite2D.
## Collision is stored as an ordinary editable CollisionPolygon2D in the scene;
## no nodes are generated, removed, or rebuilt by script.

@export_category("Landscape")
@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		_apply_texture()

@export var landscape_id: StringName = &""

@onready var _sprite: Sprite2D = %Sprite


func _ready() -> void:
	_apply_texture()


func _apply_texture() -> void:
	if not is_inside_tree():
		return
	var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = source_texture


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if source_texture == null:
		warnings.append("Assign the source texture for this landscape scene.")
	return warnings
