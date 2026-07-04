class_name GameplayContext
extends Node
## Independent gameplay scene. It owns the prototype water world, gameplay UI, pause state, and return route.

signal menu_requested()

const TITLE_SCENE_PATH: String = "res://app/contexts/menu/MenuContext.tscn"

@onready var _prototype_water: PrototypeWater = %PrototypeWater
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _pause_button: Button = %PauseButton
@onready var _control_hint: Label = %ControlHint
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _prototype_tuning_panel: PrototypeTuningPanel = %PrototypeTuningPanel
@onready var _pause_service: PauseService = %PauseService

var _is_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_button.pressed.connect(_on_pause_pressed)
	%ResumeButton.pressed.connect(_on_resume_pressed)
	%DebugTuningButton.pressed.connect(_on_debug_tuning_pressed)
	%ReturnToTitleButton.pressed.connect(_on_return_to_title_pressed)
	_pause_service.pause_changed.connect(_on_pause_changed)
	_pause_overlay.hide()
	_prototype_tuning_panel.bind_dependencies(_prototype_water)
	_prototype_tuning_panel.hide()
	activate()


func bind_dependencies(_external_pause_service: PauseService, _audio_service: AudioService) -> void:
	# Retained only so the unused legacy RootContext scene can still load.
	pass


func get_diagnostic_summary() -> String:
	return _prototype_water.get_diagnostic_summary()


func activate() -> void:
	_is_active = true
	_set_gameplay_controls_visible(true)
	_prototype_water.activate()
	_play_gameplay_music()


func deactivate() -> void:
	_is_active = false
	_pause_service.set_paused(false)
	_pause_overlay.hide()
	_prototype_tuning_panel.close()
	_set_gameplay_controls_visible(false)
	_gameplay_music.stop()
	_prototype_water.deactivate()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed(&"pause"):
		_pause_service.toggle_pause()
		get_viewport().set_input_as_handled()


func _play_gameplay_music() -> void:
	if _gameplay_music.playing:
		return
	_gameplay_music.stream = PrototypeAssets.load_audio_with_words(PackedStringArray(["pillars"]))
	if _gameplay_music.stream != null:
		_gameplay_music.play()


func _set_gameplay_controls_visible(is_visible: bool) -> void:
	_pause_button.visible = is_visible
	_control_hint.visible = is_visible
	if not is_visible:
		_pause_overlay.hide()
		_prototype_tuning_panel.hide()


func _on_pause_pressed() -> void:
	_pause_service.toggle_pause()


func _on_resume_pressed() -> void:
	_pause_service.set_paused(false)


func _on_debug_tuning_pressed() -> void:
	_prototype_tuning_panel.open()


func _on_return_to_title_pressed() -> void:
	deactivate()
	menu_requested.emit()
	var result: Error = get_tree().change_scene_to_file(TITLE_SCENE_PATH)
	if result != OK:
		push_error("Could not return to title scene: %s" % TITLE_SCENE_PATH)


func _on_pause_changed(is_paused: bool) -> void:
	if not _is_active:
		return
	_pause_overlay.visible = is_paused
	_pause_button.text = "Resume" if is_paused else "Pause"
	if not is_paused:
		_prototype_tuning_panel.close()
	if is_paused:
		%ResumeButton.grab_focus()
