class_name RootContextV2
extends Node

@onready var _menu_context: MenuContextV2 = %MenuContextV2
@onready var _gameplay_context: GameplayContextV2 = %GameplayContextV2


func _ready() -> void:
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
