class_name GameplayContextV2
extends Node

signal menu_requested

@onready var _level: SeaOfPillarsV2 = %SeaOfPillarsV2
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _pause_overlay: PauseOverlayV2 = %PauseOverlay

var _active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.menu_requested.connect(_on_pause_menu_requested)

func activate() -> void:
	_active = true
	get_tree().paused = false
	_gameplay_ui.visible = true
	_pause_overlay.close_overlay()
	_level.activate()
	_gameplay_music.play()

func deactivate() -> void:
	_active = false
	get_tree().paused = false
	_pause_overlay.close_overlay()
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_level.deactivate()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"pause"):
		if get_tree().paused:
			get_tree().paused = false
			_pause_overlay.close_overlay()
		else:
			get_tree().paused = true
			_pause_overlay.open_overlay()
		get_viewport().set_input_as_handled()

func _on_pause_menu_requested() -> void:
	get_tree().paused = false
	menu_requested.emit()
