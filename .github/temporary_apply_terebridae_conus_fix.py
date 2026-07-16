from pathlib import Path


def insert_after(path: str, needle: str, insertion: str, already: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if already in text:
        return
    index = text.find(needle)
    if index < 0:
        raise SystemExit(f"Missing insertion anchor in {path}: {needle!r}")
    index += len(needle)
    file_path.write_text(text[:index] + insertion + text[index:])


def replace_between(path: str, start: str, end: str, replacement: str, already: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if already in text:
        return
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"Missing start anchor in {path}: {start!r}")
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        raise SystemExit(f"Missing end anchor in {path}: {end!r}")
    file_path.write_text(text[:start_index] + replacement + text[end_index:])


controller = "rebuild_v3/app/contexts/gameplay/item_effect_controller.gd"
insert_after(
    controller,
    '\t\t\t"pulse_interval_scale": 0.48,\n',
    '\t\t\t"duration": 5.0,\n',
    '"duration": 5.0',
)

hylas = "scenes/characters/Hylas/hylas_equipment_input.gd"
insert_after(
    hylas,
    '@export_range(0.0, 180.0, 1.0) var conus_rope_hand_offset: float = 62.0\n',
    '@export_range(-120.0, 120.0, 1.0) var normal_conus_climb_sprite_perpendicular_offset: float = -24.0\n',
    "normal_conus_climb_sprite_perpendicular_offset",
)
insert_after(
    hylas,
    'var _conus_climb_previous_facing_left: bool = false\n',
    'var _conus_climb_sprite_base_position: Vector2 = Vector2.ZERO\n'
    'var _conus_climb_normal_sprite_scale: Vector2 = Vector2.ONE\n',
    "_conus_climb_sprite_base_position",
)
insert_after(
    hylas,
    '\t_normal_collision_layer = collision_layer\n',
    '\t_conus_climb_sprite_base_position = _animated_sprite.position\n'
    '\t_conus_climb_normal_sprite_scale = _animated_sprite.scale\n',
    '\t_conus_climb_sprite_base_position = _animated_sprite.position',
)

text = Path(hylas).read_text()
restore_line = '\t_animated_sprite.position = _conus_climb_sprite_base_position\n'
if restore_line not in text:
    target = '\t_special_velocity = Vector2.ZERO\n\t_set_visual_rotation(0.0)\n'
    if target not in text:
        raise SystemExit("Missing end-climb restoration anchor")
    text = text.replace(
        target,
        '\t_special_velocity = Vector2.ZERO\n' + restore_line + '\t_set_visual_rotation(0.0)\n',
        1,
    )
    Path(hylas).write_text(text)

input_function = '''func _input(event: InputEvent) -> void:
\tif _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
\t\treturn

\tvar key_event: InputEventKey = event as InputEventKey
\tif key_event != null and key_event.echo:
\t\treturn

\tif _conus_climb_active:
\t\tif event.is_action_pressed(&"conch", false, true) and _is_primary_item_a_binding(event):
\t\t\t_space_action_pressed_this_frame = false
\t\t\t_pending_conch_remaining = 0.0
\t\t\t_pending_interaction_remaining = 0.0
\t\t\tif is_instance_valid(_conus_climb_tether) and _conus_climb_tether.has_method(&"retract"):
\t\t\t\t_conus_climb_tether.call(&"retract")
\t\t\telse:
\t\t\t\tend_conus_wall_climb()
\t\t\tget_viewport().set_input_as_handled()
\t\treturn

\t# Exact matching is essential because Item A, Item B and Tail Flip can share
\t# the same base key while differing only by their modifiers.
\tif event.is_action_pressed(&"utility_item", false, true):
\t\t_utility_item_pressed_this_frame = true
\t\t_space_action_pressed_this_frame = false
\t\t_pending_interaction_remaining = 0.0
\t\t_pending_conch_remaining = 0.0
\t\treturn

\tif event.is_action_pressed(&"tail_flip", false, true):
\t\t_shift_space_tail_flip_requested = true
\t\tget_viewport().set_input_as_handled()
\t\treturn

\tif event.is_action_pressed(&"conch", false, true):
\t\t_space_action_pressed_this_frame = _is_primary_item_a_binding(event)
'''
replace_between(
    hylas,
    "func _input(event: InputEvent) -> void:\n",
    "\n\nfunc _physics_process",
    input_function,
    '_conus_climb_tether.call(&"retract")',
)

align_function = '''func _align_to_conus_rope() -> void:
\tvar rope_vector: Vector2 = _conus_climb_anchor - global_position
\tif rope_vector.length_squared() <= 0.0001:
\t\treturn
\tvar rope_direction: Vector2 = rope_vector.normalized()
\t_set_visual_rotation(rope_direction.angle() + PI * 0.5)
\tvar normal_scale_x: float = maxf(absf(_conus_climb_normal_sprite_scale.x), 0.001)
\tvar greatfin_active: bool = absf(_animated_sprite.scale.x) > normal_scale_x * 1.15
\tif greatfin_active:
\t\t_animated_sprite.position = _conus_climb_sprite_base_position
\telse:
\t\tvar rope_perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
\t\t_animated_sprite.position = (
\t\t\t_conus_climb_sprite_base_position
\t\t\t+ rope_perpendicular * normal_conus_climb_sprite_perpendicular_offset
\t\t)
'''
replace_between(
    hylas,
    "func _align_to_conus_rope() -> void:\n",
    "\n\nfunc _update_conus_climb_animation",
    align_function,
    "var normal_scale_x: float =",
)
