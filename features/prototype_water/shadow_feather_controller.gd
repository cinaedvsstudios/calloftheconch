class_name ShadowFeatherController
extends Node
## Keeps Hylas's shadow as a tiny diffuse oval, never as a second character silhouette.

const SHADOW_SIZE: Vector2i = Vector2i(104, 52)
const SHADOW_OFFSET: Vector2 = Vector2(7.0, 9.0)
const SHADOW_CORE_ALPHA: float = 0.115
const SHADOW_TINT: Color = Color(0.0, 0.035, 0.11, 1.0)

@onready var _hylas: HylasController = get_parent() as HylasController
@onready var _shadow: Sprite2D = _hylas.get_node_or_null("HylasShadow") as Sprite2D

var _soft_oval_texture: ImageTexture


func _ready() -> void:
	process_priority = 200
	if _hylas == null or _shadow == null:
		set_process(false)
		return
	_soft_oval_texture = _create_soft_oval_texture()
	call_deferred("_apply_shadow")


func _process(_delta: float) -> void:
	_apply_shadow()


func _apply_shadow() -> void:
	if _shadow == null or _soft_oval_texture == null:
		return
	_shadow.texture = _soft_oval_texture
	_shadow.material = null
	_shadow.position = SHADOW_OFFSET
	_shadow.rotation = 0.0
	_shadow.flip_h = false
	_shadow.scale = Vector2.ONE
	_shadow.modulate = Color.WHITE
	_shadow.visible = true


func _create_soft_oval_texture() -> ImageTexture:
	var image: Image = Image.create(SHADOW_SIZE.x, SHADOW_SIZE.y, false, Image.FORMAT_RGBA8)
	var centre: Vector2 = Vector2(float(SHADOW_SIZE.x - 1) * 0.5, float(SHADOW_SIZE.y - 1) * 0.5)
	var horizontal_radius: float = float(SHADOW_SIZE.x) * 0.5
	var vertical_radius: float = float(SHADOW_SIZE.y) * 0.5

	for y: int in range(SHADOW_SIZE.y):
		for x: int in range(SHADOW_SIZE.x):
			var normalised_x: float = (float(x) - centre.x) / horizontal_radius
			var normalised_y: float = (float(y) - centre.y) / vertical_radius
			var distance_squared: float = normalised_x * normalised_x + normalised_y * normalised_y
			var alpha: float = SHADOW_CORE_ALPHA * exp(-distance_squared * 4.8)
			image.set_pixel(x, y, Color(SHADOW_TINT.r, SHADOW_TINT.g, SHADOW_TINT.b, alpha))

	return ImageTexture.create_from_image(image)