class_name CotcEffectCountdownOverlay
extends Control

const FRAME_PATHS: Array[String] = [
	"res://assets/ui/hourglass/frame-001-frame-001.png",
	"res://assets/ui/hourglass/frame-001-frame-002.png",
	"res://assets/ui/hourglass/frame-001-frame-003.png",
	"res://assets/ui/hourglass/frame-001-frame-004.png",
	"res://assets/ui/hourglass/frame-001-frame-005.png",
	"res://assets/ui/hourglass/frame-001-frame-006.png",
	"res://assets/ui/hourglass/frame-001-frame-007.png",
	"res://assets/ui/hourglass/frame-001-frame-008.png",
	"res://assets/ui/hourglass/frame-001-frame-009.png",
	"res://assets/ui/hourglass/frame-001-frame-010.png",
	"res://assets/ui/hourglass/frame-001-frame-011.png",
	"res://assets/ui/hourglass/frame-001-frame-012.png",
	"res://assets/ui/hourglass/frame-001-frame-013.png",
	"res://assets/ui/hourglass/frame-001-frame-014.png",
	"res://assets/ui/hourglass/frame-001-frame-015.png",
	"res://assets/ui/hourglass/frame-001-frame-016.png",
]

@onready var _shadow: TextureRect = %HourglassShadow
@onready var _hourglass: TextureRect = %Hourglass

var _frames: Array[Texture2D] = []
var _last_frame_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_frames()
	clear_countdown()


func set_countdown(remaining_seconds: float, total_seconds: float) -> void:
	if total_seconds <= 0.0 or remaining_seconds <= 0.0 or _frames.is_empty():
		clear_countdown()
		return
	var elapsed_ratio: float = clampf(
		1.0 - remaining_seconds / total_seconds,
		0.0,
		0.999999,
	)
	var frame_index: int = clampi(
		int(floor(elapsed_ratio * float(_frames.size()))),
		0,
		_frames.size() - 1,
	)
	if frame_index != _last_frame_index:
		_last_frame_index = frame_index
		_hourglass.texture = _frames[frame_index]
		_shadow.texture = _frames[frame_index]
	show()


func clear_countdown() -> void:
	_last_frame_index = -1
	hide()


func get_frame_index() -> int:
	return _last_frame_index


func _load_frames() -> void:
	_frames.clear()
	for path: String in FRAME_PATHS:
		if not ResourceLoader.exists(path, "Texture2D"):
			push_warning("Missing hourglass countdown frame: %s" % path)
			continue
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture != null:
			_frames.append(texture)
	if _frames.size() != FRAME_PATHS.size():
		push_warning(
			"Hourglass countdown loaded %d of %d frames."
			% [_frames.size(), FRAME_PATHS.size()]
		)
