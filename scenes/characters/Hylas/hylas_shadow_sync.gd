extends Sprite2D

## Keeps the shader-rendered outline exactly matched to Hylas's live sprite.

@onready var _animated_sprite: AnimatedSprite2D = get_node("../AnimatedSprite") as AnimatedSprite2D


func _ready() -> void:
	_animated_sprite.frame_changed.connect(_sync_texture)
	_animated_sprite.animation_changed.connect(_sync_texture)
	_sync_to_animated_sprite()


func _process(_delta: float) -> void:
	_sync_to_animated_sprite()


func _sync_texture() -> void:
	var frame_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(
		_animated_sprite.animation,
		_animated_sprite.frame,
	)
	if frame_texture != null:
		texture = frame_texture


func _sync_to_animated_sprite() -> void:
	_sync_texture()
	flip_h = _animated_sprite.flip_h
	position = _animated_sprite.position
	rotation = _animated_sprite.rotation
	scale = _animated_sprite.scale
