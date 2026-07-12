class_name CotcSeaOfPillars
extends Node2D

const CONCH_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/effects/ConchImpact/conch_impact_effect.tscn"
)

signal conch_target_hit(target: Node2D, hit_position: Vector2, pulse_index: int)

@export_category("Level")
@export var auto_play_ambience: bool = true
@export var auto_play_bubble_overlay: bool = true

@export_category("Conch Pulse")
@export_range(0.0, 300.0, 1.0) var conch_origin_forward_offset: float = 105.0

@export_category("Bubble Overlay")
@export_range(0.001, 0.1, 0.001) var bubble_waterline_fade: float = 0.012
@export_range(0.1, 10.0, 0.1) var bubble_waterline_update_interval: float = 2.0

@onready var _hylas: CotcHylas = %Hylas
@onready var _start_marker: Marker2D = %HylasStart
@onready var _waterline_marker: Marker2D = %WaterlineMarker
@onready var _world_top_left: Marker2D = %WorldTopLeft
@onready var _world_bottom_right: Marker2D = %WorldBottomRight
@onready var _underwater_ambience: AudioStreamPlayer = %UnderwaterAmbience
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _conch_pulse: CotcConchPulse = %ConchPulse
@onready var _exit_surface_splash: CotcSurfaceSplash = %ExitSurfaceSplash
@onready var _entry_surface_splash: CotcSurfaceSplash = %EntrySurfaceSplash

var _active: bool = false
var _bubble_material: ShaderMaterial
var _bubble_waterline_update_elapsed: float = 0.0


func _ready() -> void:
	_underwater_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_hylas.normal_conch_used.connect(_on_hylas_normal_conch_used)
	_hylas.surface_splash_requested.connect(_on_hylas_surface_splash_requested)
	_conch_pulse.target_hit.connect(_on_conch_pulse_target_hit)
	_prepare_bubble_material()
	configure_player()
	deactivate()


func _process(delta: float) -> void:
	_bubble_waterline_update_elapsed += delta
	if _bubble_waterline_update_elapsed < bubble_waterline_update_interval:
		return
	_bubble_waterline_update_elapsed = 0.0
	_update_bubble_waterline_mask()


func configure_player() -> void:
	var top_left: Vector2 = _world_top_left.global_position
	var bottom_right: Vector2 = _world_bottom_right.global_position
	var world_bounds: Rect2 = Rect2(top_left, bottom_right - top_left)
	_hylas.configure_world(world_bounds, _waterline_marker.global_position.y, _start_marker.global_position)


func activate() -> void:
	_active = true
	show()
	configure_player()
	_hylas.reset_to_start(_start_marker.global_position)
	_hylas.set_play_enabled(true)
	_play_underwater_ambience()
	_bubble_waterline_update_elapsed = 0.0
	_update_bubble_waterline_mask()
	set_process(true)
	if auto_play_bubble_overlay and _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()


func deactivate() -> void:
	_active = false
	set_process(false)
	_bubble_waterline_update_elapsed = 0.0
	_hylas.set_play_enabled(false)
	_underwater_ambience.stop()
	_bubble_overlay.stop()
	_bubble_overlay.hide()
	_conch_pulse.stop()
	_clear_conch_impacts()
	_exit_surface_splash.stop_splash()
	_entry_surface_splash.stop_splash()
	hide()


func _prepare_bubble_material() -> void:
	var source_material: ShaderMaterial = _bubble_overlay.material as ShaderMaterial
	if source_material == null:
		return
	_bubble_material = source_material.duplicate() as ShaderMaterial
	_bubble_overlay.material = _bubble_material
	_bubble_material.set_shader_parameter(&"waterline_fade", bubble_waterline_fade)


func _update_bubble_waterline_mask() -> void:
	if _bubble_material == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	if viewport_height <= 0.0:
		return
	var waterline_screen_position: Vector2 = get_viewport().get_canvas_transform() * _waterline_marker.global_position
	var waterline_screen_y: float = waterline_screen_position.y / viewport_height
	_bubble_material.set_shader_parameter(&"waterline_screen_y", waterline_screen_y)


func _play_underwater_ambience() -> void:
	if not auto_play_ambience or _underwater_ambience.stream == null:
		return
	_underwater_ambience.stream_paused = false
	if not _underwater_ambience.playing:
		_underwater_ambience.play()


func _on_hylas_normal_conch_used(origin: Vector2, direction: Vector2) -> void:
	if not _active:
		return
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()
	var pulse_origin: Vector2 = origin + pulse_direction * conch_origin_forward_offset
	_conch_pulse.trigger(pulse_origin, pulse_direction)


func _on_conch_pulse_target_hit(target: Node2D, hit_position: Vector2, pulse_index: int) -> void:
	if not _active:
		return
	_spawn_conch_impact(hit_position)
	conch_target_hit.emit(target, hit_position, pulse_index)


func _spawn_conch_impact(hit_position: Vector2) -> void:
	var impact: Node2D = CONCH_IMPACT_SCENE.instantiate() as Node2D
	if impact == null:
		return
	add_child(impact)
	impact.global_position = hit_position
	if impact.has_method(&"play_effect"):
		impact.call(&"play_effect")


func _clear_conch_impacts() -> void:
	for child: Node in get_children():
		if child.is_in_group(&"conch_impact_effect"):
			child.queue_free()


func _on_hylas_surface_splash_requested(origin: Vector2, is_exit: bool) -> void:
	if not _active:
		return
	if is_exit:
		_exit_surface_splash.trigger(origin)
	else:
		_entry_surface_splash.trigger(origin)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[SeaOfPillars]",
		"active=%s" % str(_active),
		"bubble_overlay_visible=%s" % str(_bubble_overlay.visible),
		"bubble_waterline_update_interval=%.2f" % bubble_waterline_update_interval,
		"ambience_playing=%s" % str(_underwater_ambience.playing),
	]
	lines.append_array(_conch_pulse.get_debug_lines())
	lines.append_array(_hylas.get_debug_lines())
	return lines
