class_name TailBubbleBurst
extends VideoStreamPlayer
## One-shot additive burst positioned over Hylas's tail while swimming.

var _effect_size: Vector2 = Vector2(310.0, 310.0)
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
	_apply_layout()
	finished.connect(_on_finished)
	hide()


func configure(tuning: PrototypeTuning) -> void:
	_effect_size = Vector2(tuning.tail_burst_size, tuning.tail_burst_size)
	_right_facing_tail_center = Vector2(-tuning.tail_burst_back_offset, tuning.tail_burst_offset_y)
	_left_facing_tail_center = Vector2(tuning.tail_burst_back_offset, tuning.tail_burst_offset_y)
	_apply_layout()


func play_at_tail(facing_left: bool, sprite_rotation: float = 0.0) -> void:
	if stream == null:
		return

	var tail_center: Vector2 = _left_facing_tail_center if facing_left else _right_facing_tail_center
	var rotated_tail_center: Vector2 = tail_center.rotated(sprite_rotation)
	position = rotated_tail_center - (_effect_size * 0.5)
	show()
	stop()
	play()


func _apply_layout() -> void:
	size = _effect_size


func _on_finished() -> void:
	hide()
