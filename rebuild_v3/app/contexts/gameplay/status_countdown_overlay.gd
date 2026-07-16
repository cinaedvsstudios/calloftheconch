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
const MATI_TEXTURE: Texture2D = preload("res://assets/objects/ui_mati.png")
const MATI_COLUMNS: int = 3
const MATI_ROWS: int = 2
const MATI_FRAME_COUNT: int = 6

@onready var _hourglass: TextureRect = %Hourglass
var _crossfade: TextureRect
var _active_item_id: StringName = &""
var _remaining_seconds: float = 0.0
var _duration_seconds: float = 0.0
var _frame_index: int = -1
var _mati_mode: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossfade = TextureRect.new()
	_crossfade.name = "Crossfade"
	_crossfade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crossfade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crossfade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crossfade.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_crossfade)
	clear_countdown()

func set_countdown(item_id: StringName, remaining_seconds: float, duration_seconds: float) -> void:
	if String(item_id).is_empty() or remaining_seconds <= 0.0 or duration_seconds <= 0.0:
		clear_countdown()
		return
	_mati_mode = false
	_crossfade.hide()
	_hourglass.modulate = Color.WHITE
	_active_item_id = item_id
	_remaining_seconds = clampf(remaining_seconds, 0.0, duration_seconds)
	_duration_seconds = maxf(duration_seconds, 0.001)
	var elapsed_ratio: float = clampf((_duration_seconds - _remaining_seconds) / _duration_seconds, 0.0, 0.999999)
	var next_frame_index: int = clampi(floori(elapsed_ratio * float(FRAME_TEXTURES.size())), 0, FRAME_TEXTURES.size() - 1)
	if next_frame_index != _frame_index:
		_frame_index = next_frame_index
		var frame_texture: Texture2D = FRAME_TEXTURES[_frame_index]
		_hourglass.texture = frame_texture
	show()

func set_mati_progress(elapsed_seconds: float) -> void:
	_mati_mode = true
	_active_item_id = &"mati_amulet"
	_duration_seconds = 30.0
	_remaining_seconds = maxf(0.0, 30.0 - elapsed_seconds)
	_crossfade.show()
	var sequence_frame: float
	if elapsed_seconds < 5.0:
		sequence_frame = elapsed_seconds * 3.0
	elif elapsed_seconds < 25.0:
		sequence_frame = 15.0 + (elapsed_seconds - 5.0)
	else:
		sequence_frame = 35.0 + (elapsed_seconds - 25.0) * 3.0
	var current_index: int = floori(sequence_frame) % MATI_FRAME_COUNT
	var next_index: int = (current_index + 1) % MATI_FRAME_COUNT
	var blend: float = smoothstep(0.0, 1.0, sequence_frame - floor(sequence_frame))
	_hourglass.texture = _make_mati_frame(current_index)
	_crossfade.texture = _make_mati_frame(next_index)
	_hourglass.modulate = Color(1.0, 1.0, 1.0, 1.0 - blend)
	_crossfade.modulate = Color(1.0, 1.0, 1.0, blend)
	show()

func _make_mati_frame(frame_index: int) -> AtlasTexture:
	var texture_size: Vector2 = MATI_TEXTURE.get_size()
	var cell_size: Vector2 = Vector2(texture_size.x / MATI_COLUMNS, texture_size.y / MATI_ROWS)
	var column: int = frame_index % MATI_COLUMNS
	var row: int = frame_index / MATI_COLUMNS
	var atlas := AtlasTexture.new()
	atlas.atlas = MATI_TEXTURE
	atlas.region = Rect2(Vector2(column, row) * cell_size, cell_size)
	return atlas

func clear_countdown() -> void:
	_active_item_id = &""
	_remaining_seconds = 0.0
	_duration_seconds = 0.0
	_frame_index = -1
	_mati_mode = false
	if is_instance_valid(_crossfade):
		_crossfade.hide()
	_hourglass.modulate = Color.WHITE
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
		"mati_mode=%s" % str(_mati_mode),
	]
