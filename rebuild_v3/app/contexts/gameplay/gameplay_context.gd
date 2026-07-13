class_name CotcGameplayContext
extends Node

signal settings_requested
signal menu_requested
signal close_game_requested
signal death_sequence_requested
signal whale_travel_requested

@onready var _level: CotcSeaOfPillars = %SeaOfPillars
@onready var _city: CotcPillarsCity = %PillarsCity
@onready var _sea_environment: Node2D = $SeaEnvironment
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _hud: CotcGameplayHud = %GameplayHud
@onready var _hint: Label = $GameplayUI/Hint
@onready var _pause_overlay: CotcPauseOverlay = %PauseOverlay
@onready var _death_overlay: CotcDeathOverlay = %DeathOverlay

var _active: bool = false
var _in_city: bool = false
var _game_state: CotcGameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gameplay_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_hint.hide()
	_pause_overlay.resume_requested.connect(_on_pause_resume_requested)
	_pause_overlay.settings_requested.connect(_on_pause_settings_requested)
	_pause_overlay.menu_requested.connect(_on_pause_menu_requested)
	_death_overlay.continue_requested.connect(_on_death_continue_requested)
	_death_overlay.menu_requested.connect(_on_death_menu_requested)
	_death_overlay.exit_requested.connect(_on_death_exit_requested)
	_level.death_sequence_requested.connect(_on_level_death_sequence_requested)
	_level.whale_travel_requested.connect(_on_level_whale_travel_requested)
	_level.city_entry_requested.connect(_on_level_city_entry_requested)
	_level.conch_used.connect(_on_level_conch_used)
	_city.exit_requested.connect(_on_city_exit_requested)
	_city.menu_requested.connect(_on_city_menu_requested)
	_city.location_changed.connect(_on_city_location_changed)
	_city.deactivate()
	_sea_environment.hide()


func bind_game_state(game_state: CotcGameState) -> void:
	_game_state = game_state
	_level.bind_game_state(game_state)
	_hud.bind_game_state(game_state)


func activate() -> void:
	_active = true
	_in_city = false
	get_tree().paused = false
	_city.deactivate()
	_sea_environment.show()
	_gameplay_ui.visible = true
	_hint.hide()
	_hud.show()
	_hud.set_location("The Sea of Pillars")
	_pause_overlay.close_overlay()
	_death_overlay.close_overlay()
	if _game_state != null:
		_game_state.set_gameplay_active(true)
		_level.activate(_game_state.current_spawn_point_id)
	else:
		_level.activate()
	_play_gameplay_music()


func deactivate() -> void:
	_active = false
	_in_city = false
	get_tree().paused = false
	_pause_overlay.close_overlay()
	_death_overlay.close_overlay()
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_city.deactivate()
	_sea_environment.hide()
	_level.deactivate()
	if _game_state != null:
		_game_state.set_gameplay_active(false)


func return_to_pause_menu() -> void:
	if not _active or _death_overlay.is_open():
		return
	get_tree().paused = true
	_pause_overlay.open_overlay()


func is_game_active() -> bool:
	return _active


func is_death_sequence_pending() -> bool:
	return _level.is_death_sequence_pending()


func complete_death_respawn() -> void:
	_death_overlay.close_overlay()
	_level.complete_death_respawn()


func apply_accessibility_settings(_show_control_hints: bool, screen_shake_scale: float) -> void:
	_hint.hide()
	_level.set_screen_shake_scale(screen_shake_scale)


func _play_gameplay_music() -> void:
	if _gameplay_music.stream == null:
		return
	_gameplay_music.stream_paused = false
	if not _gameplay_music.playing:
		_gameplay_music.play()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _death_overlay.is_open():
		if event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"pause"):
		if get_tree().paused:
			get_tree().paused = false
			_pause_overlay.close_overlay()
		else:
			get_tree().paused = true
			_pause_overlay.open_overlay()
		get_viewport().set_input_as_handled()


func _on_pause_resume_requested() -> void:
	if not _active:
		return
	get_tree().paused = false


func _on_pause_settings_requested() -> void:
	if not _active:
		return
	get_tree().paused = true
	settings_requested.emit()


func _on_pause_menu_requested() -> void:
	get_tree().paused = false
	menu_requested.emit()


func _on_death_continue_requested() -> void:
	if not _active or not _level.is_death_sequence_pending():
		return
	complete_death_respawn()


func _on_death_menu_requested() -> void:
	if not _active:
		return
	_death_overlay.close_overlay()
	get_tree().paused = false
	menu_requested.emit()


func _on_death_exit_requested() -> void:
	close_game_requested.emit()


func _on_level_death_sequence_requested() -> void:
	if not _active:
		return
	_pause_overlay.close_overlay()
	_death_overlay.open_overlay()
	death_sequence_requested.emit()


func _on_level_whale_travel_requested() -> void:
	whale_travel_requested.emit()


func _on_level_city_entry_requested() -> void:
	if not _active or _in_city:
		return
	_in_city = true
	_level.activate_checkpoint(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
	_level.deactivate()
	_sea_environment.hide()
	_city.activate()
	_hud.set_location("Neresithoppos")


func _on_city_exit_requested() -> void:
	if not _active or not _in_city:
		return
	_in_city = false
	_city.deactivate()
	_sea_environment.show()
	_level.activate(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
	_hud.set_location("The Sea of Pillars")


func _on_city_menu_requested() -> void:
	if not _active or not _in_city:
		return
	get_tree().paused = true
	_pause_overlay.open_overlay()


func _on_city_location_changed(location_name: String) -> void:
	if not _active or not _in_city:
		return
	_hud.set_location(location_name)


func _on_level_conch_used() -> void:
	_hud.pulse_conch()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[GameplayContext]",
		"active=%s" % str(_active),
		"in_city=%s" % str(_in_city),
		"environment_visible=%s" % str(_sea_environment.visible),
		"ui_visible=%s" % str(_gameplay_ui.visible),
		"control_hint_visible=false",
		"music_playing=%s" % str(_gameplay_music.playing),
		"paused=%s" % str(get_tree().paused),
		"death_sequence_pending=%s" % str(_level.is_death_sequence_pending()),
		"death_overlay_open=%s" % str(_death_overlay.is_open()),
	]
	if _game_state != null:
		lines.append("level_id=%s" % String(_game_state.current_level_id))
		lines.append("spawn_point_id=%s" % String(_game_state.current_spawn_point_id))
		lines.append("onos=%d" % _game_state.onos)
		lines.append("limited_use_inventory_items=%d" % _game_state.inventory.size())
		lines.append("permanent_inventory_items=%d" % _game_state.permanent_inventory_items.size())
	lines.append_array(_hud.get_debug_lines())
	lines.append_array(_city.get_debug_lines())
	lines.append_array(_level.get_debug_lines())
	return lines
