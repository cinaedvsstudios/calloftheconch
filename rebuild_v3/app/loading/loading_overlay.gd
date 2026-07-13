class_name CotcLoadingOverlay
extends CanvasLayer

## Root-owned loading presentation used during save loads and context transitions.
## Missing icon frames degrade to the animated text instead of blocking startup.

const DEFAULT_FRAME_PATHS: Array[String] = [
	"res://assets/ui/load01.webp",
	"res://assets/ui/load02.webp",
	"res://assets/ui/load03.webp",
	"res://assets/ui/load04.webp",
	"res://assets/ui/load05.webp",
	"res://assets/ui/load06.webp",
	"res://assets/ui/load07.webp",
]
const ICON_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 5]
const DOT_SEQUENCE: Array[int] = [0, 1, 2, 3, 2, 1]

@export_range(0.05, 2.0, 0.05) var frame_interval_seconds: float = 0.20
@export_range(0.05, 2.0, 0.05) var dots_interval_seconds: float = 0.40

@onready var _icon: TextureRect = %LoadingIcon
@onready var _label: Label = %LoadingLabel

var _frames: Array[Texture2D] = []
var _icon_sequence_index: int = 0
var _dot_sequence_index: int = 0
var _frame_elapsed: float = 0.0
var _dots_elapsed: float = 0.0
var _base_text: String = "LOADING"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_default_frames()
	hide_loading()


func _process(delta: float) -> void:
	_frame_elapsed += delta
	_dots_elapsed += delta

	while _frame_elapsed >= frame_interval_seconds:
		_frame_elapsed -= frame_interval_seconds
		_icon_sequence_index = (_icon_sequence_index + 1) % ICON_SEQUENCE.size()
		_update_icon()

	while _dots_elapsed >= dots_interval_seconds:
		_dots_elapsed -= dots_interval_seconds
		_dot_sequence_index = (_dot_sequence_index + 1) % DOT_SEQUENCE.size()
		_update_label()


func show_loading(base_text: String = "LOADING") -> void:
	_base_text = base_text.strip_edges()
	if _base_text.is_empty():
		_base_text = "LOADING"
	_icon_sequence_index = 0
	_dot_sequence_index = 0
	_frame_elapsed = 0.0
	_dots_elapsed = 0.0
	_update_icon()
	_update_label()
	visible = true
	set_process(true)


func hide_loading() -> void:
	set_process(false)
	visible = false


func is_loading_visible() -> bool:
	return visible


func _load_default_frames() -> void:
	_frames.clear()
	for path: String in DEFAULT_FRAME_PATHS:
		if not ResourceLoader.exists(path, "Texture2D"):
			continue
		var loaded_resource: Resource = ResourceLoader.load(path, "Texture2D")
		var texture: Texture2D = loaded_resource as Texture2D
		if texture != null:
			_frames.append(texture)
	_icon.visible = not _frames.is_empty()
	if _frames.size() != DEFAULT_FRAME_PATHS.size():
		push_warning(
			"Loading overlay found %d of %d icon frames in assets/ui; animated text will still work."
			% [_frames.size(), DEFAULT_FRAME_PATHS.size()]
		)


func _update_icon() -> void:
	if _frames.is_empty():
		_icon.visible = false
		return
	_icon.visible = true
	var requested_frame_index: int = ICON_SEQUENCE[_icon_sequence_index]
	var resolved_frame_index: int = mini(requested_frame_index, _frames.size() - 1)
	_icon.texture = _frames[resolved_frame_index]


func _update_label() -> void:
	var dot_count: int = DOT_SEQUENCE[_dot_sequence_index]
	_label.text = _base_text + ".".repeat(dot_count)


func get_debug_lines() -> Array[String]:
	return [
		"[LoadingOverlay]",
		"visible=%s" % str(visible),
		"loaded_frames=%d/%d" % [_frames.size(), DEFAULT_FRAME_PATHS.size()],
		"icon_sequence_index=%d" % _icon_sequence_index,
		"dot_sequence_index=%d" % _dot_sequence_index,
	]
