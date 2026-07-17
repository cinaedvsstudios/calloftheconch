from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Missing expected block in {path}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


HYLAS_INPUT = "scenes/characters/Hylas/hylas_equipment_input.gd"
SHADOW_SYNC = "scenes/characters/Hylas/hylas_shadow_sync.gd"

# Retraction and ordinary firing must read the same Input action state. The
# release latch prevents the original firing press from immediately retracting
# the tether if Space is still held when the dart reaches the wall.
replace_once(
    HYLAS_INPUT,
    "var _conus_climb_previous_facing_left: bool = false\nvar _conus_climb_sprite_base_position: Vector2 = Vector2.ZERO\n",
    "var _conus_climb_previous_facing_left: bool = false\nvar _conus_climb_wait_for_conch_release: bool = false\nvar _conus_climb_sprite_base_position: Vector2 = Vector2.ZERO\n",
)
replace_once(
    HYLAS_INPUT,
    "\t_conus_climb_anchor = anchor_position\n\t_conus_climb_tether = tether\n\t_conus_climb_maximum_distance = maxf(\n",
    "\t_conus_climb_anchor = anchor_position\n\t_conus_climb_tether = tether\n\t_conus_climb_wait_for_conch_release = Input.is_action_pressed(&\"conch\")\n\t_conus_climb_maximum_distance = maxf(\n",
)
replace_once(
    HYLAS_INPUT,
    "\t_conus_climb_active = false\n\t_conus_climb_tether = null\n\t_conus_climb_maximum_distance = 0.0\n",
    "\t_conus_climb_active = false\n\t_conus_climb_tether = null\n\t_conus_climb_wait_for_conch_release = false\n\t_conus_climb_maximum_distance = 0.0\n",
)
replace_once(
    HYLAS_INPUT,
    '''\tif _conus_climb_active:
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
''',
    '''\tif _conus_climb_active:
\t\t# Climb retraction is owned by _physics_process so firing and retraction
\t\t# read the same Input action state.
\t\treturn
''',
)
replace_once(
    HYLAS_INPUT,
    '''\tif _conus_climb_active:
\t\t_update_conus_wall_climb(delta)
\t\t_utility_item_pressed_this_frame = false
\t\treturn
''',
    '''\tif _conus_climb_active:
\t\tif _conus_climb_wait_for_conch_release:
\t\t\tif not Input.is_action_pressed(&"conch"):
\t\t\t\t_conus_climb_wait_for_conch_release = false
\t\telif Input.is_action_just_pressed(&"conch"):
\t\t\t_space_action_pressed_this_frame = false
\t\t\t_pending_conch_remaining = 0.0
\t\t\t_pending_interaction_remaining = 0.0
\t\t\t_utility_item_pressed_this_frame = false
\t\t\tif is_instance_valid(_conus_climb_tether) and _conus_climb_tether.has_method(&"retract"):
\t\t\t\t_conus_climb_tether.call(&"retract")
\t\t\telse:
\t\t\t\tend_conus_wall_climb()
\t\t\treturn
\t\t_update_conus_wall_climb(delta)
\t\t_utility_item_pressed_this_frame = false
\t\treturn
''',
)

# ShadowSprite is a sibling of AnimatedSprite. Copying the local position keeps
# the outline attached when the normal climb sprite receives its rope offset.
replace_once(
    SHADOW_SYNC,
    "\tflip_h = _animated_sprite.flip_h\n\trotation = _animated_sprite.rotation\n\tscale = _animated_sprite.scale\n",
    "\tflip_h = _animated_sprite.flip_h\n\tposition = _animated_sprite.position\n\trotation = _animated_sprite.rotation\n\tscale = _animated_sprite.scale\n",
)
