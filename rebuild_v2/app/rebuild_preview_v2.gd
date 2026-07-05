extends Node2D

@onready var _level: SeaOfPillarsV2 = $SeaOfPillarsV2

func _ready() -> void:
	_level.activate()
