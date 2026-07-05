class_name SeaOfPillarsV2
extends Node2D

const SHIP_SWIM_BOTTOM_Y: float = 9000.0

@export_category("Level")
@export var auto_play_ambience: bool = true
@export var auto_play_bubble_overlay: bool = true

@onready var _hylas: HylasV2 = %HylasV2
@onready var _start_marker: Marker2D = %HylasStart
@onready var _waterline_marker: Marker2D = %WaterlineMarker
@onready var _world_top_left: Marker2D = %WorldTopLeft
@onready var _world_bottom_right: Marker2D = %WorldBottomRight
@onready var _world_bottom_right_extension: Marker2D = get_node_or_null("SpawnPoints/WorldBottomRight2") as Marker2D
@onready var _underwater_ambience: AudioStreamPlayer = %UnderwaterAmbience
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _conch_pulse: ConchPulseV2 = %ConchPulseV2
@onready var _surface_splash: SurfaceSplashV2 = %SurfaceSplashV2

var _active: bool = false


func _ready() -> void:
	_underwater_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_hylas.normal_conch_used.connect(_on_hylas_normal_conch_used)
	_hylas.surface_splash_requested.connect(_on_hylas_surface_splash_requested)
	_set_audio_stream_looping(_underwater_ambience)
	configure_player()
	deactivate()


func configure_player() -> void:
	var top_left: Vector2 = _world_top_left.global_position
	var bottom_right: Vector2 = _world_bottom_right.global_position
	if _world_bottom_right_extension != null:
		var extension_position: Vector2 = _world_bottom_right_extension.global_position
		bottom_right = Vector2(
			maxf(bottom_right.x, extension_position.x),
			maxf(bottom_right.y, extension_position.y),
		)

	bottom_right.y = maxf(bottom_right.y, SHIP_SWIM_BOTTOM_Y)
	var world_bounds: Rect2 = Rect2(top_left, bottom_right - top_left)
	_hylas.configure_world(world_bounds, _waterline_marker.global_position.y, _start_marker.global_position)


func activate() -> void:
	_active = true
	show()
	configure_player()
	_hylas.reset_to_start(_start_marker.global_position)
	_hylas.set_play_enabled(true)
	_play_underwater_ambience()
	if auto_play_bubble_overlay and _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()


func deactivate() -> void:
	_active = false
	_hylas.set_play_enabled(false)
	_underwater_ambience.stop()
	_bubble_overlay.stop()
	_bubble_overlay.hide()
	_conch_pulse.hide()
	_surface_splash.hide()
	hide()


func _play_underwater_ambience() -> void:
	if not auto_play_ambience or _underwater_ambience.stream == null:
		return
	_underwater_ambience.stream_paused = false
	if not _underwater_ambience.playing:
		_underwater_ambience.play()


func _on_hylas_normal_conch_used(origin: Vector2, direction: Vector2) -> void:
	if _active:
		_conch_pulse.trigger(origin, direction)


func _on_hylas_surface_splash_requested(origin: Vector2) -> void:
	if _active:
		_surface_splash.trigger(origin)


func _set_audio_stream_looping(player: AudioStreamPlayer) -> void:
	if player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = true
	elif player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
