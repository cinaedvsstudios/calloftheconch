class_name SettingsService
extends Node
## Stores player-facing preferences. The owning root calls initialize explicitly.

const SETTINGS_PATH: String = "user://settings.json"

const DEFAULT_SETTINGS: Dictionary = {
	"master_volume_db": 0.0,
	"music_volume_db": -4.0,
	"sfx_volume_db": 0.0,
	"fullscreen": false,
	"vsync_mode": DisplayServer.VSYNC_ENABLED,
	"language": "en",
}

signal settings_loaded()
signal setting_changed(setting_key: StringName, value: Variant)

var values: Dictionary = {}


func initialize() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	values = DEFAULT_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		settings_loaded.emit()
		return

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		settings_loaded.emit()
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error == OK and json.data is Dictionary:
		var loaded_values: Dictionary = json.data as Dictionary
		for key: Variant in loaded_values.keys():
			if DEFAULT_SETTINGS.has(key):
				values[key] = loaded_values[key]

	settings_loaded.emit()


func save_settings() -> Error:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(values, "\t"))
	file.close()
	return OK


func get_value(setting_key: StringName, fallback: Variant = null) -> Variant:
	return values.get(str(setting_key), fallback)


func set_value(setting_key: StringName, value: Variant, save_immediately: bool = true) -> Error:
	values[str(setting_key)] = value
	apply_setting(setting_key)
	setting_changed.emit(setting_key, value)
	return save_settings() if save_immediately else OK


func set_bus_volume(bus_name: StringName, volume_db: float) -> Error:
	var setting_key: StringName = StringName("%s_volume_db" % str(bus_name).to_lower())
	return set_value(setting_key, volume_db)


func set_fullscreen(enabled: bool) -> Error:
	return set_value(&"fullscreen", enabled)


func apply_settings() -> void:
	apply_setting(&"master_volume_db")
	apply_setting(&"music_volume_db")
	apply_setting(&"sfx_volume_db")
	apply_setting(&"fullscreen")
	apply_setting(&"vsync_mode")


func apply_setting(setting_key: StringName) -> void:
	match setting_key:
		&"master_volume_db":
			_apply_bus_volume(&"Master", float(get_value(setting_key, 0.0)))
		&"music_volume_db":
			_apply_bus_volume(&"Music", float(get_value(setting_key, 0.0)))
		&"sfx_volume_db":
			_apply_bus_volume(&"SFX", float(get_value(setting_key, 0.0)))
		&"fullscreen":
			var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_value(setting_key, false)) else DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode(mode)
		&"vsync_mode":
			DisplayServer.window_set_vsync_mode(int(get_value(setting_key, DisplayServer.VSYNC_ENABLED)))
		_:
			pass


func _apply_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)
