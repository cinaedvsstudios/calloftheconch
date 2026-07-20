@tool
class_name CotcDepthColourisation
extends Node

## Inspector-driven colour controller for depth plants and jellyfish.
## Up to three colours can be supplied. Cycle mode always begins at Colour 1,
## interpolates through hue/saturation/value, and keeps the halo and PointLight2D
## on the exact same colour. A transparent colour is treated as an empty slot.
## With two active colours the sequence automatically ping-pongs 1 -> 2 -> 1.
## In the editor the first active colour is previewed without running the cycle.

enum ColourMode {
	DISABLED,
	FIXED,
	CYCLE,
}

const COLOUR_SHADER: Shader = preload(
	"res://rebuild_v3/features/depth_life/depth_colourisation.gdshader"
)
const EMPTY_ALPHA_THRESHOLD: float = 0.01
const DEFAULT_TRANSITION_SECONDS: float = 10.0

@export_category("Colour Controller")
@export_enum("Disabled", "Fixed", "Cycle") var colour_mode: int = ColourMode.CYCLE
@export var colour_1: Color = Color(0.05, 0.72, 1.0, 1.0)
@export var colour_2: Color = Color(0.72, 0.10, 1.0, 1.0)
@export var colour_3: Color = Color(0.0, 0.0, 0.0, 0.0)
@export_range(0.25, 120.0, 0.25) var seconds_per_colour: float = DEFAULT_TRANSITION_SECONDS
@export_range(0.0, 1.0, 0.01) var colour_strength: float = 0.88
@export_range(0.0, 2.5, 0.05) var saturation_multiplier: float = 1.0
@export_range(0.0, 2.5, 0.05) var brightness_multiplier: float = 1.0

@export_category("Glow Matching")
@export_range(0.02, 0.50, 0.01) var update_interval: float = 0.08

@export_category("Target Nodes")
@export var sprite_path: NodePath = ^"../AnimatedSprite"
@export var glow_halo_path: NodePath = ^"../GlowHalo"
@export var point_light_path: NodePath = ^"../Bioluminescence"
@export var distance_activator_path: NodePath = ^"../DistanceActivator"

# Retained as storage-only fields so older scenes load without invalid-property
# warnings. They no longer control colour selection or random starting points.
@export_storage var fixed_overlay_number: int = 0
@export_storage var randomise_cycle_start: bool = false
@export_storage var seconds_per_overlay: float = 0.0
@export_storage var glow_saturation: float = 1.0
@export_storage var glow_value: float = 1.0

var _sprite: AnimatedSprite2D
var _glow_halo: Sprite2D
var _point_light: PointLight2D
var _distance_activator: Node
var _material: ShaderMaterial
var _active_colours: Array[Color] = []
var _current_index: int = 0
var _next_index: int = 0
var _transition_elapsed: float = 0.0
var _update_elapsed: float = 0.0
var _distance_active: bool = true
var _base_halo_alpha: float = 1.0
var _targets_resolved: bool = false


func _ready() -> void:
	_resolve_targets()
	_ensure_material()
	_rebuild_active_colours()
	_apply_static_shader_settings()

	if Engine.is_editor_hint():
		_apply_editor_preview()
		set_process(true)
		return

	_connect_distance_activation()
	_reset_runtime_sequence()
	_apply_current_transition()
	set_process(_should_cycle_at_runtime())


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_elapsed += maxf(0.0, delta)
		if _update_elapsed < maxf(0.02, update_interval):
			return
		_update_elapsed = 0.0
		_resolve_targets()
		_ensure_material()
		_rebuild_active_colours()
		_apply_static_shader_settings()
		_apply_editor_preview()
		return

	if not _should_cycle_at_runtime():
		return

	_transition_elapsed += maxf(0.0, delta)
	var duration: float = _get_transition_duration()
	while _transition_elapsed >= duration:
		_transition_elapsed -= duration
		_advance_colour_pair()

	_update_elapsed += maxf(0.0, delta)
	if _update_elapsed < maxf(0.02, update_interval):
		return
	_update_elapsed = fmod(_update_elapsed, maxf(0.02, update_interval))
	_apply_current_transition()


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	if Engine.is_editor_hint():
		set_process(true)
		return
	set_process(_should_cycle_at_runtime())


func _resolve_targets() -> void:
	if not is_inside_tree():
		return
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_glow_halo = get_node_or_null(glow_halo_path) as Sprite2D
	_point_light = get_node_or_null(point_light_path) as PointLight2D
	_distance_activator = get_node_or_null(distance_activator_path)
	if not _targets_resolved:
		_base_halo_alpha = _glow_halo.modulate.a if _glow_halo != null else 1.0
		_targets_resolved = true


func _ensure_material() -> void:
	if _sprite == null:
		return
	var existing: ShaderMaterial = _sprite.material as ShaderMaterial
	if (
			existing != null
			and existing.shader != null
			and existing.shader.resource_path == COLOUR_SHADER.resource_path
		):
		_material = existing
		return

	_material = ShaderMaterial.new()
	_material.resource_local_to_scene = true
	_material.shader = COLOUR_SHADER
	_sprite.material = _material


func _rebuild_active_colours() -> void:
	_active_colours.clear()
	_append_colour_if_used(colour_1)
	_append_colour_if_used(colour_2)
	_append_colour_if_used(colour_3)
	if _active_colours.is_empty():
		_active_colours.append(Color.WHITE)

	_current_index = clampi(_current_index, 0, _active_colours.size() - 1)
	_next_index = clampi(_next_index, 0, _active_colours.size() - 1)


func _append_colour_if_used(colour: Color) -> void:
	if colour.a > EMPTY_ALPHA_THRESHOLD:
		_active_colours.append(Color(colour.r, colour.g, colour.b, 1.0))


func _reset_runtime_sequence() -> void:
	_current_index = 0
	_transition_elapsed = 0.0
	_update_elapsed = 0.0
	if colour_mode == ColourMode.CYCLE and _active_colours.size() > 1:
		_next_index = 1
	else:
		_next_index = 0


func _advance_colour_pair() -> void:
	if _active_colours.size() <= 1:
		_current_index = 0
		_next_index = 0
		return

	_current_index = _next_index
	if _active_colours.size() == 2:
		_next_index = 1 - _current_index
	else:
		_next_index = (_current_index + 1) % _active_colours.size()


func _apply_editor_preview() -> void:
	if _material == null:
		return
	var preview_colour: Color = _active_colours[0] if not _active_colours.is_empty() else Color.WHITE
	_material.set_shader_parameter(&"tint_colour", preview_colour)
	_material.set_shader_parameter(
		&"colour_strength",
		0.0 if colour_mode == ColourMode.DISABLED else colour_strength,
	)
	_apply_glow_colour(preview_colour)


func _apply_current_transition() -> void:
	if _material == null or _active_colours.is_empty():
		return
	_apply_static_shader_settings()

	var current_colour: Color = _active_colours[_current_index]
	var next_colour: Color = _active_colours[_next_index]
	var blend: float = 0.0
	if colour_mode == ColourMode.CYCLE and _active_colours.size() > 1:
		blend = clampf(_transition_elapsed / _get_transition_duration(), 0.0, 1.0)
		blend = blend * blend * (3.0 - 2.0 * blend)

	var displayed_colour: Color = _interpolate_hsv(current_colour, next_colour, blend)
	_material.set_shader_parameter(&"tint_colour", displayed_colour)
	_apply_glow_colour(displayed_colour)


func _interpolate_hsv(from_colour: Color, to_colour: Color, weight: float) -> Color:
	var from_hue_angle: float = from_colour.h * TAU
	var to_hue_angle: float = to_colour.h * TAU
	var hue: float = fposmod(lerp_angle(from_hue_angle, to_hue_angle, weight) / TAU, 1.0)
	var saturation: float = lerpf(from_colour.s, to_colour.s, weight)
	var value: float = lerpf(from_colour.v, to_colour.v, weight)
	return Color.from_hsv(hue, saturation, value, 1.0)


func _apply_static_shader_settings() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(
		&"colour_strength",
		0.0 if colour_mode == ColourMode.DISABLED else colour_strength,
	)
	_material.set_shader_parameter(&"saturation_multiplier", saturation_multiplier)
	_material.set_shader_parameter(&"brightness_multiplier", brightness_multiplier)


func _apply_glow_colour(colour: Color) -> void:
	if colour_mode == ColourMode.DISABLED:
		return
	if _glow_halo != null:
		_glow_halo.modulate = Color(colour.r, colour.g, colour.b, _base_halo_alpha)
	if _point_light != null:
		_point_light.color = Color(colour.r, colour.g, colour.b, 1.0)


func _get_transition_duration() -> float:
	var requested_seconds: float = seconds_per_colour
	if (
			is_equal_approx(seconds_per_colour, DEFAULT_TRANSITION_SECONDS)
			and seconds_per_overlay > 0.0
		):
		requested_seconds = seconds_per_overlay
	return maxf(0.01, requested_seconds)


func _should_cycle_at_runtime() -> bool:
	return (
		colour_mode == ColourMode.CYCLE
		and _active_colours.size() > 1
		and _distance_active
	)


func _connect_distance_activation() -> void:
	if _distance_activator == null:
		return
	if _distance_activator.has_signal(&"activation_changed"):
		var callback := Callable(self, "_on_distance_activation_changed")
		if not _distance_activator.is_connected(&"activation_changed", callback):
			_distance_activator.connect(&"activation_changed", callback)
	if _distance_activator.has_method(&"is_distance_active"):
		_distance_active = bool(_distance_activator.call(&"is_distance_active"))


func _on_distance_activation_changed(is_active: bool) -> void:
	set_distance_active(is_active)
