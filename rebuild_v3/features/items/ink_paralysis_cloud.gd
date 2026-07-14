class_name CotcInkParalysisCloud
extends Node2D

@export_range(0.1, 20.0, 0.1) var active_seconds: float = 4.0
@export_range(0.05, 5.0, 0.05) var fade_in_seconds: float = 0.45
@export_range(0.05, 5.0, 0.05) var fade_out_seconds: float = 0.65
@export_range(0.1, 10.0, 0.1) var paralysis_refresh_seconds: float = 0.8
@export_range(0.05, 1.0, 0.05) var overlap_refresh_interval: float = 0.20

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
	if _elapsed < fade_in_seconds:
		modulate.a = clampf(_elapsed / maxf(0.01, fade_in_seconds), 0.0, 1.0)
	elif _elapsed > resolved_duration - fade_out_seconds:
		modulate.a = clampf(
			(resolved_duration - _elapsed) / maxf(0.01, fade_out_seconds),
			0.0,
			1.0,
		)
	else:
		modulate.a = 1.0

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
	if target == null or not target.is_in_group(&"enemy"):
		return
	if target.has_method(&"apply_item_paralysis"):
		target.call(&"apply_item_paralysis", paralysis_refresh_seconds)
		return
	if target.has_method(&"receive_conch_hit"):
		target.call(
			&"receive_conch_hit",
			global_position,
			Vector2.ZERO,
			0.0,
			1.0,
		)
