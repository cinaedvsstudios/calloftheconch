class_name CotcRootContext
extends Node

@onready var _menu_context: CotcMenuContext = %MenuContext
@onready var _gameplay_context: CotcGameplayContext = %GameplayContext
@onready var _developer_admin_panel: CotcDeveloperAdminPanel = %DeveloperAdminPanel


func _ready() -> void:
	_developer_admin_panel.bind_contexts(self, _menu_context, _gameplay_context)
	_menu_context.start_game_requested.connect(_on_start_game_requested)
	_menu_context.exit_requested.connect(_on_exit_requested)
	_gameplay_context.menu_requested.connect(_on_menu_requested)
	_gameplay_context.deactivate()
	_menu_context.activate()


func _on_start_game_requested() -> void:
	_menu_context.deactivate()
	_gameplay_context.activate()


func _on_menu_requested() -> void:
	_gameplay_context.deactivate()
	_menu_context.activate()


func _on_exit_requested() -> void:
	get_tree().quit()


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
	lines.append_array(_gameplay_context.get_debug_lines())
	return "\n".join(lines)


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
