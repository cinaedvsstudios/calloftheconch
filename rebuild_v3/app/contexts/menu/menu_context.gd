class_name CotcMenuContext
extends Control

signal start_game_requested
signal load_save_requested
signal settings_requested
signal exit_requested

@export_category("Title Intro")
@export_range(0.0, 5.0, 0.05) var title_reveal_delay: float = 0.55
@export_range(0.001, 0.5, 0.01) var title_start_scale: float = 0.02
@export_range(1.0, 2.0, 0.01) var title_burst_scale: float = 1.18
@export_range(0.05, 2.0, 0.01) var title_burst_duration: float = 0.18
@export_range(0.05, 2.0, 0.01) var title_settle_duration: float = 0.28
@export_range(1.0, 1.2, 0.005) var title_pulse_scale: float = 1.035
@export_range(0.2, 8.0, 0.05) var title_pulse_half_duration: float = 1.65
@export_range(0.05, 2.0, 0.01) var button_fade_duration: float = 0.35

@onready var _background_video: VideoStreamPlayer = %BackgroundVideo
@onready var _echo_pulse: VideoStreamPlayer = %EchoPulse
@onready var _title: TextureRect = %Title
@onready var _menu_buttons: VBoxContainer = %MenuButtons
@onready var _main_music: AudioStreamPlayer = %MainMusic
@onready var _impact_audio: AudioStreamPlayer = %ImpactAudio
@onready var _start_button: TextureButton = %StartButton
@onready var _load_save_button: TextureButton = %LoadSaveButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _exit_button: Button = %ExitButton

var _active: bool = false
var _intro_generation: int = 0
var _title_tween: Tween
var _button_tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_impact_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_button.pressed.connect(_on_start_button_pressed)
	_load_save_button.pressed.connect(_on_load_save_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_exit_button.pressed.connect(_on_exit_button_pressed)
	_echo_pulse.finished.connect(_on_echo_pulse_finished)
	_reset_intro_visuals()


func activate() -> void:
	_active = true
	show()
	_play_main_music()
	_play_background_video()
	_start_intro_sequence()
	_start_button.grab_focus()


func deactivate() -> void:
	_active = false
	_intro_generation += 1
	_kill_intro_tweens()
	_main_music.stop()
	_background_video.stop()
	_echo_pulse.stop()
	_echo_pulse.hide()
	_impact_audio.stop()
	hide()


func _play_main_music() -> void:
	if _main_music.stream == null:
		return
	_main_music.stream_paused = false
	if not _main_music.playing:
		_main_music.play()


func _play_background_video() -> void:
	if _background_video.stream == null:
		return
	_background_video.stop()
	_background_video.show()
	_background_video.play()


func _start_intro_sequence() -> void:
	_intro_generation += 1
	var generation: int = _intro_generation
	_kill_intro_tweens()
	_reset_intro_visuals()
	if _echo_pulse.stream != null:
		_echo_pulse.stop()
		_echo_pulse.show()
		_echo_pulse.play()
	_run_intro_after_delay(generation)


func _run_intro_after_delay(generation: int) -> void:
	await get_tree().create_timer(
		maxf(0.0, title_reveal_delay),
		true,
		false,
		true,
	).timeout
	if not _active or generation != _intro_generation:
		return

	if _impact_audio.stream != null:
		_impact_audio.stop()
		_impact_audio.play()

	_title.show()
	_title.scale = Vector2.ONE * title_start_scale
	_title_tween = create_tween()
	_title_tween.tween_property(
		_title,
		&"scale",
		Vector2.ONE * title_burst_scale,
		title_burst_duration,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_title_tween.tween_property(
		_title,
		&"scale",
		Vector2.ONE,
		title_settle_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_button_tween = create_tween()
	_button_tween.tween_interval(title_burst_duration * 0.65)
	_button_tween.tween_property(
		_menu_buttons,
		&"modulate:a",
		1.0,
		button_fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _title_tween.finished
	if not _active or generation != _intro_generation:
		return
	_start_title_pulse()


func _start_title_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(
		_title,
		&"scale",
		Vector2.ONE * title_pulse_scale,
		title_pulse_half_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(
		_title,
		&"scale",
		Vector2.ONE,
		title_pulse_half_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_intro_visuals() -> void:
	_title.hide()
	_title.scale = Vector2.ONE * title_start_scale
	_menu_buttons.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_echo_pulse.hide()


func _kill_intro_tweens() -> void:
	if _title_tween != null:
		_title_tween.kill()
	if _button_tween != null:
		_button_tween.kill()
	if _pulse_tween != null:
		_pulse_tween.kill()
	_title_tween = null
	_button_tween = null
	_pulse_tween = null


func _on_echo_pulse_finished() -> void:
	_echo_pulse.hide()


func _on_start_button_pressed() -> void:
	start_game_requested.emit()


func _on_load_save_button_pressed() -> void:
	load_save_requested.emit()


func _on_settings_button_pressed() -> void:
	settings_requested.emit()


func _on_exit_button_pressed() -> void:
	exit_requested.emit()


func get_debug_lines() -> Array[String]:
	return [
		"[MenuContext]",
		"visible=%s" % str(visible),
		"main_music_playing=%s" % str(_main_music.playing),
		"background_video_playing=%s" % str(_background_video.is_playing()),
		"echo_pulse_playing=%s" % str(_echo_pulse.is_playing()),
	]
