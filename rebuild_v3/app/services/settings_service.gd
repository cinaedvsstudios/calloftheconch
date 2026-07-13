class_name CotcSettingsService
extends Node

signal settings_changed

const CONFIG_PATH: String = "user://settings.cfg"
const SETTINGS_SCHEMA_VERSION: int = 2
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const KEYBINDING_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"action_a",
	&"conch",
	&"utility_item",
	&"inventory",
	&"tail_flip",
	&"pause",
]
const KEYBINDING_LABELS: Dictionary = {
	&"move_left": "Swim left",
	&"move_right": "Swim right",
	&"move_up": "Swim up",
	&"move_down": "Swim down",
	&"action_a": "Burst / brake",
	&"conch": "Use Item A",
	&"utility_item": "Use Item B",
	&"inventory": "Open inventory",
	&"tail_flip": "Tail Flip",
	&"pause": "Pause / back",
}
const MAX_KEYBINDING_SLOTS: int = 2

const DEFAULT_MASTER_VOLUME: float = 0.85
const DEFAULT_MUSIC_VOLUME: float = 0.80
const LEGACY_DEFAULT_EFFECTS_VOLUME: float = 0.90
const EFFECTS_BALANCE_MULTIPLIER: float = 0.75
const DEFAULT_EFFECTS_VOLUME: float = LEGACY_DEFAULT_EFFECTS_VOLUME * EFFECTS_BALANCE_MULTIPLIER
const DEFAULT_MUTE_ALL: bool = false
const DEFAULT_FULLSCREEN: bool = false
const DEFAULT_RESOLUTION_INDEX: int = 0
const DEFAULT_VSYNC_ENABLED: bool = true
const DEFAULT_SCREEN_SHAKE_SCALE: float = 1.0
const DEFAULT_SHOW_CONTROL_HINTS: bool = false

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var effects_volume: float = DEFAULT_EFFECTS_VOLUME
var mute_all: bool = DEFAULT_MUTE_ALL
var fullscreen: bool = DEFAULT_FULLSCREEN
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
var vsync_enabled: bool = DEFAULT_VSYNC_ENABLED
var screen_shake_scale: float = DEFAULT_SCREEN_SHAKE_SCALE
var show_control_hints: bool = DEFAULT_SHOW_CONTROL_HINTS
var last_keybinding_error: String = ""

var _default_keyboard_bindings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_keybindings()
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"SFX")
	_load_settings()
	# Persist migrations immediately so the 25% SFX rebalance is applied only once.
	_save_settings()
	_route_audio_tree(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	call_deferred(&"apply_all_settings")


func apply_all_settings() -> void:
	_apply_audio_settings()
	_apply_display_settings()
	settings_changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_and_emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_and_emit()


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_and_emit()


func set_mute_all(enabled: bool) -> void:
	mute_all = enabled
	_apply_audio_settings()
	_save_and_emit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_display_settings()
	_save_and_emit()


func set_resolution_index(value: int) -> void:
	resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
	_apply_display_settings()
	_save_and_emit()


func set_vsync_enabled(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_display_settings()
	_save_and_emit()


func set_screen_shake_scale(value: float) -> void:
	screen_shake_scale = clampf(value, 0.0, 1.0)
	_save_and_emit()


func set_show_control_hints(_enabled: bool) -> void:
	show_control_hints = false
	_save_and_emit()


func get_keybinding_action_label(action: StringName) -> String:
	return str(KEYBINDING_LABELS.get(action, String(action).capitalize()))


func get_keybinding_event(action: StringName, slot_index: int) -> InputEventKey:
	var keyboard_events: Array = _get_keyboard_events(action)
	if slot_index < 0 or slot_index >= keyboard_events.size():
		return null
	return keyboard_events[slot_index].duplicate() as InputEventKey


func get_keybinding_text(action: StringName, slot_index: int) -> String:
	var key_event: InputEventKey = get_keybinding_event(action, slot_index)
	if key_event == null:
		return "UNBOUND"
	var display_text: String = key_event.as_text_keycode()
	if display_text.is_empty():
		display_text = key_event.as_text_physical_keycode()
	if display_text.is_empty():
		display_text = key_event.as_text()
	return display_text.to_upper()


func set_keybinding_slot(action: StringName, slot_index: int, source_event: InputEventKey) -> bool:
	last_keybinding_error = ""
	if not InputMap.has_action(action):
		last_keybinding_error = "That action is not available."
		return false
	if slot_index < 0 or slot_index >= MAX_KEYBINDING_SLOTS:
		last_keybinding_error = "That binding slot is not available."
		return false
	var normalized_event: InputEventKey = _normalize_key_event(source_event)
	if normalized_event == null:
		last_keybinding_error = "Press a keyboard key."
		return false
	var conflict_action: StringName = _find_keybinding_conflict(action, slot_index, normalized_event)
	if conflict_action != &"":
		last_keybinding_error = "That key is already assigned to %s." % get_keybinding_action_label(conflict_action)
		return false

	var keyboard_events: Array = _get_keyboard_events(action)
	while keyboard_events.size() <= slot_index:
		keyboard_events.append(null)
	keyboard_events[slot_index] = normalized_event
	while not keyboard_events.is_empty() and keyboard_events.back() == null:
		keyboard_events.pop_back()
	_replace_keyboard_events(action, keyboard_events)
	_save_and_emit()
	return true


func clear_keybinding_slot(action: StringName, slot_index: int) -> bool:
	last_keybinding_error = ""
	if not InputMap.has_action(action):
		last_keybinding_error = "That action is not available."
		return false
	var keyboard_events: Array = _get_keyboard_events(action)
	if slot_index < 0 or slot_index >= keyboard_events.size():
		return true
	keyboard_events.remove_at(slot_index)
	_replace_keyboard_events(action, keyboard_events)
	_save_and_emit()
	return true


func reset_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	effects_volume = DEFAULT_EFFECTS_VOLUME
	mute_all = DEFAULT_MUTE_ALL
	fullscreen = DEFAULT_FULLSCREEN
	resolution_index = DEFAULT_RESOLUTION_INDEX
	vsync_enabled = DEFAULT_VSYNC_ENABLED
	screen_shake_scale = DEFAULT_SCREEN_SHAKE_SCALE
	show_control_hints = DEFAULT_SHOW_CONTROL_HINTS
	_restore_default_keybindings()
	apply_all_settings()
	_save_settings()


func get_resolution_options() -> Array[Vector2i]:
	return RESOLUTIONS


func get_selected_resolution() -> Vector2i:
	return RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]


func _capture_default_keybindings() -> void:
	_default_keyboard_bindings.clear()
	for action: StringName in KEYBINDING_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var default_events: Array = []
		for key_event: InputEventKey in _get_keyboard_events(action):
			default_events.append(key_event.duplicate() as InputEventKey)
		_default_keyboard_bindings[action] = default_events


func _restore_default_keybindings() -> void:
	for action: StringName in KEYBINDING_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var default_events: Array = _default_keyboard_bindings.get(action, [])
		var copied_events: Array = []
		for event_variant: Variant in default_events:
			var key_event: InputEventKey = event_variant as InputEventKey
			if key_event != null:
				copied_events.append(key_event.duplicate() as InputEventKey)
		_replace_keyboard_events(action, copied_events)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored_schema_version: int = int(
		config.get_value("meta", "settings_schema_version", 1)
	)
	master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	var loaded_effects_volume: float = float(
		config.get_value(
			"audio",
			"effects_volume",
			LEGACY_DEFAULT_EFFECTS_VOLUME if stored_schema_version < SETTINGS_SCHEMA_VERSION else DEFAULT_EFFECTS_VOLUME,
		)
	)
	if stored_schema_version < SETTINGS_SCHEMA_VERSION:
		loaded_effects_volume *= EFFECTS_BALANCE_MULTIPLIER
	effects_volume = clampf(loaded_effects_volume, 0.0, 1.0)
	mute_all = bool(config.get_value("audio", "mute_all", DEFAULT_MUTE_ALL))
	fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	resolution_index = clampi(
		int(config.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX)),
		0,
		RESOLUTIONS.size() - 1,
	)
	vsync_enabled = bool(config.get_value("display", "vsync_enabled", DEFAULT_VSYNC_ENABLED))
	screen_shake_scale = clampf(
		float(config.get_value("accessibility", "screen_shake_scale", DEFAULT_SCREEN_SHAKE_SCALE)),
		0.0,
		1.0,
	)
	show_control_hints = false
	_load_keybindings(config)


func _load_keybindings(config: ConfigFile) -> void:
	for action: StringName in KEYBINDING_ACTIONS:
		var action_key: String = String(action)
		if not InputMap.has_action(action) or not config.has_section_key("keybindings", action_key):
			continue
		var stored_value: Variant = config.get_value("keybindings", action_key, [])
		if not stored_value is Array:
			continue
		var loaded_events: Array = []
		for event_payload: Variant in stored_value as Array:
			if not event_payload is Dictionary:
				continue
			var key_event: InputEventKey = _deserialize_key_event(event_payload as Dictionary)
			if key_event != null:
				loaded_events.append(key_event)
		_replace_keyboard_events(action, loaded_events)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "settings_schema_version", SETTINGS_SCHEMA_VERSION)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("audio", "mute_all", mute_all)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "vsync_enabled", vsync_enabled)
	config.set_value("accessibility", "screen_shake_scale", screen_shake_scale)
	_save_keybindings(config)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Could not save settings to %s. Error %d." % [CONFIG_PATH, save_error])


func _save_keybindings(config: ConfigFile) -> void:
	for action: StringName in KEYBINDING_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var serialized_events: Array = []
		for key_event: InputEventKey in _get_keyboard_events(action):
			serialized_events.append(_serialize_key_event(key_event))
		config.set_value("keybindings", String(action), serialized_events)


func _serialize_key_event(key_event: InputEventKey) -> Dictionary:
	return {
		"keycode": int(key_event.keycode),
		"physical_keycode": int(key_event.physical_keycode),
		"key_label": int(key_event.key_label),
		"location": int(key_event.location),
		"shift": key_event.shift_pressed,
		"ctrl": key_event.ctrl_pressed,
		"alt": key_event.alt_pressed,
		"meta": key_event.meta_pressed,
	}


func _deserialize_key_event(payload: Dictionary) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.keycode = int(payload.get("keycode", 0))
	key_event.physical_keycode = int(payload.get("physical_keycode", 0))
	key_event.key_label = int(payload.get("key_label", 0))
	key_event.location = int(payload.get("location", 0))
	key_event.shift_pressed = bool(payload.get("shift", false))
	key_event.ctrl_pressed = bool(payload.get("ctrl", false))
	key_event.alt_pressed = bool(payload.get("alt", false))
	key_event.meta_pressed = bool(payload.get("meta", false))
	return _normalize_key_event(key_event)


func _normalize_key_event(source_event: InputEventKey) -> InputEventKey:
	if source_event == null:
		return null
	var key_event := InputEventKey.new()
	key_event.keycode = source_event.keycode
	key_event.physical_keycode = source_event.physical_keycode
	key_event.key_label = source_event.key_label
	key_event.location = source_event.location
	key_event.shift_pressed = source_event.shift_pressed
	key_event.ctrl_pressed = source_event.ctrl_pressed
	key_event.alt_pressed = source_event.alt_pressed
	key_event.meta_pressed = source_event.meta_pressed
	key_event.pressed = false
	key_event.echo = false
	if key_event.keycode == 0 and key_event.physical_keycode == 0:
		return null
	match key_event.keycode:
		KEY_SHIFT:
			key_event.shift_pressed = false
		KEY_CTRL:
			key_event.ctrl_pressed = false
		KEY_ALT:
			key_event.alt_pressed = false
		KEY_META:
			key_event.meta_pressed = false
	return key_event


func _find_keybinding_conflict(
		action: StringName,
		slot_index: int,
		candidate: InputEventKey,
	) -> StringName:
	for other_action: StringName in KEYBINDING_ACTIONS:
		if not InputMap.has_action(other_action):
			continue
		var other_events: Array = _get_keyboard_events(other_action)
		for other_slot: int in range(other_events.size()):
			if other_action == action and other_slot == slot_index:
				continue
			var other_event: InputEventKey = other_events[other_slot] as InputEventKey
			if other_event != null and _key_events_match(candidate, other_event):
				return other_action
	return &""


func _key_events_match(first: InputEventKey, second: InputEventKey) -> bool:
	return (
		first.keycode == second.keycode
		and first.physical_keycode == second.physical_keycode
		and first.shift_pressed == second.shift_pressed
		and first.ctrl_pressed == second.ctrl_pressed
		and first.alt_pressed == second.alt_pressed
		and first.meta_pressed == second.meta_pressed
	)


func _get_keyboard_events(action: StringName) -> Array:
	var keyboard_events: Array = []
	if not InputMap.has_action(action):
		return keyboard_events
	for input_event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = input_event as InputEventKey
		if key_event != null:
			keyboard_events.append(key_event)
	return keyboard_events


func _replace_keyboard_events(action: StringName, keyboard_events: Array) -> void:
	if not InputMap.has_action(action):
		return
	var non_keyboard_events: Array[InputEvent] = []
	for input_event: InputEvent in InputMap.action_get_events(action):
		if not input_event is InputEventKey:
			non_keyboard_events.append(input_event)
	InputMap.action_erase_events(action)
	for event_variant: Variant in keyboard_events:
		var key_event: InputEventKey = event_variant as InputEventKey
		if key_event != null:
			InputMap.action_add_event(action, key_event)
	for input_event: InputEvent in non_keyboard_events:
		InputMap.action_add_event(action, input_event)


func _save_and_emit() -> void:
	_save_settings()
	settings_changed.emit()


func _apply_audio_settings() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"SFX", effects_volume)
	var master_index: int = AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, mute_all)


func _apply_display_settings() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(get_selected_resolution())


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var new_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(new_index, bus_name)


func _set_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume_db: float = -80.0 if linear_volume <= 0.0001 else linear_to_db(linear_volume)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _route_audio_tree(node: Node) -> void:
	_route_audio_node(node)
	for child: Node in node.get_children():
		_route_audio_tree(child)


func _on_node_added(node: Node) -> void:
	call_deferred(&"_route_audio_node", node)


func _route_audio_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var target_bus: StringName = _get_audio_bus_for_node(node)
	var audio_player := node as AudioStreamPlayer
	if audio_player != null:
		audio_player.bus = target_bus
		return
	var audio_player_2d := node as AudioStreamPlayer2D
	if audio_player_2d != null:
		audio_player_2d.bus = target_bus
		return
	var audio_player_3d := node as AudioStreamPlayer3D
	if audio_player_3d != null:
		audio_player_3d.bus = target_bus


func _get_audio_bus_for_node(node: Node) -> StringName:
	var lower_name: String = node.name.to_lower()
	if lower_name.contains("music") or lower_name.contains("ambience"):
		return &"Music"
	return &"SFX"
