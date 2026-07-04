class_name ShadowFeatherController
extends Node2D
## Draws a subtle, diffuse oval shadow. It never reuses Hylas's sprite texture.

const SHADOW_OFFSET: Vector2 = Vector2(7.0, 9.0)
const OUTER_RADIUS: float = 47.0
const OVAL_HEIGHT_RATIO: float = 0.42
const LAYER_COUNT: int = 18
const SHADOW_COLOR: Color = Color(0.0, 0.035, 0.10, 1.0)

@onready var _hylas: HylasController = get_parent() as HylasController
@onready var _old_shadow: Sprite2D = _hylas.get_node_or_null("HylasShadow") as Sprite2D


func _ready() -> void:
	process_priority = 200
	z_index = -2
	show_behind_parent = true
	position = SHADOW_OFFSET
	queue_redraw()


func _process(_delta: float) -> void:
	# HylasController updates this legacy Sprite2D while changing frames.
	# Keep it disabled so only the drawn oval is visible.
	if _old_shadow != null:
		_old_shadow.visible = false


func _draw() -> void:
	# Large, faint rings first; then progressively denser inner rings.
	# This gives a broad 20px-style feather without any hard character outline.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, OVAL_HEIGHT_RATIO))
	for layer_index: int in range(LAYER_COUNT):
		var progress: float = float(layer_index) / float(LAYER_COUNT - 1)
		var radius: float = lerpf(OUTER_RADIUS, 9.0, progress)
		var alpha: float = lerpf(0.0015, 0.010, progress * progress)
		draw_circle(Vector2.ZERO, radius, Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)