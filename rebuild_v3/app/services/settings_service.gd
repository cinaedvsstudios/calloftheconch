class_name CotcSettingsService
extends Node

signal settings_changed

const CONFIG_PATH: String = "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const DEFAULT_MASTER_VOLUME: float = 0.85
const DEFAULT_MUSIC_VOLUME: float = 0.80
const DEFAULT_EFFECTS_VOLUME: float = 0.90
const DEFAULT_MUTE_ALL: bool = false
const DEFAULT_FULLSCREEN: bool = false
const DEFAULT_RESOLUTION_INDEX: int = 0
const DEFAULT_VSYNC_ENABLED: bool = true
const DEFAULT_SCREEN_SHAKE_SCALE: float = 1.0
const DEFAULT_SHOW_CONTROL_HINTS: bool = true

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var effects_volume: float = DEFAULT_EFFECTS_VOLUME
var mute_all: bool = DEFAULT_MUTE_ALL
var fullscreen: bool = DEFAULT_FULLSCREEN
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
var vsync_enabled: bool = DEFAULT_VSYNC_ENABLED
var screen_shake_scale: float = DEFAULT_SCREEN_SHAKE_SCALE
var show_control_hints: bool = DEFAULT_SHOW_CONTROL_HINTS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus(&"Music")
	_ensure_audio_bus(&"SFX")
	_load_settings()
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


func set_show_control_hints(enabled: bool) -> void:
	show_control_hints = enabled
	_save_and_emit()


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
	apply_all_settings()
	_save_settings()


func get_resolution_options() -> Array[Vector2i]:
	return RESOLUTIONS


func get_selected_resolution() -> Vector2i:
	return RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("audio", "effects_volume", DEFAULT_EFFECTS_VOLUME)), 0.0, 1.0)
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
	show_control_hints = bool(
		config.get_value("accessibility", "show_control_hints", DEFAULT_SHOW_CONTROL_HINTS)
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("audio", "mute_all", mute_all)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "vsync_enabled", vsync_enabled)
	config.set_value("accessibility", "screen_shake_scale", screen_shake_scale)
	config.set_value("accessibility", "show_control_hints", show_control_hints)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Could not save settings to %s. Error %d." % [CONFIG_PATH, save_error])


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
