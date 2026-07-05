class_name GameplayContextV2
extends Node

signal menu_requested

@onready var _level: SeaOfPillarsV2 = %SeaOfPillarsV2
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _pause_overlay: PauseOverlayV2 = %PauseOverlay

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.menu_requested.connect(_on_pause_menu_requested)

func activate() -> void:
	_gameplay_ui.visible = true
	_level.activate()
	_gameplay_music.play()

func deactivate() -> void:
	get_tree().paused = false
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_level.deactivate()

func _on_pause_menu_requested() -> void:
	menu_requested.emit()
