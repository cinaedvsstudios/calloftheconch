class_name MenuContext
extends Control
## Independent title scene. It loads gameplay only after Start is pressed.

signal start_game_requested()
signal quit_requested()

const GAMEPLAY_SCENE_PATH: String = "res://app/contexts/gameplay/GameplayContext.tscn"

@onready var _background: TextureRect = %Background
@onready var _title: TextureRect = %Title
@onready var _start_button: Button = %StartButton
@onready var _main_music: AudioStreamPlayer = %MainMusic

var _pulse_tween: Tween


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_background.texture = PrototypeAssets.load_texture(PrototypeAssets.CITY_BACKGROUND_CANDIDATES)
	_title.texture = PrototypeAssets.load_texture(PrototypeAssets.TITLE_TEXTURE_CANDIDATES)
	_title.pivot_offset = _title.size * 0.5
	call_deferred("activate")


func activate() -> void:
	show()
	_start_button.hide()
	_title.hide()
	_title.scale = Vector2(0.04, 0.04)
	_title.modulate.a = 0.0
	_play_main_music()
	call_deferred("_queue_title_entrance")


func deactivate() -> void:
	_stop_title_animation()
	_main_music.stop()
	hide()


func _queue_title_entrance() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(0.50, true)
	await timer.timeout
	if not is_visible_in_tree():
		return
	_play_title_entrance()


func _play_title_entrance() -> void:
	if not is_visible_in_tree():
		return
	_title.pivot_offset = _title.size * 0.5
	_title.show()
	var entrance_tween: Tween = create_tween()
	entrance_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance_tween.set_trans(Tween.TRANS_BACK)
	entrance_tween.set_ease(Tween.EASE_OUT)
	entrance_tween.parallel().tween_property(_title, "scale", Vector2(1.10, 1.10), 0.52)
	entrance_tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.20)
	entrance_tween.tween_property(_title, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entrance_tween.tween_callback(_show_start_button)
	entrance_tween.tween_callback(_begin_title_pulse)


func _show_start_button() -> void:
	_start_button.modulate.a = 0.0
	_start_button.show()
	_start_button.grab_focus()
	var button_tween: Tween = create_tween()
	button_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	button_tween.tween_property(_start_button, "modulate:a", 1.0, 0.22)


func _begin_title_pulse() -> void:
	_stop_title_animation()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tween.tween_property(_title, "scale", Vector2(1.035, 1.035), 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_title, "scale", Vector2(0.995, 0.995), 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_title_animation() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _play_main_music() -> void:
	if _main_music.playing:
		return
	_main_music.stream = PrototypeAssets.load_audio_with_words(PackedStringArray(["call", "conch", "music"]))
	if _main_music.stream != null:
		_main_music.play()


func _on_start_pressed() -> void:
	_main_music.stop()
	if get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH) != OK:
		push_error("Could not open gameplay scene: %s" % GAMEPLAY_SCENE_PATH)


func _on_quit_pressed() -> void:
	quit_requested.emit()
	get_tree().quit()
