extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller_intro.gd"

## The positions visible in cuttlefish_tutorial_controller.tscn are the actual
## runtime layout. Drag Cuttlefish relative to HylasEditorAnchor, and drag or
## resize HintAnchor directly. These authored values are cached before runtime
## movement begins and are not replaced when tutorial text changes page.

@onready var _hylas_editor_anchor: Marker2D = %HylasEditorAnchor

var _authored_hover_offset: Vector2 = Vector2(135.0, -35.0)
var _authored_hint_screen_offset: Vector2 = Vector2(-75.0, -85.0)


func _ready() -> void:
	_capture_authored_editor_layout()
	super._ready()


func _get_hover_target() -> Vector2:
	if not is_instance_valid(_hylas):
		return _cuttlefish.global_position
	var world_rect: Rect2 = _get_visible_world_rect()
	var bob_offset: float = sin(_bob_time * TAU * hover_bob_frequency) * hover_bob_amplitude
	var target: Vector2 = _hylas.global_position + _authored_hover_offset
	target.y += bob_offset

	var minimum_x: float = world_rect.position.x + world_screen_margin
	var maximum_x: float = maxf(minimum_x, world_rect.end.x - world_screen_margin)
	var minimum_y: float = world_rect.position.y + world_screen_margin
	var maximum_y: float = maxf(minimum_y, world_rect.end.y - world_screen_margin)
	target.x = clampf(target.x, minimum_x, maximum_x)
	target.y = clampf(target.y, minimum_y, maximum_y)
	return target


func _update_hint_anchor_position() -> void:
	if _ink_position_locked:
		return
	if not _cuttlefish.visible:
		return
	_update_hint_anchor_pivot()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cuttlefish_screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	var desired_center: Vector2 = cuttlefish_screen_position + _authored_hint_screen_offset
	var scaled_half_size: Vector2 = _hint_anchor.size * _hint_anchor.scale * 0.5
	var minimum_center: Vector2 = Vector2.ONE * hint_screen_margin + scaled_half_size
	var maximum_center: Vector2 = (
		viewport_size - Vector2.ONE * hint_screen_margin - scaled_half_size
	)
	maximum_center.x = maxf(maximum_center.x, minimum_center.x)
	maximum_center.y = maxf(maximum_center.y, minimum_center.y)
	desired_center.x = clampf(desired_center.x, minimum_center.x, maximum_center.x)
	desired_center.y = clampf(desired_center.y, minimum_center.y, maximum_center.y)
	_hint_anchor.position = desired_center - _hint_anchor.size * 0.5
	_sync_hint_text_layout()


func _capture_authored_editor_layout() -> void:
	if is_instance_valid(_hylas_editor_anchor) and is_instance_valid(_cuttlefish):
		_authored_hover_offset = _cuttlefish.position - _hylas_editor_anchor.position
		hover_horizontal_offset = absf(_authored_hover_offset.x)
		hover_vertical_offset = -_authored_hover_offset.y

	if is_instance_valid(_hint_anchor) and is_instance_valid(_cuttlefish):
		var hint_center: Vector2 = _hint_anchor.position + _hint_anchor.size * 0.5
		_authored_hint_screen_offset = hint_center - _cuttlefish.position
		hint_screen_horizontal_offset = -_authored_hint_screen_offset.x
		hint_screen_vertical_offset = _authored_hint_screen_offset.y


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("authored_hover_offset=%s" % str(_authored_hover_offset))
	lines.append("authored_hint_offset=%s" % str(_authored_hint_screen_offset))
	return lines
