extends "res://rebuild_v3/app/services/settings_service.gd"

## Restores the saved tutorial-tooltip setting and defaults it to enabled.

const DEFAULT_TUTORIAL_TOOLTIPS: bool = true


func _load_settings() -> void:
	super._load_settings()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		show_control_hints = DEFAULT_TUTORIAL_TOOLTIPS
		return
	show_control_hints = bool(
		config.get_value(
			"accessibility",
			"show_control_hints",
			DEFAULT_TUTORIAL_TOOLTIPS,
		)
	)


func _save_settings() -> void:
	super._save_settings()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	config.set_value("accessibility", "show_control_hints", show_control_hints)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Could not save tutorial tooltip setting. Error %d." % save_error)


func set_show_control_hints(enabled: bool) -> void:
	if show_control_hints == enabled:
		return
	show_control_hints = enabled
	_save_settings()
	settings_changed.emit()


func reset_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	effects_volume = DEFAULT_EFFECTS_VOLUME
	mute_all = DEFAULT_MUTE_ALL
	fullscreen = DEFAULT_FULLSCREEN
	resolution_index = DEFAULT_RESOLUTION_INDEX
	vsync_enabled = DEFAULT_VSYNC_ENABLED
	screen_shake_scale = DEFAULT_SCREEN_SHAKE_SCALE
	show_control_hints = DEFAULT_TUTORIAL_TOOLTIPS
	_restore_default_keybindings()
	apply_all_settings()
	_save_settings()
