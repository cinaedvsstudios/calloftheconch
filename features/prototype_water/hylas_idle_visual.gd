class_name HylasIdleVisual
extends Node
## Applies the dedicated idle frame set after the movement controller has entered its idle state.
## It deliberately leaves every active action (swim, burst, conch, flip, stop, jump) to HylasController.

const IDLE_FRAME_DURATION: float = 0.28

var _hylas: HylasController
var _sprite: Sprite2D
var _shadow: Sprite2D
var _frames: Array[Texture2D] = []
var _elapsed: float = 0.0
var _frame_index: int = 0
var _was_idle: bool = false


func _ready() -> void:
	_hylas = get_parent() as HylasController
	if _hylas == null:
		set_process(false)
		return
	_sprite = _hylas.get_node("Sprite") as Sprite2D
	_shadow = _hylas.get_node("HylasShadow") as Sprite2D
	_frames = PrototypeAssets.load_hylas_frames("hylas-idle")
	if _sprite == null or _shadow == null or _frames.is_empty():
		set_process(false)


func _process(delta: float) -> void:
	if _hylas == null or _hylas._animation_mode != &"idle":
		_was_idle = false
		return

	if not _was_idle:
		_was_idle = true
		_elapsed = 0.0
		_frame_index = 0
		_apply_frame()
		return

	_elapsed += delta
	if _elapsed < IDLE_FRAME_DURATION:
		_apply_frame()
		return

	_elapsed = 0.0
	_frame_index = (_frame_index + 1) % _frames.size()
	_apply_frame()


func _apply_frame() -> void:
	var texture: Texture2D = _frames[_frame_index]
	var scale_factor: float = _hylas._tuning.hylas_display_height / maxf(1.0, float(texture.get_height()))
	_sprite.texture = texture
	_sprite.flip_h = _hylas._facing_left
	_sprite.rotation = _hylas._visual_rotation
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_shadow.texture = texture
	_shadow.flip_h = _hylas._facing_left
	_shadow.rotation = _hylas._visual_rotation
	_shadow.scale = Vector2(
		scale_factor * _hylas._tuning.hylas_shadow_scale,
		scale_factor * _hylas._tuning.hylas_shadow_scale,
	)
	_hylas._apply_shadow_style()
