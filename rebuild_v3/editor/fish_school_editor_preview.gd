@tool
extends Node2D

@export_category("Editor Preview")
@export var show_patrol_area: bool = true
@export var show_home_marker: bool = true
@export var show_label: bool = true


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_refresh_preview()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_preview()
	queue_redraw()


func _refresh_preview() -> void:
	var school: Node2D = get_parent() as Node2D
	if school == null:
		return
	var sprite: AnimatedSprite2D = school.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return
	var display_height: float = float(school.get("display_height"))
	var multiplier: float = float(school.get("display_scale_multiplier"))
	var scale_factor: float = display_height * multiplier / maxf(1.0, float(texture.get_height()))
	sprite.scale = Vector2.ONE * scale_factor


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var school: Node2D = get_parent() as Node2D
	if school == null:
		return
	var half_extents: Vector2 = school.get("patrol_half_extents")
	if show_patrol_area:
		var patrol_rect: Rect2 = Rect2(-half_extents, half_extents * 2.0)
		draw_rect(patrol_rect, Color(0.15, 0.85, 1.0, 0.07), true)
		draw_rect(patrol_rect, Color(0.15, 0.85, 1.0, 0.82), false, 3.0)
	if show_home_marker:
		draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), Color(0.25, 1.0, 0.45, 0.95), 2.0)
		draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), Color(0.25, 1.0, 0.45, 0.95), 2.0)
	if show_label:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(22.0, -14.0),
			"FISH HOME / PATROL AREA",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			Color(0.25, 1.0, 0.45, 1.0),
		)
