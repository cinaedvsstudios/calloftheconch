class_name CotcInkParalysisCloud
extends Node2D

@export_range(0.1, 20.0, 0.1) var active_seconds: float = 10.0
@export_range(0.05, 5.0, 0.05) var fade_in_seconds: float = 0.45
@export_range(0.05, 5.0, 0.05) var fade_out_seconds: float = 0.65
@export_range(0.1, 10.0, 0.1) var paralysis_refresh_seconds: float = 1.0
@export_range(0.05, 1.0, 0.05) var overlap_refresh_interval: float = 0.15
@export_range(0.1, 10.0, 0.1) var opacity_cycle_seconds: float = 3.0
@export_range(0.0, 1.0, 0.01) var minimum_opacity: float = 0.30
@export_range(0.0, 1.0, 0.01) var maximum_opacity: float = 0.90

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
	modulate.a = 0.0
	show()
	_ink_video.stop()
	_ink_video.play()
	set_process(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_overlap_elapsed += delta
	if _overlap_elapsed >= overlap_refresh_interval:
		_overlap_elapsed = 0.0
		_refresh_paralysis()

	var resolved_duration: float = maxf(active_seconds, fade_in_seconds + fade_out_seconds)
	var breathing: float = 0.5 + 0.5 * sin((_elapsed / maxf(0.1, opacity_cycle_seconds)) * TAU)
	var target_alpha: float = lerpf(minimum_opacity, maximum_opacity, breathing)
	if _elapsed < fade_in_seconds:
		modulate.a = target_alpha * clampf(_elapsed / fade_in_seconds, 0.0, 1.0)
	elif _elapsed > resolved_duration - fade_out_seconds:
		modulate.a = target_alpha * clampf((resolved_duration - _elapsed) / fade_out_seconds, 0.0, 1.0)
	else:
		modulate.a = target_alpha

	if _elapsed >= resolved_duration:
		_playing = false
		set_process(false)
		_ink_video.stop()
		queue_free()


func _refresh_paralysis() -> void:
	for area: Area2D in _paralysis_area.get_overlapping_areas():
		_apply_paralysis(area)
	for body: Node2D in _paralysis_area.get_overlapping_bodies():
		_apply_paralysis(body)


func _apply_paralysis(target: Node) -> void:
	if target == null:
		return
	var resolved_target: Node = target
	if not resolved_target.is_in_group(&"enemy") and resolved_target.get_parent() != null and resolved_target.get_parent().is_in_group(&"enemy"):
		resolved_target = resolved_target.get_parent()
	if not resolved_target.is_in_group(&"enemy"):
		return
	if resolved_target.has_method(&"apply_item_paralysis"):
		resolved_target.call(&"apply_item_paralysis", paralysis_refresh_seconds)
	elif resolved_target.has_method(&"receive_conch_hit"):
		resolved_target.call(&"receive_conch_hit", global_position, Vector2.ZERO, 0.0, 1.0)
