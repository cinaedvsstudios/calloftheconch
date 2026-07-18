extends Sprite2D

## Keeps the shader-rendered outline exactly matched to Hylas's live sprite.

const SYNC_PRIORITY: int = 1000

@onready var _animated_sprite: AnimatedSprite2D = get_node("../AnimatedSprite") as AnimatedSprite2D


func _ready() -> void:
	if not is_instance_valid(_animated_sprite):
		push_error("Hylas ShadowSprite could not find AnimatedSprite.")
		set_process(false)
		set_physics_process(false)
		return
	process_priority = SYNC_PRIORITY
	process_physics_priority = SYNC_PRIORITY
	_animated_sprite.frame_changed.connect(_sync_texture)
	_animated_sprite.animation_changed.connect(_sync_texture)
	_sync_to_animated_sprite()
	set_process(true)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_sync_to_animated_sprite()


func _process(_delta: float) -> void:
	_sync_to_animated_sprite()


func _sync_texture() -> void:
	if not is_instance_valid(_animated_sprite) or _animated_sprite.sprite_frames == null:
		return
	var frame_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(
		_animated_sprite.animation,
		_animated_sprite.frame,
	)
	if frame_texture != null:
		texture = frame_texture


func _sync_to_animated_sprite() -> void:
	if not is_instance_valid(_animated_sprite):
		return
	_sync_texture()
	# Copy the complete local transform in one operation after Hylas's physics and
	# presentation scripts have finished. This prevents the outline rendering one
	# update ahead of, or behind, the visible sprite during movement and rotation.
	transform = _animated_sprite.transform
	flip_h = _animated_sprite.flip_h
	flip_v = _animated_sprite.flip_v
	centered = _animated_sprite.centered
	offset = _animated_sprite.offset
