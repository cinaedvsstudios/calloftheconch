class_name CotcDepthColourisation
extends Node

## Applies one of the ten JPEG colour maps to an AnimatedSprite2D while keeping
## the source frame alpha and luminance. Cycle mode crossfades continuously from
## one map to the next and keeps the visible halo and PointLight2D in sync.

enum ColourMode {
	DISABLED,
	FIXED,
	CYCLE,
}

const COLOUR_SHADER: Shader = preload(
	"res://rebuild_v3/features/depth_life/depth_colourisation.gdshader"
)
const COLOUR_MAPS: Array = [
	preload("res://assets/effects/coloroverlay01.jpg"),
	preload("res://assets/effects/coloroverlay02.jpg"),
	preload("res://assets/effects/coloroverlay03.jpg"),
	preload("res://assets/effects/coloroverlay04.jpg"),
	preload("res://assets/effects/coloroverlay05.jpg"),
	preload("res://assets/effects/coloroverlay06.jpg"),
	preload("res://assets/effects/coloroverlay07.jpg"),
	preload("res://assets/effects/coloroverlay08.jpg"),
	preload("res://assets/effects/coloroverlay09.jpg"),
	preload("res://assets/effects/coloroverlay10.jpg"),
]

@export_category("Colourisation")
@export_enum("Disabled", "Fixed", "Cycle") var colour_mode: int = ColourMode.DISABLED
@export_range(1, 10, 1) var fixed_overlay_number: int = 1
@export var randomise_cycle_start: bool = true
@export_range(1.0, 120.0, 0.5) var seconds_per_overlay: float = 10.0
@export_range(0.0, 1.0, 0.01) var colour_strength: float = 0.88
@export_range(0.0, 2.5, 0.05) var saturation_multiplier: float = 1.0
@export_range(0.0, 2.5, 0.05) var brightness_multiplier: float = 1.0

@export_category("Glow Matching")
@export_range(0.0, 1.0, 0.01) var glow_saturation: float = 0.92
@export_range(0.0, 2.0, 0.01) var glow_value: float = 1.0
@export_range(0.02, 0.50, 0.01) var update_interval: float = 0.10

@export_category("Target Nodes")
@export var sprite_path: NodePath = ^"../AnimatedSprite"
@export var glow_halo_path: NodePath = ^"../GlowHalo"
@export var point_light_path: NodePath = ^"../Bioluminescence"
@export var distance_activator_path: NodePath = ^"../DistanceActivator"

var _sprite: AnimatedSprite2D
var _glow_halo: Sprite2D
var _point_light: PointLight2D
var _distance_activator: Node
var _material: ShaderMaterial
var _current_index: int = 0
var _next_index: int = 1
var _transition_elapsed: float = 0.0
var _update_elapsed: float = 0.0
var _distance_active: bool = true
var _base_halo_alpha: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_glow_halo = get_node_or_null(glow_halo_path) as Sprite2D
	_point_light = get_node_or_null(point_light_path) as PointLight2D
	_distance_activator = get_node_or_null(distance_activator_path)

	if colour_mode == ColourMode.DISABLED:
		set_process(false)
		return
	if _sprite == null:
		push_error("CotcDepthColourisation requires an AnimatedSprite2D target.")
		set_process(false)
		return

	_base_halo_alpha = _glow_halo.modulate.a if _glow_halo != null else 1.0
	_material = ShaderMaterial.new()
	_material.shader = COLOUR_SHADER
	_sprite.material = _material
	_apply_static_shader_settings()
	_configure_starting_overlay()
	_connect_distance_activation()
	_refresh_overlay_bindings()
	_apply_transition_colour()
	set_process(colour_mode == ColourMode.CYCLE and _distance_active)


func _process(delta: float) -> void:
	if colour_mode != ColourMode.CYCLE or not _distance_active:
		return
	_transition_elapsed += maxf(0.0, delta)
	var duration: float = maxf(0.01, seconds_per_overlay)
	while _transition_elapsed >= duration:
		_transition_elapsed -= duration
		_current_index = _next_index
		_next_index = (_current_index + 1) % COLOUR_MAPS.size()
		_refresh_overlay_bindings()

	_update_elapsed += maxf(0.0, delta)
	if _update_elapsed < update_interval:
		return
	_update_elapsed = fmod(_update_elapsed, maxf(0.02, update_interval))
	_apply_transition_colour()


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	set_process(colour_mode == ColourMode.CYCLE and _distance_active)


func _configure_starting_overlay() -> void:
	if colour_mode == ColourMode.FIXED:
		_current_index = clampi(fixed_overlay_number - 1, 0, COLOUR_MAPS.size() - 1)
		_next_index = _current_index
		_transition_elapsed = 0.0
		return

	_rng.seed = hash(str(get_path()))
	if randomise_cycle_start:
		_current_index = _rng.randi_range(0, COLOUR_MAPS.size() - 1)
		_transition_elapsed = _rng.randf_range(0.0, maxf(0.01, seconds_per_overlay))
	else:
		_current_index = 0
		_transition_elapsed = 0.0
	_next_index = (_current_index + 1) % COLOUR_MAPS.size()


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


func _apply_static_shader_settings() -> void:
	_material.set_shader_parameter(&"colour_strength", colour_strength)
	_material.set_shader_parameter(&"saturation_multiplier", saturation_multiplier)
	_material.set_shader_parameter(&"brightness_multiplier", brightness_multiplier)


func _refresh_overlay_bindings() -> void:
	_material.set_shader_parameter(&"colour_map_a", COLOUR_MAPS[_current_index])
	_material.set_shader_parameter(&"colour_map_b", COLOUR_MAPS[_next_index])


func _apply_transition_colour() -> void:
	var blend: float = 0.0
	if colour_mode == ColourMode.CYCLE:
		blend = clampf(
			_transition_elapsed / maxf(0.01, seconds_per_overlay),
			0.0,
			1.0,
		)
	_material.set_shader_parameter(&"map_blend", blend)
	_apply_glow_colour(_interpolated_hue_colour(blend))


func _interpolated_hue_colour(blend: float) -> Color:
	var map_count: float = float(COLOUR_MAPS.size())
	var current_hue: float = float(_current_index) / map_count
	var next_hue: float = float(_next_index) / map_count
	var interpolated_angle: float = lerp_angle(current_hue * TAU, next_hue * TAU, blend)
	var hue: float = fposmod(interpolated_angle / TAU, 1.0)
	return Color.from_hsv(
		hue,
		clampf(glow_saturation, 0.0, 1.0),
		clampf(glow_value, 0.0, 2.0),
	)


func _apply_glow_colour(colour: Color) -> void:
	if _glow_halo != null:
		_glow_halo.modulate = Color(colour.r, colour.g, colour.b, _base_halo_alpha)
	if _point_light != null:
		_point_light.color = Color(colour.r, colour.g, colour.b, 1.0)
