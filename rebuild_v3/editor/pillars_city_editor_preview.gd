@tool
extends Control

const HYLAS_TEXTURE: Texture2D = preload("res://assets/characters/hylas-idle_01.webp")

@export_category("Editor Preview")
@export var show_hylas_spawn: bool = true
@export var show_doorway_regions: bool = true
@export var show_doorway_radius: bool = true
@export var show_labels: bool = true


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_refresh_preview()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_preview()
	queue_redraw()


func _refresh_preview() -> void:
	var city: CanvasLayer = get_parent() as CanvasLayer
	if city == null:
		return
	var background: TextureRect = city.get_node_or_null("CityBackground") as TextureRect
	if background != null:
		var texture_value: Variant = city.get("city_background_texture")
		if texture_value is Texture2D:
			background.texture = texture_value as Texture2D
	var bubble_overlay: CanvasItem = city.get_node_or_null("BubbleOverlay") as CanvasItem
	if bubble_overlay != null:
		bubble_overlay.visible = false
	var location_overlay: CanvasItem = city.get_node_or_null("LocationOverlay") as CanvasItem
	if location_overlay != null:
		location_overlay.visible = false
	var interaction_hint: Label = city.get_node_or_null("InteractionHint") as Label
	if interaction_hint != null:
		interaction_hint.visible = true
		interaction_hint.text = "EDITOR PREVIEW — SWIM TO A DOORWAY AND PRESS SPACE"


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var city: CanvasLayer = get_parent() as CanvasLayer
	if city == null:
		return
	var hotspot_paths: Array[String] = [
		"Hotspots/ExitGateButton",
		"Hotspots/MenuBuildingButton",
		"Hotspots/AgoraButton",
		"Hotspots/OracleButton",
	]
	var labels: Array[String] = ["EXIT", "MENU", "AGORA", "ORACLE"]
	var radius: float = float(city.get("doorway_interaction_radius"))
	for index: int in range(hotspot_paths.size()):
		var button: Button = city.get_node_or_null(hotspot_paths[index]) as Button
		if button == null:
			continue
		var rect: Rect2 = Rect2(button.position, button.size)
		var center: Vector2 = rect.get_center()
		if show_doorway_regions:
			draw_rect(rect, Color(0.15, 0.95, 1.0, 0.10), true)
			draw_rect(rect, Color(0.20, 0.95, 1.0, 0.95), false, 3.0)
		if show_doorway_radius:
			draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 0.72, 0.15, 0.70), 2.0)
			draw_circle(center, 5.0, Color(1.0, 0.72, 0.15, 0.95))
		if show_labels:
			_draw_label(center + Vector2(10.0, -12.0), labels[index], Color(0.25, 1.0, 1.0, 1.0))

	if show_hylas_spawn:
		var preview_size: Vector2 = size
		if preview_size.x <= 0.0 or preview_size.y <= 0.0:
			preview_size = get_viewport_rect().size
		var spawn_ratio: Vector2 = city.get("hylas_spawn_ratio")
		var spawn_position: Vector2 = Vector2(
			preview_size.x * spawn_ratio.x,
			preview_size.y * spawn_ratio.y,
		)
		var display_height: float = float(city.get("hylas_display_height"))
		var texture_size: Vector2 = HYLAS_TEXTURE.get_size()
		var scale_factor: float = display_height / maxf(1.0, texture_size.y)
		var draw_size: Vector2 = texture_size * scale_factor
		draw_texture_rect(HYLAS_TEXTURE, Rect2(spawn_position - draw_size * 0.5, draw_size), false)
		draw_line(spawn_position - Vector2(14.0, 0.0), spawn_position + Vector2(14.0, 0.0), Color(0.3, 1.0, 0.45, 1.0), 2.0)
		draw_line(spawn_position - Vector2(0.0, 14.0), spawn_position + Vector2(0.0, 14.0), Color(0.3, 1.0, 0.45, 1.0), 2.0)
		if show_labels:
			_draw_label(spawn_position + Vector2(16.0, -16.0), "HYLAS SPAWN", Color(0.3, 1.0, 0.45, 1.0))


func _draw_label(position_value: Vector2, text_value: String, color_value: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position_value,
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		color_value,
	)
