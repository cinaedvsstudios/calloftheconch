class_name GameplayContextV2
extends Node

signal menu_requested

@onready var _level: SeaOfPillarsV2 = %SeaOfPillarsV2
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI

func activate() -> void:
	_gameplay_ui.visible = true
	_level.activate()
	_gameplay_music.play()

func deactivate() -> void:
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_level.deactivate()
