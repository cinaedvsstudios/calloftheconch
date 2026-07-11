class_name CotcDeveloperAdminPanel
extends Control

const AUDIO_TEST_FREQUENCY_HZ: float = 660.0
const AUDIO_TEST_DURATION_SECONDS: float = 0.80
const AUDIO_TEST_MIX_RATE: float = 22050.0
const AUDIO_TEST_AMPLITUDE: float = 0.22

@onready var _report_text: TextEdit = %ReportText
@onready var _refresh_button: Button = %RefreshButton
@onready var _audio_test_button: Button = %AudioTestButton
@onready var _copy_button: Button = %CopyButton
@onready var _close_button: Button = %CloseButton
@onready var _audio_test_player: AudioStreamPlayer = %AudioTestPlayer

var _root_context: CotcRootContext
var _menu_context: CotcMenuContext
var _gameplay_context: CotcGameplayContext
var _audio_test_playback: AudioStreamGeneratorPlayback
var _audio_test_phase: float = 0.0
var _audio_test_remaining: float = 0.0
var _master_bus_index: int = -1
var _master_was_muted: bool = false
var _master_original_volume_db: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_button.pressed.connect(refresh_report)
	_audio_test_button.pressed.connect(_play_audio_test)
	_copy_button.pressed.connect(_copy_report)
	_close_button.pressed.connect(hide)
	set_process(false)
	hide()


func _process(delta: float) -> void:
	if _audio_test_remaining <= 0.0:
		_finish_audio_test()
		return
	_audio_test_remaining = maxf(0.0, _audio_test_remaining - delta)
	_fill_audio_test_buffer()
	if _audio_test_remaining <= 0.0:
		_finish_audio_test()


func bind_contexts(root_context: CotcRootContext, menu_context: CotcMenuContext, gameplay_context: CotcGameplayContext) -> void:
	_root_context = root_context
	_menu_context = menu_context
	_gameplay_context = gameplay_context


func toggle_panel() -> void:
	visible = not visible
	if visible:
		refresh_report()
		grab_focus()


func refresh_report() -> void:
	if _root_context == null:
		_report_text.text = "Developer/Admin panel is not bound yet."
		return
	_report_text.text = _root_context.build_debug_report()


func _play_audio_test() -> void:
	_finish_audio_test()

	_master_bus_index = AudioServer.get_bus_index(&"Master")
	if _master_bus_index >= 0:
		_master_was_muted = AudioServer.is_bus_mute(_master_bus_index)
		_master_original_volume_db = AudioServer.get_bus_volume_db(_master_bus_index)
		AudioServer.set_bus_mute(_master_bus_index, false)
		AudioServer.set_bus_volume_db(_master_bus_index, 0.0)

	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = AUDIO_TEST_MIX_RATE
	generator.buffer_length = 0.20
	_audio_test_player.stream = generator
	_audio_test_player.play()
	_audio_test_playback = _audio_test_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_audio_test_phase = 0.0
	_audio_test_remaining = AUDIO_TEST_DURATION_SECONDS
	_audio_test_button.disabled = true
	set_process(true)
	_fill_audio_test_buffer()
	refresh_report()


func _fill_audio_test_buffer() -> void:
	if _audio_test_playback == null:
		return
	var available_frames: int = _audio_test_playback.get_frames_available()
	var remaining_frames: int = ceili(_audio_test_remaining * AUDIO_TEST_MIX_RATE)
	var frames_to_write: int = mini(available_frames, remaining_frames)
	var phase_increment: float = AUDIO_TEST_FREQUENCY_HZ / AUDIO_TEST_MIX_RATE
	for _frame_index: int in range(frames_to_write):
		var sample: float = sin(_audio_test_phase * TAU) * AUDIO_TEST_AMPLITUDE
		_audio_test_playback.push_frame(Vector2(sample, sample))
		_audio_test_phase = fposmod(_audio_test_phase + phase_increment, 1.0)


func _finish_audio_test() -> void:
	if _audio_test_player != null and _audio_test_player.playing:
		_audio_test_player.stop()
	_audio_test_playback = null
	_audio_test_remaining = 0.0
	if _master_bus_index >= 0:
		AudioServer.set_bus_volume_db(_master_bus_index, _master_original_volume_db)
		AudioServer.set_bus_mute(_master_bus_index, _master_was_muted)
	_master_bus_index = -1
	if _audio_test_button != null:
		_audio_test_button.disabled = false
	set_process(false)


func _copy_report() -> void:
	DisplayServer.clipboard_set(_report_text.text)
