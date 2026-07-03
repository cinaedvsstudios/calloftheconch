class_name RootContext
extends Node
## Composition root for the title screen, one gameplay context and permanent diagnostics.

const MENU_CONTEXT_ID: StringName = &"menu"
const GAMEPLAY_CONTEXT_ID: StringName = &"gameplay"
@export_range(0.0, 2.0, 0.01) var context_fade_duration: float = 0.45

@onready var _settings_service: SettingsService = %SettingsService
@onready var _audio_service: AudioService = %AudioService
@onready var _pause_service: PauseService = %PauseService
@onready var _menu_context: MenuContext = %MenuContext
@onready var _gameplay_context: GameplayContext = %GameplayContext
@onready var _developer_admin_panel: DeveloperAdminPanel = %DeveloperAdminPanel
@onready var _fade_rect: ColorRect = %FadeRect

var _active_context_id: StringName = &""
var _is_switching_context: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_service.initialize()
	_gameplay_context.bind_dependencies(_pause_service, _audio_service)
	_developer_admin_panel.bind_dependencies(self, _pause_service)
	_developer_admin_panel.record_action("project", "RootContext initialised")
	_menu_context.start_game_requested.connect(_on_start_game_requested)
	_menu_context.quit_requested.connect(_on_quit_requested)
	_gameplay_context.menu_requested.connect(_on_menu_requested)
	_activate_initial_menu()


func switch_context(context_id: StringName) -> void:
	if _is_switching_context or context_id == _active_context_id:
		return

	var next_context: Node = _get_context(context_id)
	if next_context == null:
		push_warning("RootContext has no context named '%s'." % context_id)
		return

	_is_switching_context = true
	await _fade_to(1.0)

	var current_context: Node = _get_context(_active_context_id)
	if current_context != null and current_context.has_method(&"deactivate"):
		current_context.call(&"deactivate")
	if next_context.has_method(&"activate"):
		next_context.call(&"activate")
	_active_context_id = context_id
	_developer_admin_panel.record_action("context", str(context_id))

	await _fade_to(0.0)
	_is_switching_context = false


func get_active_context_id_text() -> String:
	return str(_active_context_id)


func get_diagnostic_summary() -> String:
	if _active_context_id == GAMEPLAY_CONTEXT_ID:
		return _gameplay_context.get_diagnostic_summary()
	return "MenuContext active. No save slot or gameplay state is used in Prototype 0.1."


func _activate_initial_menu() -> void:
	# The first screen must be available immediately. Gameplay CanvasLayers are explicitly
	# deactivated before the title appears so no gameplay-only overlay leaks over the menu.
	_gameplay_context.deactivate()
	_menu_context.activate()
	_active_context_id = MENU_CONTEXT_ID
	_fade_rect.modulate.a = 0.0
	_developer_admin_panel.record_action("context", str(MENU_CONTEXT_ID))


func _on_start_game_requested() -> void:
	await switch_context(GAMEPLAY_CONTEXT_ID)


func _on_menu_requested() -> void:
	await switch_context(MENU_CONTEXT_ID)


func _on_quit_requested() -> void:
	_developer_admin_panel.record_action("application", "quit requested")
	get_tree().quit()


func _get_context(context_id: StringName) -> Node:
	match context_id:
		MENU_CONTEXT_ID:
			return _menu_context
		GAMEPLAY_CONTEXT_ID:
			return _gameplay_context
		_:
			return null


func _fade_to(target_alpha: float) -> void:
	if context_fade_duration <= 0.0:
		_fade_rect.modulate.a = target_alpha
		return

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "modulate:a", clampf(target_alpha, 0.0, 1.0), context_fade_duration)
	await tween.finished
