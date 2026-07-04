class_name IdleVisualController
extends Node
## Applies the dedicated hylas-idle frames only while the main Hylas controller is in its idle state.
## Kept as a separate child controller so it cannot alter burst, conch, flip or jump input flow.

const IDLE_FRAME_DURATION: float = 0.34

@onready var _hylas: HylasController = get_parent() as HylasController
@onready var _sprite: Sprite2D = _hylas.get_node_or_null("Sprite") as Sprite2D
@onready var _shadow: Sprite2D = _hylas.get_node_or_null("HylasShadow") as Sprite2D

var _idle_frames: Array[Texture2D] = []
var _elapsed: float = 0.0
var _frame_index: int = -1


func _ready() -> void:
	process_priority = 100
	_idle_frames = PrototypeAssets.load_hylas_frames("hylas-idle")
	set_process(not _idle_frames.is_empty())


func _process(delta: float) -> void:
	if _idle_frames.is_empty() or _hylas == null or _sprite == null or _shadow == null:
		return
	if not bool(_hylas.get("_play_enabled")):
		_reset_animation()
		return
	if _hylas.get("_animation_mode") != &"idle":
		_reset_animation()
		return

	_elapsed += delta
	var next_index: int = floori(_elapsed / IDLE_FRAME_DURATION) % _idle_frames.size()
	if next_index == _frame_index:
		return
	_frame_index = next_index
	_apply_frame(_idle_frames[_frame_index])


func _reset_animation() -> void:
	_elapsed = 0.0
	_frame_index = -1


func _apply_frame(texture: Texture2D) -> void:
	var tuning: Variant = _hylas.get("_tuning")
	var display_height: float = 205.0
	var shadow_scale: float = 1.18
	if tuning != null:
		display_height = float(tuning.hylas_display_height)
		shadow_scale = float(tuning.hylas_shadow_scale)

	var scale_factor: float = display_height / maxf(1.0, float(texture.get_height()))
	var facing_left: bool = bool(_hylas.get("_facing_left"))
	var rotation_radians: float = float(_hylas.get("_visual_rotation"))

	_sprite.texture = texture
	_sprite.flip_h = facing_left
	_sprite.rotation = rotation_radians
	_sprite.scale = Vector2(scale_factor, scale_factor)

	_shadow.texture = texture
	_shadow.flip_h = facing_left
	_shadow.rotation = rotation_radians
	_shadow.scale = Vector2(scale_factor * shadow_scale, scale_factor * shadow_scale)
