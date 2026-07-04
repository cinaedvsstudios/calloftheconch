class_name TailBubbleBurst
extends VideoStreamPlayer
## One-shot additive burst positioned behind Hylas's tail while swimming, bursting or tail-flipping.

var _base_effect_size: Vector2 = Vector2(310.0, 310.0)
var _right_facing_tail_center: Vector2 = Vector2(-120.0, 15.0)
var _left_facing_tail_center: Vector2 = Vector2(120.0, 15.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream = PrototypeAssets.load_video(PrototypeAssets.TAIL_BURST_VIDEO_CANDIDATES)
	if stream == null:
		hide()
		return

	var additive_material: CanvasItemMaterial = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	loop = false
	expand = true
	_apply_layout(_base_effect_size)
	finished.connect(_on_finished)
	hide()


func configure(tuning: PrototypeTuning) -> void:
	_base_effect_size = Vector2(tuning.tail_burst_size, tuning.tail_burst_size)
	_right_facing_tail_center = Vector2(-tuning.tail_burst_back_offset, tuning.tail_burst_offset_y)
	_left_facing_tail_center = Vector2(tuning.tail_burst_back_offset, tuning.tail_burst_offset_y)
	_apply_layout(_base_effect_size)


func play_at_tail(facing_left: bool, sprite_rotation: float = 0.0, size_multiplier: float = 1.0) -> void:
	if stream == null:
		return

	var effect_size: Vector2 = _base_effect_size * maxf(0.10, size_multiplier)
	var tail_center: Vector2 = _left_facing_tail_center if facing_left else _right_facing_tail_center
	var rotated_tail_center: Vector2 = tail_center.rotated(sprite_rotation)
	_apply_layout(effect_size)
	position = rotated_tail_center - (effect_size * 0.5)
	show()
	stop()
	play()


func _apply_layout(effect_size: Vector2) -> void:
	size = effect_size


func _on_finished() -> void:
	hide()
