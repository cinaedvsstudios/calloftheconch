class_name GameplayContextV2
extends Node

signal menu_requested

@onready var _level: SeaOfPillarsV2 = %SeaOfPillarsV2
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic

func activate() -> void:
	_level.activate()
	_gameplay_music.play()

func deactivate() -> void:
	_gameplay_music.stop()
	_level.deactivate()
