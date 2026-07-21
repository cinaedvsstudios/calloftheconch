class_name CotcPirateShipCoordinator
extends Node

## Owns the local transition between the active Sea of Pillars level and the
## pirate-ship interior. The exterior level stays instantiated, so returning
## restores Hylas to the exact position and facing direction used on entry.
## It also owns the two music tracks and the transition swim sound so entry and
## exit use one symmetrical audio sequence.

const INTERIOR_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/sea_of_pillars/levels/pirate_ship_interior.tscn"
)
const PIRATE_SHIP_GROUP: StringName = &"pirate_ship"
const HYLAS_GROUP: StringName = &"hylas"
const AUDIO_DIRECTORY: String = "res://assets/audio"
const AUDIO_EXTENSIONS: PackedStringArray = ["mp3", "ogg", "wav"]
const DEPTH_MUSIC_CANDIDATES: PackedStringArray = [
	"res://assets/audio/seaofpillars-depths.mp3",
	"res://assets/audio/SeaOfPillars-Depths.mp3",
	"res://assets/audio/seaofpillars_depths.mp3",
	"res://assets/audio/Sea of Pillars Depths.mp3",
]
const DEPTH_MUSIC_WORDS: PackedStringArray = ["seaofpillars", "depths"]
const SWIM_AUDIO_CANDIDATES: PackedStringArray = [
	"res://assets/audio/swim_noise.mp3",
	"res://assets/audio/Swim_Noise.mp3",
]
const SWIM_AUDIO_WORDS: PackedStringArray = ["swim", "noise"]

@export_category("Context Nodes")
@export var level_path: NodePath = ^"../SeaOfPillars"
@export var environment_path: NodePath = ^"../SeaEnvironment"
@export var hud_path: NodePath = ^"../GameplayUI/GameplayHud"
@export var music_path: NodePath = ^"../GameplayMusic"
@export var tutorial_path: NodePath = ^"../CuttlefishTutorial"
@export var depth_music_path: NodePath = ^"DepthMusic"
@export var transition_swim_audio_path: NodePath = ^"TransitionSwimAudio"

@export_category("Audio Transition")
@export_range(0.05, 4.0, 0.05) var music_fade_in_seconds: float = 0.75
@export_range(-80.0, -20.0, 1.0) var silent_volume_db: float = -50.0
@export_range(-40.0, 6.0, 0.5) var depth_music_volume_db: float = -8.0
@export_range(-40.0, 6.0, 0.5) var transition_swim_volume_db: float = -3.0

@export_category("Return")
@export_range(0.0, 4.0, 0.05) var return_interaction_cooldown: float = 0.85

var _gameplay_context: Node
var _level: Node
var _environment: CanvasItem
var _hud: Node
var _music: AudioStreamPlayer
var _depth_music: AudioStreamPlayer
var _transition_swim_audio: AudioStreamPlayer
var _tutorial: Node
var _interior: CotcPirateShipInterior
var _active_entry: CotcPirateShipEntry
var _return_position: Vector2 = Vector2.ZERO
var _return_facing_left: bool = false
var _transition_active: bool = false
var _entry_sequence_active: bool = false
var _sea_music_target_volume_db: float = -8.0
var _bound_entries: Array[CotcPirateShipEntry] = []
var _sea_music_tween: Tween
var _depth_music_tween: Tween


func _ready() -> void:
	_gameplay_context = get_parent()
	_environment = get_node_or_null(environment_path) as CanvasItem
	_hud = get_node_or_null(hud_path)
	_music = get_node_or_null(music_path) as AudioStreamPlayer
	_depth_music = get_node_or_null(depth_music_path) as AudioStreamPlayer
	_transition_swim_audio = get_node_or_null(
		transition_swim_audio_path
	) as AudioStreamPlayer
	_tutorial = get_node_or_null(tutorial_path)
	if is_instance_valid(_music):
		_sea_music_target_volume_db = _music.volume_db
	_prepare_transition_audio()
	if _gameplay_context != null:
		if not _gameplay_context.child_entered_tree.is_connected(_on_context_child_changed):
			_gameplay_context.child_entered_tree.connect(_on_context_child_changed)
		if not _gameplay_context.child_exiting_tree.is_connected(_on_context_child_changed):
			_gameplay_context.child_exiting_tree.connect(_on_context_child_changed)
	call_deferred(&"_bind_current_level")


func _exit_tree() -> void:
	_disconnect_entries()
	_kill_audio_tweens()
	_stop_transition_swim()
	if is_instance_valid(_depth_music):
		_depth_music.stop()
	if is_instance_valid(_music):
		_music.volume_db = _sea_music_target_volume_db


func _on_context_child_changed(_child: Node) -> void:
	call_deferred(&"_bind_current_level")


func _bind_current_level() -> void:
	var candidate: Node = get_node_or_null(level_path)
	if candidate == _level and not _bound_entries.is_empty():
		return
	_disconnect_entries()
	_level = candidate
	if _level == null:
		return
	for node: Node in get_tree().get_nodes_in_group(PIRATE_SHIP_GROUP):
		if not _level.is_ancestor_of(node):
			continue
		var entry: CotcPirateShipEntry = node as CotcPirateShipEntry
		if entry == null:
			continue
		var start_callback: Callable = Callable(
			self,
			"_on_entry_transition_started",
		).bind(entry)
		if not entry.entry_transition_started.is_connected(start_callback):
			entry.entry_transition_started.connect(start_callback)
		var request_callback: Callable = Callable(
			self,
			"_on_interior_requested",
		).bind(entry)
		if not entry.interior_requested.is_connected(request_callback):
			entry.interior_requested.connect(request_callback)
		_bound_entries.append(entry)


func _disconnect_entries() -> void:
	for entry: CotcPirateShipEntry in _bound_entries:
		if not is_instance_valid(entry):
			continue
		var start_callback: Callable = Callable(
			self,
			"_on_entry_transition_started",
		).bind(entry)
		if entry.entry_transition_started.is_connected(start_callback):
			entry.entry_transition_started.disconnect(start_callback)
		var request_callback: Callable = Callable(
			self,
			"_on_interior_requested",
		).bind(entry)
		if entry.interior_requested.is_connected(request_callback):
			entry.interior_requested.disconnect(request_callback)
	_bound_entries.clear()


func _on_entry_transition_started(
		duration_seconds: float,
		entry: CotcPirateShipEntry,
	) -> void:
	if (
			_transition_active
			or _entry_sequence_active
			or not is_instance_valid(entry)
			or not is_instance_valid(_level)
		):
		if is_instance_valid(entry):
			entry.cancel_entry_transition()
		return
	if _gameplay_context != null and _gameplay_context.has_method(&"is_game_active"):
		if not bool(_gameplay_context.call(&"is_game_active")):
			entry.cancel_entry_transition()
			return

	_entry_sequence_active = true
	_active_entry = entry
	_start_transition_swim()
	_fade_out_sea_music(maxf(0.05, duration_seconds))


func _on_interior_requested(
		return_position: Vector2,
		facing_left: bool,
		entry: CotcPirateShipEntry,
	) -> void:
	if _transition_active or not is_instance_valid(entry) or not is_instance_valid(_level):
		return
	if _gameplay_context != null and _gameplay_context.has_method(&"is_game_active"):
		if not bool(_gameplay_context.call(&"is_game_active")):
			entry.cancel_entry_transition()
			_restore_audio_after_failed_entry()
			return

	_transition_active = true
	_entry_sequence_active = false
	_active_entry = entry
	_return_position = return_position
	_return_facing_left = facing_left
	_stop_transition_swim()
	_stop_sea_music_for_interior()
	_disable_open_sea_systems()

	_level.call(&"deactivate")
	if is_instance_valid(_environment):
		_environment.hide()

	var interior_instance: Node = INTERIOR_SCENE.instantiate()
	_interior = interior_instance as CotcPirateShipInterior
	if _interior == null:
		push_error("Pirate ship interior scene does not use CotcPirateShipInterior.")
		entry.cancel_entry_transition()
		_restore_open_sea_after_failed_entry()
		return

	_gameplay_context.add_child(_interior)
	_interior.exit_transition_started.connect(_on_interior_exit_transition_started)
	_interior.exit_requested.connect(_on_interior_exit_requested)
	_interior.activate()
	_start_depth_music()
	_set_hud_location("Pirate Shipwreck")


func _on_interior_exit_transition_started(duration_seconds: float) -> void:
	if not _transition_active or not is_instance_valid(_interior):
		return
	_start_transition_swim()
	_fade_out_depth_music(maxf(0.05, duration_seconds))


func _on_interior_exit_requested() -> void:
	if not _transition_active or not is_instance_valid(_interior):
		return
	if not is_instance_valid(_level):
		_bind_current_level()
	if not is_instance_valid(_level):
		push_error("Cannot return from pirate ship because the Sea of Pillars level is missing.")
		return

	if is_instance_valid(_active_entry):
		_active_entry.prepare_return_from_interior(return_interaction_cooldown)

	_stop_depth_music_for_return()
	if is_instance_valid(_environment):
		_environment.show()
	_activate_level_at_return_position()
	_stop_transition_swim()
	_restore_open_sea_systems()
	_set_hud_location("The Sea of Pillars")

	_interior.complete_exit_transition()
	await _interior.transition_finished
	if is_instance_valid(_interior):
		_interior.queue_free()
	_interior = null
	_active_entry = null
	_transition_active = false
	_entry_sequence_active = false


func _activate_level_at_return_position() -> void:
	var spawn_point_id: StringName = &""
	var game_state: Object = null
	if _gameplay_context != null:
		game_state = _gameplay_context.get("_game_state") as Object
	if game_state != null:
		var stored_spawn: Variant = game_state.get("current_spawn_point_id")
		if stored_spawn != null:
			spawn_point_id = StringName(str(stored_spawn))

	_level.call(&"activate", spawn_point_id)
	var sea_hylas: CotcHylas = _find_level_hylas()
	if sea_hylas == null:
		push_error("Sea of Pillars Hylas was not found after leaving the pirate ship.")
		return
	sea_hylas.velocity = Vector2.ZERO
	sea_hylas.reset_to_start(_return_position)
	var sprite: AnimatedSprite2D = sea_hylas.get_node_or_null(^"AnimatedSprite") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = _return_facing_left
	var camera: Camera2D = sea_hylas.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
	sea_hylas.set_play_enabled(true)


func _find_level_hylas() -> CotcHylas:
	for candidate: Node in get_tree().get_nodes_in_group(HYLAS_GROUP):
		if _level.is_ancestor_of(candidate):
			return candidate as CotcHylas
	return null


func _disable_open_sea_systems() -> void:
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"deactivate"):
		_tutorial.call(&"deactivate")
	if _gameplay_context != null:
		if _gameplay_context.has_method(&"_force_deactivate_leaf_sheep"):
			_gameplay_context.call(&"_force_deactivate_leaf_sheep", &"pirate_ship")
		if _gameplay_context.has_method(&"_set_leaf_sheep_gameplay_active"):
			_gameplay_context.call(&"_set_leaf_sheep_gameplay_active", false)


func _restore_open_sea_systems() -> void:
	_start_sea_music()
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"activate"):
		_tutorial.call(&"activate")
	if _gameplay_context != null and _gameplay_context.has_method(
			&"_set_leaf_sheep_gameplay_active"
		):
		_gameplay_context.call(&"_set_leaf_sheep_gameplay_active", true)


func _restore_open_sea_after_failed_entry() -> void:
	if is_instance_valid(_environment):
		_environment.show()
	if is_instance_valid(_level):
		_level.call(&"activate")
	_restore_audio_after_failed_entry()
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"activate"):
		_tutorial.call(&"activate")
	if _gameplay_context != null and _gameplay_context.has_method(
			&"_set_leaf_sheep_gameplay_active"
		):
		_gameplay_context.call(&"_set_leaf_sheep_gameplay_active", true)
	_active_entry = null
	_transition_active = false
	_entry_sequence_active = false


func _restore_audio_after_failed_entry() -> void:
	_stop_transition_swim()
	if is_instance_valid(_depth_music):
		_depth_music.stop()
	_start_sea_music()


func _prepare_transition_audio() -> void:
	if is_instance_valid(_depth_music):
		_depth_music.stop()
		_depth_music.volume_db = silent_volume_db
		if _depth_music.stream == null:
			_depth_music.stream = _load_transition_audio(
				DEPTH_MUSIC_CANDIDATES,
				DEPTH_MUSIC_WORDS,
			)
		if _depth_music.stream != null:
			_set_stream_looping(_depth_music.stream, true)
		else:
			push_warning(
				"Pirate ship depths music was not found in res://assets/audio. "
				+ "Expected seaofpillars-depths.mp3 or a filename containing "
				+ "'seaofpillars' and 'depths'."
			)
	else:
		push_warning("PirateShipCoordinator is missing its DepthMusic AudioStreamPlayer.")

	if is_instance_valid(_transition_swim_audio):
		_transition_swim_audio.stop()
		_transition_swim_audio.volume_db = transition_swim_volume_db
		if _transition_swim_audio.stream == null:
			_transition_swim_audio.stream = _load_transition_audio(
				SWIM_AUDIO_CANDIDATES,
				SWIM_AUDIO_WORDS,
			)
		if _transition_swim_audio.stream != null:
			_set_stream_looping(_transition_swim_audio.stream, true)
		else:
			push_warning(
				"Pirate ship transition sound was not found. Expected "
				+ "res://assets/audio/swim_noise.mp3."
			)
	else:
		push_warning(
			"PirateShipCoordinator is missing its TransitionSwimAudio AudioStreamPlayer."
		)


func _load_transition_audio(
		candidates: PackedStringArray,
		required_words: PackedStringArray,
	) -> AudioStream:
	for path: String in candidates:
		var stream: AudioStream = _load_audio_at_path(path)
		if stream != null:
			return stream

	var directory: DirAccess = DirAccess.open(AUDIO_DIRECTORY)
	if directory == null:
		return null
	directory.list_dir_begin()
	var filename: String = directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and _is_supported_audio_filename(filename):
			if _filename_contains_words(filename, required_words):
				var discovered_path: String = AUDIO_DIRECTORY.path_join(filename)
				var discovered_stream: AudioStream = _load_audio_at_path(discovered_path)
				if discovered_stream != null:
					directory.list_dir_end()
					return discovered_stream
		filename = directory.get_next()
	directory.list_dir_end()
	return null


func _load_audio_at_path(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if not (resource is AudioStream):
		return null
	var duplicated_resource: Resource = resource.duplicate(true)
	if duplicated_resource is AudioStream:
		return duplicated_resource as AudioStream
	return resource as AudioStream


func _is_supported_audio_filename(filename: String) -> bool:
	return AUDIO_EXTENSIONS.has(filename.get_extension().to_lower())


func _filename_contains_words(
		filename: String,
		required_words: PackedStringArray,
	) -> bool:
	var normalised_filename: String = _normalise_audio_name(filename.get_basename())
	for word: String in required_words:
		if not normalised_filename.contains(_normalise_audio_name(word)):
			return false
	return true


func _normalise_audio_name(value: String) -> String:
	return (
		value
		. to_lower()
		. replace(" ", "")
		. replace("_", "")
		. replace("-", "")
	)


func _set_stream_looping(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream as AudioStreamMP3
		mp3_stream.loop = should_loop
	elif stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
		ogg_stream.loop = should_loop


func _fade_out_sea_music(duration_seconds: float) -> void:
	if not is_instance_valid(_music) or not _music.playing:
		return
	_kill_sea_music_tween()
	_sea_music_tween = create_tween()
	_sea_music_tween.set_trans(Tween.TRANS_SINE)
	_sea_music_tween.set_ease(Tween.EASE_IN_OUT)
	_sea_music_tween.tween_property(
		_music,
		^"volume_db",
		silent_volume_db,
		maxf(0.05, duration_seconds),
	)
	_sea_music_tween.finished.connect(_on_sea_music_faded_out, CONNECT_ONE_SHOT)


func _on_sea_music_faded_out() -> void:
	if is_instance_valid(_music):
		_music.stop()
		_music.volume_db = _sea_music_target_volume_db
	_sea_music_tween = null


func _stop_sea_music_for_interior() -> void:
	_kill_sea_music_tween()
	if is_instance_valid(_music):
		_music.stop()
		_music.volume_db = _sea_music_target_volume_db


func _start_sea_music() -> void:
	if not is_instance_valid(_music) or _music.stream == null:
		return
	_kill_sea_music_tween()
	_music.stop()
	_music.volume_db = silent_volume_db
	_music.play()
	_sea_music_tween = create_tween()
	_sea_music_tween.set_trans(Tween.TRANS_SINE)
	_sea_music_tween.set_ease(Tween.EASE_IN_OUT)
	_sea_music_tween.tween_property(
		_music,
		^"volume_db",
		_sea_music_target_volume_db,
		maxf(0.05, music_fade_in_seconds),
	)
	_sea_music_tween.finished.connect(_clear_sea_music_tween, CONNECT_ONE_SHOT)


func _clear_sea_music_tween() -> void:
	_sea_music_tween = null


func _start_depth_music() -> void:
	if not is_instance_valid(_depth_music) or _depth_music.stream == null:
		return
	_kill_depth_music_tween()
	_depth_music.stop()
	_depth_music.volume_db = silent_volume_db
	_depth_music.play()
	_depth_music_tween = create_tween()
	_depth_music_tween.set_trans(Tween.TRANS_SINE)
	_depth_music_tween.set_ease(Tween.EASE_IN_OUT)
	_depth_music_tween.tween_property(
		_depth_music,
		^"volume_db",
		depth_music_volume_db,
		maxf(0.05, music_fade_in_seconds),
	)
	_depth_music_tween.finished.connect(_clear_depth_music_tween, CONNECT_ONE_SHOT)


func _fade_out_depth_music(duration_seconds: float) -> void:
	if not is_instance_valid(_depth_music) or not _depth_music.playing:
		return
	_kill_depth_music_tween()
	_depth_music_tween = create_tween()
	_depth_music_tween.set_trans(Tween.TRANS_SINE)
	_depth_music_tween.set_ease(Tween.EASE_IN_OUT)
	_depth_music_tween.tween_property(
		_depth_music,
		^"volume_db",
		silent_volume_db,
		maxf(0.05, duration_seconds),
	)
	_depth_music_tween.finished.connect(_on_depth_music_faded_out, CONNECT_ONE_SHOT)


func _on_depth_music_faded_out() -> void:
	if is_instance_valid(_depth_music):
		_depth_music.stop()
		_depth_music.volume_db = depth_music_volume_db
	_depth_music_tween = null


func _stop_depth_music_for_return() -> void:
	_kill_depth_music_tween()
	if is_instance_valid(_depth_music):
		_depth_music.stop()
		_depth_music.volume_db = depth_music_volume_db


func _clear_depth_music_tween() -> void:
	_depth_music_tween = null


func _start_transition_swim() -> void:
	if not is_instance_valid(_transition_swim_audio):
		return
	if _transition_swim_audio.stream == null:
		return
	_transition_swim_audio.stop()
	_transition_swim_audio.volume_db = transition_swim_volume_db
	_transition_swim_audio.play()


func _stop_transition_swim() -> void:
	if is_instance_valid(_transition_swim_audio):
		_transition_swim_audio.stop()


func _kill_audio_tweens() -> void:
	_kill_sea_music_tween()
	_kill_depth_music_tween()


func _kill_sea_music_tween() -> void:
	if is_instance_valid(_sea_music_tween) and _sea_music_tween.is_running():
		_sea_music_tween.kill()
	_sea_music_tween = null


func _kill_depth_music_tween() -> void:
	if is_instance_valid(_depth_music_tween) and _depth_music_tween.is_running():
		_depth_music_tween.kill()
	_depth_music_tween = null


func _set_hud_location(location_name: String) -> void:
	if is_instance_valid(_hud) and _hud.has_method(&"set_location"):
		_hud.call(&"set_location", location_name)


func get_debug_lines() -> Array[String]:
	return [
		"[PirateShipCoordinator]",
		"transition_active=%s" % str(_transition_active),
		"entry_sequence_active=%s" % str(_entry_sequence_active),
		"interior_active=%s" % str(is_instance_valid(_interior)),
		"bound_entries=%d" % _bound_entries.size(),
		"return_position=%s" % str(_return_position),
		"sea_music_playing=%s" % str(is_instance_valid(_music) and _music.playing),
		"depth_music_loaded=%s" % str(
			is_instance_valid(_depth_music) and _depth_music.stream != null
		),
		"depth_music_playing=%s" % str(
			is_instance_valid(_depth_music) and _depth_music.playing
		),
		"transition_swim_loaded=%s" % str(
			is_instance_valid(_transition_swim_audio)
			and _transition_swim_audio.stream != null
		),
	]
