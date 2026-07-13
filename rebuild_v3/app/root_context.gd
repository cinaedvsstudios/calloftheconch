class_name CotcRootContext
extends Node

const SETTINGS_ORIGIN_MENU: StringName = &"menu"
const SETTINGS_ORIGIN_GAMEPLAY: StringName = &"gameplay"

@onready var _game_state: CotcGameState = %GameState
@onready var _save_service: CotcSaveService = %SaveService
@onready var _settings_service: CotcSettingsService = %SettingsService
@onready var _menu_context: CotcMenuContext = %MenuContext
@onready var _continue_context: CotcContinueContext = %ContinueContext
@onready var _intro_context: CotcIntroContext = %IntroContext
@onready var _settings_context: CotcSettingsContext = %SettingsContext
@onready var _gameplay_context: CotcGameplayContext = %GameplayContext
@onready var _developer_admin_panel: CotcDeveloperAdminPanel = %DeveloperAdminPanel

var _settings_origin: StringName = SETTINGS_ORIGIN_MENU


func _ready() -> void:
	_save_service.bind_game_state(_game_state)
	_gameplay_context.bind_game_state(_game_state)
	_continue_context.bind_save_service(_save_service)
	_settings_context.bind_settings(_settings_service)
	_settings_context.bind_save_service(_save_service)
	_developer_admin_panel.bind_contexts(self, _menu_context, _gameplay_context)

	_menu_context.start_game_requested.connect(_on_new_game_requested)
	_menu_context.load_save_requested.connect(_on_continue_requested)
	_menu_context.settings_requested.connect(_on_menu_settings_requested)
	_menu_context.exit_requested.connect(_on_exit_requested)
	_continue_context.load_requested.connect(_on_load_requested)
	_continue_context.back_requested.connect(_on_continue_back_requested)
	_intro_context.intro_finished.connect(_on_intro_finished)
	_settings_context.save_game_requested.connect(_on_save_game_requested)
	_settings_context.back_requested.connect(_on_settings_back_requested)
	_settings_service.settings_changed.connect(_apply_runtime_settings)
	_gameplay_context.settings_requested.connect(_on_gameplay_settings_requested)
	_gameplay_context.menu_requested.connect(_on_menu_requested)

	_continue_context.deactivate()
	_intro_context.deactivate()
	_settings_context.deactivate()
	_gameplay_context.deactivate()
	_apply_runtime_settings()
	_menu_context.activate()


func _on_new_game_requested() -> void:
	_continue_context.deactivate()
	_settings_context.deactivate()
	_menu_context.deactivate()
	_intro_context.activate()


func _on_intro_finished() -> void:
	_intro_context.deactivate()
	_game_state.start_new_game()
	_gameplay_context.activate()


func _on_continue_requested() -> void:
	_settings_context.deactivate()
	_menu_context.deactivate(false)
	_continue_context.activate()


func _on_continue_back_requested() -> void:
	_continue_context.deactivate()
	_menu_context.activate()


func _on_load_requested(save_id: String) -> void:
	if not _save_service.load_save(save_id):
		_continue_context.show_load_error(_save_service.last_error_message)
		return
	_continue_context.deactivate()
	_settings_context.deactivate()
	_menu_context.deactivate(true)
	_gameplay_context.activate()


func _on_menu_settings_requested() -> void:
	_settings_origin = SETTINGS_ORIGIN_MENU
	_continue_context.deactivate()
	_menu_context.deactivate(false)
	_settings_context.activate(false)


func _on_gameplay_settings_requested() -> void:
	_settings_origin = SETTINGS_ORIGIN_GAMEPLAY
	_settings_context.activate(true)


func _on_settings_back_requested() -> void:
	_settings_context.deactivate()
	if _settings_origin == SETTINGS_ORIGIN_GAMEPLAY and _gameplay_context.is_game_active():
		_gameplay_context.return_to_pause_menu()
		return
	_settings_origin = SETTINGS_ORIGIN_MENU
	_menu_context.activate()


func _on_save_game_requested(save_name: String) -> void:
	if not _gameplay_context.is_game_active():
		_settings_context.show_save_result(false, "A game must be active before it can be saved.")
		return
	var saved_payload: Dictionary = _save_service.save_named(save_name)
	if saved_payload.is_empty():
		_settings_context.show_save_result(false, _save_service.last_error_message)
		return
	_settings_context.show_save_result(true, "Saved as ‘%s’." % str(saved_payload.get("name", save_name)))


func _on_menu_requested() -> void:
	_gameplay_context.deactivate()
	_continue_context.deactivate()
	_intro_context.deactivate()
	_settings_context.deactivate()
	_settings_origin = SETTINGS_ORIGIN_MENU
	_menu_context.activate()


func _on_exit_requested() -> void:
	get_tree().quit()


func _apply_runtime_settings() -> void:
	if not is_instance_valid(_settings_service) or not is_instance_valid(_gameplay_context):
		return
	_gameplay_context.apply_accessibility_settings(
		_settings_service.show_control_hints,
		_settings_service.screen_shake_scale,
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_developer_admin"):
		_developer_admin_panel.toggle_panel()
		get_viewport().set_input_as_handled()


func build_debug_report() -> String:
	var lines: Array[String] = []
	lines.append("Call of the Conch Prototype")
	lines.append("Root context active")
	lines.append("Tree paused: %s" % str(get_tree().paused))
	lines.append("")
	lines.append_array(_get_audio_debug_lines())
	lines.append("")
	lines.append_array(_menu_context.get_debug_lines())
	lines.append("")
	lines.append_array(_continue_context.get_debug_lines())
	lines.append("")
	lines.append_array(_intro_context.get_debug_lines())
	lines.append("")
	lines.append_array(_settings_context.get_debug_lines())
	lines.append("")
	lines.append_array(_get_save_debug_lines())
	lines.append("")
	lines.append_array(_gameplay_context.get_debug_lines())
	return "\n".join(lines)


func _get_save_debug_lines() -> Array[String]:
	return [
		"[SaveState]",
		"save_count=%d" % _save_service.list_saves().size(),
		"active_save_id=%s" % _game_state.active_save_id,
		"active_save_name=%s" % _game_state.active_save_name,
		"level_id=%s" % String(_game_state.current_level_id),
		"spawn_point_id=%s" % String(_game_state.current_spawn_point_id),
		"playtime=%s" % _game_state.get_playtime_display(),
		"onos=%d" % _game_state.onos,
		"inventory_item_types=%d" % _game_state.inventory.size(),
	]


func _get_audio_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[Audio]",
		"driver=%s" % AudioServer.get_driver_name(),
		"output_device=%s" % AudioServer.output_device,
		"available_output_devices=%s" % str(AudioServer.get_output_device_list()),
		"mix_rate_hz=%s" % str(AudioServer.get_mix_rate()),
	]
	var master_bus_index: int = AudioServer.get_bus_index(&"Master")
	if master_bus_index < 0:
		lines.append("master_bus=missing")
		return lines
	lines.append("master_muted=%s" % str(AudioServer.is_bus_mute(master_bus_index)))
	lines.append("master_volume_db=%.2f" % AudioServer.get_bus_volume_db(master_bus_index))
	lines.append("master_peak_left_db=%.2f" % AudioServer.get_bus_peak_volume_left_db(master_bus_index, 0))
	lines.append("master_peak_right_db=%.2f" % AudioServer.get_bus_peak_volume_right_db(master_bus_index, 0))
	return lines
