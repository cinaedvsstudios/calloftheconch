@tool
extends Node2D

const CONCH_PULSE_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/conch_pulse.tscn"
)

@export_category("Editor Preview")
@export var show_conch_alignment: bool = true
@export_range(0, 5, 1) var conch_preview_frame: int = 4
@export_range(0.0, 1.0, 0.01) var sonar_preview_progress: float = 0.16
@export var show_jump_arc: bool = true
@export var show_labels: bool = true

var _sonar_texture: Texture2D
var _sonar_local_position: Vector2 = Vector2.ZERO
var _start_diameter: float = 20.0
var _pulse_range: float = 700.0
var _flash_position: Vector2 = Vector2.ZERO
var _flash_size: Vector2 = Vector2.ZERO
var _flash_rotation: float = 0.0
var _flash_pivot: Vector2 = Vector2.ZERO
var _flash_scale: Vector2 = Vector2.ONE
var _metrics_loaded: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_load_effect_metrics()
	_update_hylas_pose()
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not _metrics_loaded:
		_load_effect_metrics()
	_update_hylas_pose()
	queue_redraw()


func _load_effect_metrics() -> void:
	var pulse_instance: Node = CONCH_PULSE_SCENE.instantiate()
	if pulse_instance == null:
		return
	_start_diameter = float(pulse_instance.get("start_diameter"))
	_pulse_range = float(pulse_instance.get("pulse_range"))
	var sonar: Sprite2D = pulse_instance.get_node_or_null("SonarArc") as Sprite2D
	if sonar != null:
		_sonar_texture = sonar.texture
		_sonar_local_position = sonar.position
	var flash: VideoStreamPlayer = pulse_instance.get_node_or_null("OriginFlash") as VideoStreamPlayer
	if flash != null:
		_flash_position = Vector2(flash.offset_left, flash.offset_top)
		_flash_size = Vector2(
			flash.offset_right - flash.offset_left,
			flash.offset_bottom - flash.offset_top,
		)
		_flash_rotation = flash.rotation
		_flash_pivot = flash.pivot_offset
		_flash_scale = flash.scale
	pulse_instance.free()
	_metrics_loaded = true


func _update_hylas_pose() -> void:
	var hylas: Node2D = get_parent() as Node2D
	if hylas == null:
		return
	var sprite: AnimatedSprite2D = hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(&"conch"):
		return
	var frame_count: int = sprite.sprite_frames.get_frame_count(&"conch")
	if frame_count <= 0:
		return
	sprite.animation = &"conch"
	sprite.frame = clampi(conch_preview_frame, 0, frame_count - 1)
	sprite.pause()
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"conch", sprite.frame)
	if frame_texture != null:
		var display_height: float = float(hylas.get("display_height"))
		var scale_factor: float = display_height / maxf(1.0, float(frame_texture.get_height()))
		sprite.scale = Vector2.ONE * scale_factor
	var shadow: CanvasItem = hylas.get_node_or_null("ShadowSprite") as CanvasItem
	if shadow != null:
		shadow.visible = false


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var hylas: Node2D = get_parent() as Node2D
	if hylas == null:
		return
	var origin_marker: Marker2D = hylas.get_node_or_null("ConchPulseOrigin") as Marker2D
	var pulse_origin: Vector2 = origin_marker.position if origin_marker != null else Vector2(105.0, 0.0)

	if show_conch_alignment:
		draw_line(Vector2.ZERO, pulse_origin, Color(0.2, 1.0, 0.55, 0.75), 2.0)
		draw_circle(pulse_origin, 7.0, Color(0.2, 1.0, 0.55, 0.95))
		_draw_sonar_preview(pulse_origin)
		_draw_flash_bounds(pulse_origin)
		if show_labels:
			_draw_label(pulse_origin + Vector2(12.0, -18.0), "CONCH PULSE ORIGIN", Color(0.2, 1.0, 0.55, 1.0))

	if show_jump_arc:
		_draw_jump_preview(hylas)


func _draw_sonar_preview(pulse_origin: Vector2) -> void:
	if _sonar_texture == null:
		return
	var progress: float = clampf(sonar_preview_progress, 0.0, 1.0)
	var diameter: float = lerpf(_start_diameter, _pulse_range, progress)
	var texture_size: Vector2 = _sonar_texture.get_size()
	var reference_diameter: float = maxf(1.0, maxf(texture_size.x, texture_size.y))
	var scale_factor: float = diameter / reference_diameter
	var draw_size: Vector2 = texture_size * scale_factor
	var center: Vector2 = pulse_origin + _sonar_local_position
	var rect: Rect2 = Rect2(center - draw_size * 0.5, draw_size)
	draw_texture_rect(_sonar_texture, rect, false, Color(1.0, 1.0, 1.0, 0.65))
	draw_arc(center, diameter * 0.5, -0.40, 0.40, 32, Color(0.18, 0.78, 1.0, 0.9), 2.0)
	if show_labels:
		_draw_label(center + Vector2(12.0, 22.0), "SONAR WAVE", Color(0.18, 0.78, 1.0, 1.0))


func _draw_flash_bounds(pulse_origin: Vector2) -> void:
	if _flash_size.x <= 0.0 or _flash_size.y <= 0.0:
		return
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2(_flash_size.x, 0.0),
		_flash_size,
		Vector2(0.0, _flash_size.y),
	])
	for index: int in range(corners.size()):
		var local_point: Vector2 = corners[index] - _flash_pivot
		local_point *= _flash_scale
		local_point = local_point.rotated(_flash_rotation)
		corners[index] = pulse_origin + _flash_position + _flash_pivot + local_point
	var outline: PackedVector2Array = PackedVector2Array(corners)
	outline.append(corners[0])
	draw_colored_polygon(corners, Color(1.0, 0.45, 0.12, 0.08))
	draw_polyline(outline, Color(1.0, 0.45, 0.12, 0.95), 3.0)
	if show_labels:
		_draw_label(corners[0] + Vector2(8.0, -8.0), "ECHOPULSE VIDEO BOUNDS", Color(1.0, 0.55, 0.2, 1.0))


func _draw_jump_preview(hylas: Node2D) -> void:
	var jump_distance: float = float(hylas.get("jump_forward_distance"))
	var jump_height: float = float(hylas.get("jump_arc_height"))
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(25):
		var progress: float = float(step) / 24.0
		points.append(Vector2(
			jump_distance * progress,
			40.0 * progress - sin(progress * PI) * jump_height,
		))
	draw_polyline(points, Color(1.0, 0.86, 0.25, 0.50), 2.0)
	draw_circle(points[points.size() - 1], 6.0, Color(1.0, 0.86, 0.25, 0.85))
	if show_labels:
		var midpoint_index: int = points.size() / 2
		_draw_label(points[midpoint_index] + Vector2(8.0, -8.0), "SURFACE JUMP ARC", Color(1.0, 0.86, 0.25, 0.9))


func _draw_label(position_value: Vector2, text_value: String, color_value: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position_value,
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		color_value,
	)
