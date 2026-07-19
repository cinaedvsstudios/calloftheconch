extends "res://rebuild_v3/app/contexts/gameplay/gameplay_inventory_audio.gd"

## Adds the level-local cuttlefish tutorial feature to the existing gameplay context.

@onready var _cuttlefish_tutorial: CotcCuttlefishTutorialController = %CuttlefishTutorial


func _ready() -> void:
	super._ready()
	_cuttlefish_tutorial.bind_level(_level)


func bind_game_state(game_state: CotcGameState) -> void:
	super.bind_game_state(game_state)
	_cuttlefish_tutorial.bind_game_state(game_state)


func apply_accessibility_settings(show_control_hints: bool, screen_shake_scale: float) -> void:
	super.apply_accessibility_settings(show_control_hints, screen_shake_scale)
	_cuttlefish_tutorial.call(&"set_tooltips_enabled", show_control_hints)


func activate() -> void:
	super.activate()
	_cuttlefish_tutorial.activate()


func deactivate() -> void:
	_cuttlefish_tutorial.deactivate()
	super.deactivate()


func complete_death_respawn() -> void:
	super.complete_death_respawn()
	_cuttlefish_tutorial.activate()


func _replace_level(replacement: CotcSeaOfPillars) -> void:
	super._replace_level(replacement)
	_cuttlefish_tutorial.bind_level(_level)


func _on_level_city_entry_requested() -> void:
	super._on_level_city_entry_requested()
	if _in_city:
		_cuttlefish_tutorial.deactivate()


func _on_city_exit_requested() -> void:
	super._on_city_exit_requested()
	if _active and not _in_city:
		_cuttlefish_tutorial.activate()


func _on_level_death_sequence_requested() -> void:
	_cuttlefish_tutorial.deactivate()
	super._on_level_death_sequence_requested()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append_array(_cuttlefish_tutorial.get_debug_lines())
	return lines
