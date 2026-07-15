class_name CotcInkParalysisCloud
extends Node2D

signal time_remaining_changed(remaining_seconds: float, duration_seconds: float)
signal cloud_finished

@export_range(0.1, 60.0, 0.1) var active_seconds: float = 30.0
@export_range(0.1, 10.0, 0.1) var paralysis_refresh_seconds: float = 1.0
@export_range(0.05, 1.0, 0.05) var overlap_refresh_interval: float = 0.15
@export_range(0.1, 10.0, 0.1) var opacity_cycle_seconds: float = 3.0
@export_range(0.0, 1.0, 0.01) var minimum_opacity: float = 0.40
@export_range(0.0, 1.0, 0.01) var maximum_opacity: float = 0.80
@export_range(20.0, 1000.0, 5.0) var paralysis_radius: float = 300.0

@onready var _ink_video: VideoStreamPlayer = %InkVideo
@onready var _paralysis_area: Area2D = %ParalysisArea

var _elapsed: float = 0.0
var _overlap_elapsed: float = 0.0
var _playing: bool = false


func _ready() -> void:
	_ink_video.loop = true
	_ink_video.stop()
	hide()
	set_process(false)


func play_cloud(world_position: Vector2) -> void:
	global_position = world_position
	_elapsed = 0.0
	_overlap_elapsed = overlap_refresh_interval
	_playing = true
	modulate.a = minimum_opacity
	show()
	_ink_video.stop()
	_ink_video.play()
	set_process(true)
	_refresh_paralysis()
	time_remaining_changed.emit(active_seconds, active_seconds)


func _process(delta: float) -> void:
	if not _playing:
		return

	_elapsed = minf(active_seconds, _elapsed + maxf(delta, 0.0))
	_overlap_elapsed += maxf(delta, 0.0)
	if _overlap_elapsed >= overlap_refresh_interval:
		_overlap_elapsed = 0.0
		_refresh_paralysis()

	# Keep the source video visibly looping for the complete ten-second active
	# period. Some codecs can report a stopped player at the loop boundary, so
	# restart it here rather than allowing the visual to disappear early.
	if not _ink_video.is_playing() and _elapsed < active_seconds:
		_ink_video.play()

	var breathing: float = 0.5 + 0.5 * sin((_elapsed / maxf(0.1, opacity_cycle_seconds)) * TAU)
	modulate.a = clampf(lerpf(minimum_opacity, maximum_opacity, breathing), 0.40, 0.80)

	var remaining_seconds: float = maxf(0.0, active_seconds - _elapsed)
	time_remaining_changed.emit(remaining_seconds, active_seconds)
	if remaining_seconds > 0.0:
		return

	_playing = false
	set_process(false)
	_ink_video.stop()
	cloud_finished.emit()
	queue_free()


func get_time_remaining() -> float:
	return maxf(0.0, active_seconds - _elapsed) if _playing else 0.0


func _refresh_paralysis() -> void:
	var seen_targets: Dictionary = {}

	for area: Area2D in _paralysis_area.get_overlapping_areas():
		_apply_paralysis(area, seen_targets, false)
	for body: Node2D in _paralysis_area.get_overlapping_bodies():
		_apply_paralysis(body, seen_targets, false)

	# Distance-activated enemies can temporarily disable their collision. The
	# canonical groups keep the cloud reliable for those enemies as well.
	for candidate: Node in get_tree().get_nodes_in_group(&"enemy"):
		_apply_paralysis(candidate, seen_targets, true)
	for candidate: Node in get_tree().get_nodes_in_group(&"conch_target"):
		_apply_paralysis(candidate, seen_targets, true)
	for candidate: Node in get_tree().get_nodes_in_group(&"hazard"):
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
		var target_2d: Node2D = target as Node2D
		if target_2d == null:
			target_2d = resolved_target as Node2D
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
				or current.has_method(&"receive_conch_hit")
		):
			return current
		current = current.get_parent()
		parent_checks += 1
	return null
