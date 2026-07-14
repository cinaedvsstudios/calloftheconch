@tool
extends Node2D

const HYLAS_CONCH_TEXTURE: Texture2D = preload(
	"res://assets/characters/hylas-conch1_05.webp"
)

@export_category("Editor Preview")
@export var show_hylas_reference: bool = true
@export var hylas_reference_offset: Vector2 = Vector2(-105.0, 0.0)
@export_range(80.0, 400.0, 1.0) var hylas_reference_height: float = 205.0
@export_range(0.0, 1.0, 0.01) var sonar_preview_progress: float = 0.16
@export var show_video_bounds: bool = true
@export var show_labels: bool = true


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_refresh_preview_nodes()
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_preview_nodes()
	queue_redraw()


func _refresh_preview_nodes() -> void:
	var pulse: Node2D = get_parent() as Node2D
	if pulse == null:
		return
	var sonar: Sprite2D = pulse.get_node_or_null("SonarArc") as Sprite2D
	if sonar != null and sonar.texture != null:
		var start_diameter: float = float(pulse.get("start_diameter"))
		var pulse_range: float = float(pulse.get("pulse_range"))
		var diameter: float = lerpf(
			start_diameter,
			pulse_range,
			clampf(sonar_preview_progress, 0.0, 1.0),
		)
		var texture_size: Vector2 = sonar.texture.get_size()
		var reference_diameter: float = maxf(1.0, maxf(texture_size.x, texture_size.y))
		sonar.scale = Vector2.ONE * (diameter / reference_diameter)
		sonar.modulate = Color(1.0, 1.0, 1.0, 0.70)
		sonar.visible = true
	var flash: VideoStreamPlayer = pulse.get_node_or_null("OriginFlash") as VideoStreamPlayer
	if flash != null:
		flash.stop()
		flash.visible = true


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var pulse: Node2D = get_parent() as Node2D
	if pulse == null:
		return
	var sonar: Sprite2D = pulse.get_node_or_null("SonarArc") as Sprite2D
	var flash: VideoStreamPlayer = pulse.get_node_or_null("OriginFlash") as VideoStreamPlayer
	if show_hylas_reference:
		var hylas_size: Vector2 = HYLAS_CONCH_TEXTURE.get_size()
		var hylas_scale: float = hylas_reference_height / maxf(1.0, hylas_size.y)
		var hylas_draw_size: Vector2 = hylas_size * hylas_scale
		draw_texture_rect(
			HYLAS_CONCH_TEXTURE,
			Rect2(hylas_reference_offset - hylas_draw_size * 0.5, hylas_draw_size),
			false,
		)
		if show_labels:
			_draw_label(hylas_reference_offset + Vector2(-40.0, -hylas_draw_size.y * 0.55), "HYLAS CONCH FRAME", Color(0.35, 1.0, 0.55, 1.0))

	if sonar != null and sonar.texture != null:
		var diameter: float = maxf(sonar.scale.x, sonar.scale.y) * maxf(
			sonar.texture.get_size().x,
			sonar.texture.get_size().y,
		)
		draw_arc(sonar.position, diameter * 0.5, -0.40, 0.40, 32, Color(0.18, 0.78, 1.0, 0.95), 2.0)
		if show_labels:
			_draw_label(sonar.position + Vector2(12.0, 22.0), "SONAR WAVE — DRAG SONARARC", Color(0.18, 0.78, 1.0, 1.0))

	if show_video_bounds and flash != null:
		_draw_flash_bounds(flash)

	draw_circle(Vector2.ZERO, 7.0, Color(0.25, 1.0, 0.55, 1.0))
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), Color(0.25, 1.0, 0.55, 0.95), 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), Color(0.25, 1.0, 0.55, 0.95), 2.0)
	if show_labels:
		_draw_label(Vector2(12.0, -18.0), "PULSE ORIGIN", Color(0.25, 1.0, 0.55, 1.0))


func _draw_flash_bounds(flash: VideoStreamPlayer) -> void:
	var control_position: Vector2 = Vector2(flash.offset_left, flash.offset_top)
	var control_size: Vector2 = Vector2(
		flash.offset_right - flash.offset_left,
		flash.offset_bottom - flash.offset_top,
	)
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2(control_size.x, 0.0),
		control_size,
		Vector2(0.0, control_size.y),
	])
	for index: int in range(corners.size()):
		var local_point: Vector2 = corners[index] - flash.pivot_offset
		local_point *= flash.scale
		local_point = local_point.rotated(flash.rotation)
		corners[index] = control_position + flash.pivot_offset + local_point
	var outline: PackedVector2Array = PackedVector2Array(corners)
	outline.append(corners[0])
	draw_colored_polygon(corners, Color(1.0, 0.45, 0.12, 0.08))
	draw_polyline(outline, Color(1.0, 0.45, 0.12, 0.95), 3.0)
	if show_labels:
		_draw_label(corners[0] + Vector2(8.0, -8.0), "ECHOPULSE VIDEO — DRAG ORIGINFLASH", Color(1.0, 0.55, 0.2, 1.0))


func _draw_label(position_value: Vector2, text_value: String, color_value: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position_value,
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		color_value,
	)
