class_name CotcSeaweedSlowArea
extends Area2D

## Adds a non-stacking movement slowdown while Hylas overlaps an existing
## seaweed scene. The parent AnimatedSprite2D remains the visual scene root.

@export_category("Slowdown")
@export_range(0.05, 1.0, 0.05) var movement_multiplier: float = 0.5

@export_category("Automatic Collision Coverage")
@export_range(0.1, 1.0, 0.05) var collision_width_ratio: float = 0.82
@export_range(0.1, 1.0, 0.05) var collision_height_ratio: float = 0.92
@export var collision_offset_ratio: Vector2 = Vector2(0.0, 0.02)

@onready var _collision_shape: CollisionShape2D = %SlowCollision

var _affected_hylas: Dictionary[Node, bool] = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_configure_collision_from_parent_sprite()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	for hylas: Node in _affected_hylas.keys():
		_remove_slow_from_hylas(hylas)
	_affected_hylas.clear()


func _configure_collision_from_parent_sprite() -> void:
	var sprite: AnimatedSprite2D = get_parent() as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		push_warning("CotcSeaweedSlowArea requires an AnimatedSprite2D parent.")
		return

	var animation_name: StringName = sprite.animation
	if String(animation_name).is_empty() or not sprite.sprite_frames.has_animation(animation_name):
		animation_name = &"idle"
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return

	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if texture == null:
		return

	var rectangle: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		_collision_shape.shape = rectangle
	var texture_size: Vector2 = texture.get_size()
	rectangle.size = Vector2(
		maxf(1.0, texture_size.x * collision_width_ratio),
		maxf(1.0, texture_size.y * collision_height_ratio),
	)
	_collision_shape.position = Vector2(
		texture_size.x * collision_offset_ratio.x,
		texture_size.y * collision_offset_ratio.y,
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"hylas"):
		return
	if not body.has_method(&"set_seaweed_slow_source"):
		return
	_affected_hylas[body] = true
	body.call(&"set_seaweed_slow_source", self, movement_multiplier)


func _on_body_exited(body: Node2D) -> void:
	if not _affected_hylas.has(body):
		return
	_affected_hylas.erase(body)
	_remove_slow_from_hylas(body)


func _remove_slow_from_hylas(hylas: Node) -> void:
	if is_instance_valid(hylas) and hylas.has_method(&"remove_seaweed_slow_source"):
		hylas.call(&"remove_seaweed_slow_source", self)
