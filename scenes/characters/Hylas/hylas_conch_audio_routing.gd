extends "res://scenes/characters/Hylas/hylas_phase6_fix.gd"

const ROUTED_NORMAL_CONCH_ID: StringName = &"normal_conch"
const ROUTED_SUPER_CONCH_ID: StringName = &"charonia_tritonis"
const NORMAL_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Conch_noise.mp3")
const SUPER_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Super Conch_noise.mp3")


func _ready() -> void:
	super._ready()
	_sync_equipped_conch_audio()


func set_equipped_item_a(item_id: StringName) -> void:
	super.set_equipped_item_a(item_id)
	if is_node_ready():
		_sync_equipped_conch_audio()


func _sync_equipped_conch_audio() -> void:
	if not is_instance_valid(_conch_audio):
		return
	_conch_audio.stop()
	match get_equipped_item_a():
		ROUTED_NORMAL_CONCH_ID:
			_conch_audio.stream = NORMAL_CONCH_AUDIO_STREAM
		ROUTED_SUPER_CONCH_ID:
			_conch_audio.stream = SUPER_CONCH_AUDIO_STREAM
		_:
			# Terebridae and Conus play their dedicated audio from the item controller.
			_conch_audio.stream = null
