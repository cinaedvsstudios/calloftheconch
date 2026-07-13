class_name CotcSettingsContext
extends Control

signal back_requested

@onready var _water_background: CotcWaterVideoBackground = %WaterVideoBackground
@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _effects_slider: HSlider = %EffectsSlider
@onready var _effects_value: Label = %EffectsValue
@onready var _mute_check: CheckButton = %MuteCheck
@onready var _display_mode_option: OptionButton = %DisplayModeOption
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _vsync_check: CheckButton = %VSyncCheck
@onready var _shake_slider: HSlider = %ShakeSlider
@onready var _shake_value: Label = %ShakeValue
@onready var _control_hints_check: CheckButton = %ControlHintsCheck
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton

var _settings: CotcSettingsService
var _syncing_controls: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_display_options()
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_effects_slider.value_changed.connect(_on_effects_volume_changed)
	_mute_check.toggled.connect(_on_mute_toggled)
	_display_mode_option.item_selected.connect(_on_display_mode_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_shake_slider.value_changed.connect(_on_shake_changed)
	_control_hints_check.toggled.connect(_on_control_hints_toggled)
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func bind_settings(settings_service: CotcSettingsService) -> void:
	_settings = settings_service
	if is_node_ready():
		_populate_resolution_options()
		_sync_from_settings()


func activate() -> void:
	show()
	_water_background.play_background()
	_populate_resolution_options()
	_sync_from_settings()
	_back_button.grab_focus()


func deactivate() -> void:
	_water_background.stop_background()
	hide()


func _populate_display_options() -> void:
	_display_mode_option.clear()
	_display_mode_option.add_item("Windowed", 0)
	_display_mode_option.add_item("Fullscreen", 1)
	_populate_resolution_options()


func _populate_resolution_options() -> void:
	_resolution_option.clear()
	if _settings == null:
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
			_resolution_option.add_item("%d × %d" % [size.x, size.y])
		return
	for size: Vector2i in _settings.get_resolution_options():
		_resolution_option.add_item("%d × %d" % [size.x, size.y])


func _sync_from_settings() -> void:
	if _settings == null:
		return
	_syncing_controls = true
	_master_slider.value = _settings.master_volume * 100.0
	_music_slider.value = _settings.music_volume * 100.0
	_effects_slider.value = _settings.effects_volume * 100.0
	_mute_check.button_pressed = _settings.mute_all
	_display_mode_option.select(1 if _settings.fullscreen else 0)
	_resolution_option.select(_settings.resolution_index)
	_resolution_option.disabled = _settings.fullscreen
	_vsync_check.button_pressed = _settings.vsync_enabled
	_shake_slider.value = _settings.screen_shake_scale * 100.0
	_control_hints_check.button_pressed = _settings.show_control_hints
	_syncing_controls = false
	_update_value_labels()


func _update_value_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_slider.value)
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_effects_value.text = "%d%%" % roundi(_effects_slider.value)
	_shake_value.text = "%d%%" % roundi(_shake_slider.value)


func _on_master_volume_changed(value: float) -> void:
	_master_value.text = "%d%%" % roundi(value)
	if not _syncing_controls and _settings != null:
		_settings.set_master_volume(value / 100.0)


func _on_music_volume_changed(value: float) -> void:
	_music_value.text = "%d%%" % roundi(value)
	if not _syncing_controls and _settings != null:
		_settings.set_music_volume(value / 100.0)


func _on_effects_volume_changed(value: float) -> void:
	_effects_value.text = "%d%%" % roundi(value)
	if not _syncing_controls and _settings != null:
		_settings.set_effects_volume(value / 100.0)


func _on_mute_toggled(enabled: bool) -> void:
	if not _syncing_controls and _settings != null:
		_settings.set_mute_all(enabled)


func _on_display_mode_selected(index: int) -> void:
	if _syncing_controls or _settings == null:
		return
	_settings.set_fullscreen(index == 1)
	_resolution_option.disabled = index == 1


func _on_resolution_selected(index: int) -> void:
	if not _syncing_controls and _settings != null:
		_settings.set_resolution_index(index)


func _on_vsync_toggled(enabled: bool) -> void:
	if not _syncing_controls and _settings != null:
		_settings.set_vsync_enabled(enabled)


func _on_shake_changed(value: float) -> void:
	_shake_value.text = "%d%%" % roundi(value)
	if not _syncing_controls and _settings != null:
		_settings.set_screen_shake_scale(value / 100.0)


func _on_control_hints_toggled(enabled: bool) -> void:
	if not _syncing_controls and _settings != null:
		_settings.set_show_control_hints(enabled)


func _on_reset_pressed() -> void:
	if _settings == null:
		return
	_settings.reset_defaults()
	_sync_from_settings()


func _on_back_pressed() -> void:
	back_requested.emit()


func get_debug_lines() -> Array[String]:
	return [
		"[SettingsContext]",
		"visible=%s" % str(visible),
		"background_playing=%s" % str(_water_background.is_background_playing()),
	]
