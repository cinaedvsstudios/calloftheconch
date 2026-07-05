class_name MenuContextV2
extends Control

signal start_game_requested
signal exit_requested

func activate() -> void:
	show()

func deactivate() -> void:
	hide()
