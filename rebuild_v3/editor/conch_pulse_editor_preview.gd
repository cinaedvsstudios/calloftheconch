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
@export var preview_facing_left: bool = false
@export_range(-89.0, 89.0, 1.0) var preview_steering_degrees: float = 0.0
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

	var steering_rotation: float = deg_to_rad(preview_steering_degrees)
	var facing_direction: Vector2 = Vector2.LEFT if preview_facing_left else Vector2.RIGHT
	var pulse_direction: Vector2 = facing_direction.rotated(steering_rotation)

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
		sonar.rotation = pulse_direction.angle()
		sonar.modulate = Color(1.0, 1.0, 1.0, 0.70)
		sonar.visible = true

	var flash_pivot: Node2D = pulse.get_node_or_null("OriginFlashPivot") as Node2D
	if flash_pivot != null:
		var flash_scale: float = float(pulse.get("flash_scale"))
		var facing_sign: float = -1.0 if preview_facing_left else 1.0
		flash_pivot.rotation = steering_rotation
		flash_pivot.scale = Vector2(facing_sign * flash_scale, flash_scale)

	var flash: VideoStreamPlayer = pulse.get_node_or_null(
		"OriginFlashPivot/OriginFlashVisual/OriginFlash"
	) as VideoStreamPlayer
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
	var flash: VideoStreamPlayer = pulse.get_node_or_null(
		"OriginFlashPivot/OriginFlashVisual/OriginFlash"
	) as VideoStreamPlayer

	if show_hylas_reference:
		var hylas_size: Vector2 = HYLAS_CONCH_TEXTURE.get_size()
		var hylas_scale: float = hylas_reference_height / maxf(1.0, hylas_size.y)
		var facing_scale: float = -hylas_scale if preview_facing_left else hylas_scale
		draw_set_transform(
			hylas_reference_offset,
			deg_to_rad(preview_steering_degrees),
			Vector2(facing_scale, hylas_scale),
		)
		draw_texture_rect(
			HYLAS_CONCH_TEXTURE,
			Rect2(-hylas_size * 0.5, hylas_size),
			false,
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if show_labels:
			_draw_label(
				hylas_reference_offset + Vector2(-40.0, -hylas_reference_height * 0.55),
				"HYLAS CONCH FRAME",
				Color(0.35, 1.0, 0.55, 1.0),
			)

	if sonar != null and sonar.texture != null:
		var diameter: float = maxf(absf(sonar.scale.x), absf(sonar.scale.y)) * maxf(
			sonar.texture.get_size().x,
			sonar.texture.get_size().y,
		)
		var direction: Vector2 = Vector2.RIGHT.rotated(sonar.rotation)
		var arc_start: float = direction.angle() - 0.40
		var arc_end: float = direction.angle() + 0.40
		draw_arc(
			sonar.position,
			diameter * 0.5,
			arc_start,
			arc_end,
			32,
			Color(0.18, 0.78, 1.0, 0.95),
			2.0,
		)
		if show_labels:
			_draw_label(
				sonar.position + Vector2(12.0, 22.0),
				"SONAR WAVE — DRAG SONARARC",
				Color(0.18, 0.78, 1.0, 1.0),
			)

	if show_video_bounds and flash != null:
		_draw_flash_bounds(flash)

	draw_circle(Vector2.ZERO, 7.0, Color(0.25, 1.0, 0.55, 1.0))
	draw_line(
		Vector2(-18.0, 0.0),
		Vector2(18.0, 0.0),
		Color(0.25, 1.0, 0.55, 0.95),
		2.0,
	)
	draw_line(
		Vector2(0.0, -18.0),
		Vector2(0.0, 18.0),
		Color(0.25, 1.0, 0.55, 0.95),
		2.0,
	)
	if show_labels:
		_draw_label(
			Vector2(12.0, -18.0),
			"PULSE ORIGIN",
			Color(0.25, 1.0, 0.55, 1.0),
		)


func _draw_flash_bounds(flash: VideoStreamPlayer) -> void:
	var to_preview: Transform2D = get_global_transform().affine_inverse() * flash.get_global_transform()
	var control_size: Vector2 = flash.size
	var corners: PackedVector2Array = PackedVector2Array([
		to_preview * Vector2.ZERO,
		to_preview * Vector2(control_size.x, 0.0),
		to_preview * control_size,
		to_preview * Vector2(0.0, control_size.y),
	])
	var outline: PackedVector2Array = PackedVector2Array(corners)
	outline.append(corners[0])
	draw_colored_polygon(corners, Color(1.0, 0.45, 0.12, 0.08))
	draw_polyline(outline, Color(1.0, 0.45, 0.12, 0.95), 3.0)
	if show_labels:
		_draw_label(
			corners[0] + Vector2(8.0, -8.0),
			"ECHOPULSE VIDEO — DRAG ORIGINFLASHPIVOT",
			Color(1.0, 0.55, 0.2, 1.0),
		)


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
