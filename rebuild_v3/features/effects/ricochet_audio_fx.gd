class_name CotcRicochetAudioFx
extends Node2D

## Presentation-only ricochet audio layer. It listens to Hylas ricochet bounces
## and plays short overlapping one-shots at the wall contact position.

const IMPACT_STREAM: AudioStream = preload("res://assets/audio/impact.mp3")
const SUPERJUMP_STREAM: AudioStream = preload("res://assets/audio/superjump.mp3")

@export_category("Ricochet Audio")
@export var enabled: bool = true
@export var play_impact: bool = true
@export var play_superjump: bool = true
@export_range(-40.0, 12.0, 0.5) var impact_volume_db: float = -2.0
@export_range(-40.0, 12.0, 0.5) var superjump_volume_db: float = -7.0
@export_range(0.50, 2.00, 0.01) var pitch_min: float = 0.96
@export_range(0.50, 2.00, 0.01) var pitch_max: float = 1.04

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hylas: Node


func _ready() -> void:
	_rng.randomize()
	_hylas = _resolve_hylas()
	if _hylas == null:
		push_warning("RicochetAudioFX could not find Hylas to connect ricochet_bounced.")
		return
	if _hylas.has_signal(&"ricochet_bounced"):
		var callback: Callable = Callable(self, &"_on_ricochet_bounced")
		if not _hylas.is_connected(&"ricochet_bounced", callback):
			_hylas.connect(&"ricochet_bounced", callback)


func _resolve_hylas() -> Node:
	var candidate: Node = owner
	if candidate != null and candidate.has_signal(&"ricochet_bounced"):
		return candidate
	candidate = get_parent()
	while candidate != null:
		if candidate.has_signal(&"ricochet_bounced"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _on_ricochet_bounced(
		contact_position: Vector2,
		_normal: Vector2,
		_new_direction: Vector2,
		_chain_count: int,
	) -> void:
	if not enabled:
		return
	if play_impact:
		_play_one_shot(IMPACT_STREAM, contact_position, impact_volume_db)
	if play_superjump:
		_play_one_shot(SUPERJUMP_STREAM, contact_position, superjump_volume_db)


func _play_one_shot(stream: AudioStream, origin: Vector2, volume_db: float) -> void:
	if stream == null:
		return
	var audio_parent: Node = _hylas.get_parent() if _hylas != null else get_tree().current_scene
	if audio_parent == null:
		audio_parent = self
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.name = "RicochetOneShotAudio"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(pitch_min, pitch_max)
	player.top_level = true
	audio_parent.add_child(player)
	player.global_position = origin
	player.finished.connect(player.queue_free)
	player.play()
