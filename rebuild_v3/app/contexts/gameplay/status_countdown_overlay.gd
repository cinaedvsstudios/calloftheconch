class_name CotcStatusCountdownOverlay
extends Control

const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/hourglass/frame-001-frame-001.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-002.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-003.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-004.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-005.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-006.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-007.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-008.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-009.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-010.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-011.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-012.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-013.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-014.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-015.png"),
	preload("res://assets/ui/hourglass/frame-001-frame-016.png"),
]

@onready var _shadow: TextureRect = %Shadow
@onready var _hourglass: TextureRect = %Hourglass

var _active_item_id: StringName = &""
var _remaining_seconds: float = 0.0
var _duration_seconds: float = 0.0
var _frame_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_countdown()


func set_countdown(
		item_id: StringName,
		remaining_seconds: float,
		duration_seconds: float,
	) -> void:
	if String(item_id).is_empty() or remaining_seconds <= 0.0 or duration_seconds <= 0.0:
		clear_countdown()
		return

	_active_item_id = item_id
	_remaining_seconds = clampf(remaining_seconds, 0.0, duration_seconds)
	_duration_seconds = maxf(duration_seconds, 0.001)
	var elapsed_ratio: float = clampf(
		(_duration_seconds - _remaining_seconds) / _duration_seconds,
		0.0,
		0.999999,
	)
	var next_frame_index: int = clampi(
		floori(elapsed_ratio * float(FRAME_TEXTURES.size())),
		0,
		FRAME_TEXTURES.size() - 1,
	)
	if next_frame_index != _frame_index:
		_frame_index = next_frame_index
		var frame_texture: Texture2D = FRAME_TEXTURES[_frame_index]
		_shadow.texture = frame_texture
		_hourglass.texture = frame_texture
	show()


func clear_countdown() -> void:
	_active_item_id = &""
	_remaining_seconds = 0.0
	_duration_seconds = 0.0
	_frame_index = -1
	hide()


func is_counting_down() -> bool:
	return visible and _remaining_seconds > 0.0


func get_active_item_id() -> StringName:
	return _active_item_id


func get_debug_lines() -> Array[String]:
	return [
		"[StatusCountdownOverlay]",
		"visible=%s" % str(visible),
		"item_id=%s" % String(_active_item_id),
		"remaining=%.3f" % _remaining_seconds,
		"duration=%.3f" % _duration_seconds,
		"frame=%d" % _frame_index,
	]
