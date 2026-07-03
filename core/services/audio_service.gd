class_name AudioService
extends Node
## Context-persistent audio service with per-sound concurrency caps.

@export var sound_effect_settings: Array[SoundEffectSetting] = []

var _settings_by_key: Dictionary = {}
var _active_count_by_key: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	rebuild_catalogue()


func rebuild_catalogue() -> void:
	_settings_by_key.clear()
	for setting: SoundEffectSetting in sound_effect_settings:
		if setting == null or not setting.is_valid():
			continue
		_settings_by_key[setting.key] = setting


func play_sfx(
	key: StringName,
	volume_offset_db: float = 0.0,
	pitch_scale_override: float = -1.0
) -> AudioStreamPlayer:
	var setting: SoundEffectSetting = _get_setting(key)
	if setting == null or get_active_count(key) >= setting.max_simultaneous:
		return null

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = setting.stream
	player.bus = _resolve_bus_name(setting.bus_name)
	player.volume_db = setting.volume_db + volume_offset_db
	player.pitch_scale = _resolve_pitch_scale(setting, pitch_scale_override)
	player.set_meta("sound_key", key)
	add_child(player)
	_active_count_by_key[key] = get_active_count(key) + 1
	player.finished.connect(_on_player_finished.bind(player, key), CONNECT_ONE_SHOT)
	player.play()
	return player


func get_active_count(key: StringName) -> int:
	return int(_active_count_by_key.get(key, 0))


func stop_all_sfx() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			child.queue_free()
	_active_count_by_key.clear()


func _get_setting(key: StringName) -> SoundEffectSetting:
	var value: Variant = _settings_by_key.get(key)
	return value as SoundEffectSetting if value is SoundEffectSetting else null


func _resolve_bus_name(requested_bus_name: StringName) -> StringName:
	return requested_bus_name if AudioServer.get_bus_index(requested_bus_name) >= 0 else &"Master"


func _resolve_pitch_scale(setting: SoundEffectSetting, override_value: float) -> float:
	if override_value > 0.0:
		return override_value
	return _rng.randf_range(setting.pitch_random_min, setting.pitch_random_max)


func _on_player_finished(player: AudioStreamPlayer, key: StringName) -> void:
	_active_count_by_key[key] = maxi(0, get_active_count(key) - 1)
	if is_instance_valid(player):
		player.queue_free()
