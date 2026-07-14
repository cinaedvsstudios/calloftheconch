@tool
extends Node2D

@export_category("Editor Preview")
@export var show_world_bounds: bool = true
@export var show_waterline: bool = true
@export var show_city_gate: bool = true
@export var show_spawn_points: bool = true


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var level: Node2D = get_parent() as Node2D
	if level == null:
		return
	var top_left: Marker2D = level.get_node_or_null("WorldTopLeft") as Marker2D
	var bottom_right: Marker2D = level.get_node_or_null("WorldBottomRight") as Marker2D
	var waterline: Marker2D = level.get_node_or_null("WaterlineMarker") as Marker2D
	var hylas_start: Marker2D = level.get_node_or_null("HylasStart") as Marker2D

	if show_world_bounds and top_left != null and bottom_right != null:
		var world_rect: Rect2 = Rect2(top_left.position, bottom_right.position - top_left.position)
		draw_rect(world_rect, Color(0.18, 0.88, 1.0, 0.03), true)
		draw_rect(world_rect, Color(0.18, 0.88, 1.0, 0.72), false, 8.0)
		_draw_label(world_rect.position + Vector2(20.0, 36.0), "PLAYABLE WORLD BOUNDS", Color(0.18, 0.88, 1.0, 1.0), 24)

	if show_waterline and waterline != null and top_left != null and bottom_right != null:
		draw_line(
			Vector2(top_left.position.x, waterline.position.y),
			Vector2(bottom_right.position.x, waterline.position.y),
			Color(0.25, 1.0, 0.95, 0.80),
			6.0,
		)
		_draw_label(waterline.position + Vector2(20.0, -18.0), "WATERLINE", Color(0.25, 1.0, 0.95, 1.0), 22)

	if show_spawn_points and hylas_start != null:
		_draw_marker(hylas_start.position, "HYLAS START", Color(0.25, 1.0, 0.45, 1.0))
	var whale: Node2D = level.get_node_or_null("WhaleTravel") as Node2D
	if show_spawn_points and whale != null:
		_draw_marker(whale.position, "WHALE CHECKPOINT", Color(0.72, 0.52, 1.0, 1.0))

	if show_city_gate:
		_draw_city_gate(level)


func _draw_city_gate(level: Node2D) -> void:
	var city_art: Sprite2D = level.get_node_or_null("Citymain") as Sprite2D
	if city_art == null or city_art.texture == null:
		return
	var texture_size: Vector2 = city_art.texture.get_size()
	var texture_offset: Vector2 = level.get("city_gate_texture_offset")
	var gate_position: Vector2 = city_art.position + Vector2(
		texture_size.x * city_art.scale.x * texture_offset.x,
		texture_size.y * city_art.scale.y * texture_offset.y,
	)
	var radius: float = float(level.get("city_gate_interaction_radius"))
	var return_offset: Vector2 = level.get("city_gate_return_offset")
	var return_position: Vector2 = gate_position + return_offset
	draw_circle(gate_position, radius, Color(1.0, 0.66, 0.12, 0.05))
	draw_arc(gate_position, radius, 0.0, TAU, 96, Color(1.0, 0.66, 0.12, 0.92), 8.0)
	_draw_marker(gate_position, "CITY GATE INTERACTION", Color(1.0, 0.66, 0.12, 1.0))
	draw_line(gate_position, return_position, Color(1.0, 0.28, 0.65, 0.82), 5.0)
	_draw_marker(return_position, "CITY RETURN POSITION", Color(1.0, 0.28, 0.65, 1.0))


func _draw_marker(position_value: Vector2, text_value: String, color_value: Color) -> void:
	draw_circle(position_value, 14.0, color_value)
	draw_line(position_value - Vector2(34.0, 0.0), position_value + Vector2(34.0, 0.0), color_value, 5.0)
	draw_line(position_value - Vector2(0.0, 34.0), position_value + Vector2(0.0, 34.0), color_value, 5.0)
	_draw_label(position_value + Vector2(42.0, -20.0), text_value, color_value, 22)


func _draw_label(position_value: Vector2, text_value: String, color_value: Color, font_size: int) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position_value,
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color_value,
	)
