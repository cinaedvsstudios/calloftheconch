class_name CotcInkParalysisCloud
extends Node2D

signal countdown_changed(remaining_seconds: float, total_seconds: float)
signal cloud_finished

@export_range(0.1, 20.0, 0.1) var active_seconds: float = 10.0
@export_range(0.05, 5.0, 0.05) var fade_in_seconds: float = 0.45
@export_range(0.05, 5.0, 0.05) var fade_out_seconds: float = 0.65
@export_range(0.1, 10.0, 0.1) var paralysis_refresh_seconds: float = 1.0
@export_range(0.05, 1.0, 0.05) var overlap_refresh_interval: float = 0.15
@export_range(0.1, 10.0, 0.1) var opacity_cycle_seconds: float = 3.0
@export_range(0.0, 1.0, 0.01) var minimum_opacity: float = 0.40
@export_range(0.0, 1.0, 0.01) var maximum_opacity: float = 0.80
@export_range(20.0, 1000.0, 5.0) var paralysis_radius: float = 250.0

@onready var _ink_video: VideoStreamPlayer = %InkVideo
@onready var _paralysis_area: Area2D = %ParalysisArea

var _elapsed: float = 0.0
var _overlap_elapsed: float = 0.0
var _playing: bool = false


func _ready() -> void:
	_ink_video.loop = true
	if not _ink_video.finished.is_connected(_on_ink_video_finished):
		_ink_video.finished.connect(_on_ink_video_finished)
	_ink_video.stop()
	hide()
	set_process(false)


func play_cloud(world_position: Vector2) -> void:
	global_position = world_position
	_elapsed = 0.0
	_overlap_elapsed = overlap_refresh_interval
	_playing = true
	modulate.a = 0.0
	show()
	_restart_video()
	set_process(true)
	countdown_changed.emit(active_seconds, active_seconds)


func _process(delta: float) -> void:
	if not _playing:
		return

	_elapsed += delta
	var active_start: float = fade_in_seconds
	var active_end: float = active_start + active_seconds
	var total_duration: float = active_end + fade_out_seconds

	# Some video streams can still report finished despite loop being enabled.
	# Restart explicitly so the ink remains moving for the entire effect.
	if not _ink_video.is_playing() and _elapsed < total_duration:
		_restart_video()

	var breathing: float = 0.5 + 0.5 * sin((_elapsed / maxf(0.1, opacity_cycle_seconds)) * TAU)
	var target_alpha: float = lerpf(minimum_opacity, maximum_opacity, breathing)
	if _elapsed < active_start:
		modulate.a = target_alpha * clampf(_elapsed / maxf(0.05, fade_in_seconds), 0.0, 1.0)
	elif _elapsed < active_end:
		modulate.a = target_alpha
	else:
		modulate.a = target_alpha * clampf(
			(total_duration - _elapsed) / maxf(0.05, fade_out_seconds),
			0.0,
			1.0,
		)

	if _elapsed >= active_start and _elapsed < active_end:
		_overlap_elapsed += delta
		if _overlap_elapsed >= overlap_refresh_interval:
			_overlap_elapsed = 0.0
			_refresh_paralysis()
		var remaining_seconds: float = maxf(0.0, active_end - _elapsed)
		countdown_changed.emit(remaining_seconds, active_seconds)
	elif _elapsed < active_start:
		countdown_changed.emit(active_seconds, active_seconds)
	else:
		countdown_changed.emit(0.0, active_seconds)

	if _elapsed >= total_duration:
		_finish_cloud()


func get_active_remaining_seconds() -> float:
	if not _playing:
		return 0.0
	var active_start: float = fade_in_seconds
	var active_end: float = active_start + active_seconds
	if _elapsed < active_start:
		return active_seconds
	return clampf(active_end - _elapsed, 0.0, active_seconds)


func _restart_video() -> void:
	if _ink_video.stream == null:
		return
	_ink_video.stop()
	_ink_video.play()


func _on_ink_video_finished() -> void:
	if _playing:
		_restart_video()


func _finish_cloud() -> void:
	if not _playing:
		return
	_playing = false
	set_process(false)
	_ink_video.stop()
	modulate.a = 0.0
	countdown_changed.emit(0.0, active_seconds)
	cloud_finished.emit()
	queue_free()


func _refresh_paralysis() -> void:
	var seen_targets: Dictionary = {}

	# Physics overlap remains useful for enemies with ordinary active collision.
	for area: Area2D in _paralysis_area.get_overlapping_areas():
		_apply_paralysis(area, seen_targets, false)
	for body: Node2D in _paralysis_area.get_overlapping_bodies():
		_apply_paralysis(body, seen_targets, false)

	# Some enemies disable their collision or monitoring while using distance
	# activation. Scan the canonical groups as well so every visible enemy inside
	# the cloud receives the same paralysis refresh.
	for candidate: Node in get_tree().get_nodes_in_group(&"enemy"):
		_apply_paralysis(candidate, seen_targets, true)
	for candidate: Node in get_tree().get_nodes_in_group(&"hazard"):
		_apply_paralysis(candidate, seen_targets, true)
	for candidate: Node in get_tree().get_nodes_in_group(&"conch_target"):
		_apply_paralysis(candidate, seen_targets, true)


func _apply_paralysis(
		target: Node,
		seen_targets: Dictionary,
		enforce_radius: bool,
	) -> void:
	var resolved_target: Node = _resolve_enemy_target(target)
	if resolved_target == null or resolved_target.is_queued_for_deletion():
		return

	var target_id: int = resolved_target.get_instance_id()
	if seen_targets.has(target_id):
		return

	if enforce_radius:
		var target_2d: Node2D = resolved_target as Node2D
		if target_2d == null:
			return
		var maximum_distance_squared: float = paralysis_radius * paralysis_radius
		if global_position.distance_squared_to(target_2d.global_position) > maximum_distance_squared:
			return

	seen_targets[target_id] = true
	if resolved_target.has_method(&"apply_item_paralysis"):
		resolved_target.call(&"apply_item_paralysis", paralysis_refresh_seconds)
	elif resolved_target.has_method(&"receive_conch_hit"):
		resolved_target.call(&"receive_conch_hit", global_position, Vector2.ZERO, 0.0, 1.0)


func _resolve_enemy_target(target: Node) -> Node:
	var current: Node = target
	var parent_checks: int = 0
	while current != null and parent_checks < 12:
		if (
			current.is_in_group(&"enemy")
			or current.is_in_group(&"hazard")
			or current.has_method(&"apply_item_paralysis")
		):
			return current
		current = current.get_parent()
		parent_checks += 1
	return null
