from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Missing expected block in {path}")
    file_path.write_text(text.replace(old, new, 1))


# Terebridae: emit fresh pulses continuously for five seconds instead of
# stretching the lifetime of the original fixed six pulses.
replace_once(
    "rebuild_v3/app/contexts/gameplay/item_effect_controller.gd",
    '\t\t\t"pulse_interval_scale": 0.48,\n\t\t\t"duration": 5.0,\n',
    '\t\t\t"pulse_interval_scale": 0.48,\n\t\t\t"stream_seconds": 5.0,\n',
)

replace_once(
    "rebuild_v3/features/effects/conch_pulse_item_profiles.gd",
    "var _default_pulse_duration: float\nvar _default_echo_alpha_decay: float\n",
    "var _default_pulse_duration: float\nvar _default_pulse_count: int\nvar _default_echo_alpha_decay: float\n",
)
replace_once(
    "rebuild_v3/features/effects/conch_pulse_item_profiles.gd",
    "\t_default_pulse_duration = pulse_duration\n\t_default_echo_alpha_decay = echo_alpha_decay\n",
    "\t_default_pulse_duration = pulse_duration\n\t_default_pulse_count = pulse_count\n\t_default_echo_alpha_decay = echo_alpha_decay\n",
)
replace_once(
    "rebuild_v3/features/effects/conch_pulse_item_profiles.gd",
    '''\tpulse_duration = float(profile.get("duration", _default_pulse_duration))
\techo_alpha_decay = float(profile.get("echo_alpha_decay", _default_echo_alpha_decay))
\tpulse_interval = _default_pulse_interval * float(profile.get("pulse_interval_scale", 1.0))
''',
    '''\tpulse_duration = float(profile.get("duration", _default_pulse_duration))
\techo_alpha_decay = float(profile.get("echo_alpha_decay", _default_echo_alpha_decay))
\tpulse_interval = _default_pulse_interval * float(profile.get("pulse_interval_scale", 1.0))
\tvar requested_pulse_count: int = int(profile.get("pulse_count", _default_pulse_count))
\tvar stream_seconds: float = maxf(0.0, float(profile.get("stream_seconds", 0.0)))
\tif stream_seconds > 0.0:
\t\trequested_pulse_count = maxi(
\t\t\t1,
\t\t\tint(ceil(stream_seconds / maxf(0.01, pulse_interval))) + 1,
\t\t)
\trequested_pulse_count = clampi(requested_pulse_count, 1, 160)
\tif pulse_count != requested_pulse_count:
\t\tpulse_count = requested_pulse_count
\t\t_build_pulse_sprites()
''',
)
replace_once(
    "rebuild_v3/features/effects/conch_pulse.gd",
    '''func _build_pulse_sprites() -> void:
\t_pulse_sprites.clear()
\t_pulse_sprites.append(_sonar_arc_template)
''',
    '''func _build_pulse_sprites() -> void:
\tfor pulse_index: int in range(1, _pulse_sprites.size()):
\t\tvar old_echo: Sprite2D = _pulse_sprites[pulse_index]
\t\tif is_instance_valid(old_echo):
\t\t\told_echo.free()
\t_pulse_sprites.clear()
\t_pulse_sprites.append(_sonar_arc_template)
''',
)

# Conus: a full-length rope, physics-owned retraction, and no same-frame refire.
replace_once(
    "scenes/characters/Hylas/hylas_equipment_input.gd",
    '@export_range(40.0, 900.0, 5.0) var conus_climb_speed: float = 260.0\n',
    '@export_range(40.0, 900.0, 5.0) var conus_climb_speed: float = 260.0\n@export_range(720.0, 2400.0, 10.0) var conus_climb_rope_length: float = 1500.0\n',
)
replace_once(
    "scenes/characters/Hylas/hylas_equipment_input.gd",
    '''\t_conus_climb_maximum_distance = maxf(
\t\tconus_climb_minimum_distance,
\t\tglobal_position.distance_to(anchor_position),
\t)
''',
    '''\t_conus_climb_maximum_distance = maxf(
\t\tconus_climb_minimum_distance,
\t\tmaxf(conus_climb_rope_length, global_position.distance_to(anchor_position)),
\t)
''',
)
replace_once(
    "scenes/characters/Hylas/hylas_equipment_input.gd",
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
\t\tif event.is_action_pressed(&"conch", false, true):
\t\t\tget_viewport().set_input_as_handled()
\t\treturn
''',
)
replace_once(
    "scenes/characters/Hylas/hylas_equipment_input.gd",
    '''\tif _conus_climb_active:
\t\t_update_conus_wall_climb(delta)
\t\t_utility_item_pressed_this_frame = false
\t\treturn
''',
    '''\tif _conus_climb_active:
\t\tif Input.is_action_just_pressed(&"conch"):
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

# The outline/shadow must follow the normal climb sprite's local offset.
replace_once(
    "scenes/characters/Hylas/hylas_shadow_sync.gd",
    '''\tflip_h = _animated_sprite.flip_h
\trotation = _animated_sprite.rotation
\tscale = _animated_sprite.scale
''',
    '''\tflip_h = _animated_sprite.flip_h
\tposition = _animated_sprite.position
\trotation = _animated_sprite.rotation
\tscale = _animated_sprite.scale
''',
)

# Greatfin adds one extra hit beyond the ordinary fin count.
replace_once(
    "rebuild_v3/app/contexts/gameplay/gameplay_hud.gd",
    '\t_fin_value.text = str(_game_state.current_fins)\n',
    '\tvar displayed_fins: int = _game_state.current_fins + (1 if _game_state.greatfin_active else 0)\n\t_fin_value.text = str(displayed_fins)\n',
)
