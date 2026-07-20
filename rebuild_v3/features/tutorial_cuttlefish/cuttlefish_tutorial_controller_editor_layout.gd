extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller_intro.gd"

## The visible layout in cuttlefish_tutorial_controller.tscn is the runtime layout.
## HylasEditorAnchor represents Hylas in the editor preview. Drag Cuttlefish
## relative to that marker to set where Lykos hovers.
## Drag or resize HintAnchor directly to set the exact on-screen ink/video/text
## rectangle. Runtime no longer recentres or clamps that rectangle around Hylas.

@onready var _hylas_editor_anchor: Marker2D = %HylasEditorAnchor

var _authored_hover_offset: Vector2 = Vector2(135.0, -35.0)
var _authored_hint_position: Vector2 = Vector2(535.0, 70.0)
var _authored_hint_size: Vector2 = Vector2(900.0, 380.0)


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
	if not is_instance_valid(_hint_anchor):
		return

	_hint_anchor.position = _authored_hint_position
	_hint_anchor.size = _authored_hint_size
	_update_hint_anchor_pivot()
	_sync_hint_text_layout()


func _capture_authored_editor_layout() -> void:
	var authored_hylas_position: Vector2 = Vector2.ZERO
	if is_instance_valid(_hylas_editor_anchor):
		authored_hylas_position = _hylas_editor_anchor.global_position

	var authored_lykos_position: Vector2 = _cuttlefish.global_position
	if is_instance_valid(_sprite):
		authored_lykos_position = _sprite.global_position

	_authored_hover_offset = authored_lykos_position - authored_hylas_position
	hover_horizontal_offset = absf(_authored_hover_offset.x)
	hover_vertical_offset = -_authored_hover_offset.y

	if is_instance_valid(_hint_anchor):
		_authored_hint_position = _hint_anchor.position
		_authored_hint_size = _hint_anchor.size

	# A direct child-sprite drag is converted into the authored hover offset, so
	# the runtime sprite can remain centred on the moving Cuttlefish parent.
	if is_instance_valid(_sprite):
		_sprite.position = Vector2.ZERO


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("authored_hover_offset=%s" % str(_authored_hover_offset))
	lines.append("authored_hint_position=%s" % str(_authored_hint_position))
	lines.append("authored_hint_size=%s" % str(_authored_hint_size))
	return lines
