class_name CotcPlantForegroundOverlap
extends Node

## Keeps plant artwork in front of Hylas while making only the pixels directly
## covering his body slightly transparent.

const OVERLAP_SHADER: Shader = preload(
	"res://rebuild_v3/features/plant_foreground/plant_hylas_overlap.gdshader"
)
const COLOURISATION_SHADER_PATH: String = (
	"res://rebuild_v3/features/depth_life/depth_colourisation.gdshader"
)
const HYLAS_GROUP: StringName = &"hylas"

@export_category("Foreground")
@export var target_path: NodePath = ^".."
@export_range(-4096, 4096, 1) var foreground_z_index: int = 8

@export_category("Hylas Overlap")
@export_range(0.0, 1.0, 0.05) var overlap_opacity: float = 0.8
@export var hylas_half_size: Vector2 = Vector2(92.0, 55.0)
@export_range(0.0, 0.5, 0.01) var edge_softness: float = 0.12

var _target: CanvasItem
var _hylas: Node2D
var _hylas_visual: Node2D
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_target = get_node_or_null(target_path) as CanvasItem
	if _target == null:
		push_warning("Plant foreground overlap could not resolve its target CanvasItem.")
		set_process(false)
		return

	_target.z_as_relative = false
	_target.z_index = maxi(_target.z_index, foreground_z_index)
	_collect_visuals(_target)
	_resolve_hylas()
	set_process(not _materials.is_empty())


func _process(_delta: float) -> void:
	if not is_instance_valid(_hylas):
		_resolve_hylas()
	if not is_instance_valid(_hylas):
		return

	var anchor_position: Vector2 = _hylas.global_position
	var anchor_rotation: float = _hylas.global_rotation
	if is_instance_valid(_hylas_visual):
		anchor_position = _hylas_visual.global_position
		anchor_rotation = _hylas_visual.global_rotation

	for material: ShaderMaterial in _materials:
		if not is_instance_valid(material):
			continue
		material.set_shader_parameter(&"hylas_world_position", anchor_position)
		material.set_shader_parameter(&"hylas_half_size", hylas_half_size)
		material.set_shader_parameter(&"hylas_world_rotation", anchor_rotation)


func _collect_visuals(node: Node) -> void:
	if node is Sprite2D or node is AnimatedSprite2D:
		_register_visual(node as CanvasItem)
	for child: Node in node.get_children():
		_collect_visuals(child)


func _register_visual(visual: CanvasItem) -> void:
	var shader_material: ShaderMaterial = visual.material as ShaderMaterial
	if shader_material == null:
		if visual.material != null:
			# Preserve additive and other specialised non-shader materials.
			return
		shader_material = ShaderMaterial.new()
		shader_material.shader = OVERLAP_SHADER
		visual.material = shader_material
	elif not _supports_overlap(shader_material):
		return

	if _materials.has(shader_material):
		return
	shader_material.set_shader_parameter(&"overlap_opacity", overlap_opacity)
	shader_material.set_shader_parameter(&"edge_softness", edge_softness)
	shader_material.set_shader_parameter(&"hylas_half_size", hylas_half_size)
	_materials.append(shader_material)


func _supports_overlap(material: ShaderMaterial) -> bool:
	if material.shader == null:
		return false
	return (
		material.shader == OVERLAP_SHADER
		or material.shader.resource_path == COLOURISATION_SHADER_PATH
	)


func _resolve_hylas() -> void:
	_hylas = null
	_hylas_visual = null
	for candidate: Node in get_tree().get_nodes_in_group(HYLAS_GROUP):
		var candidate_2d: Node2D = candidate as Node2D
		if candidate_2d == null or not candidate_2d.is_inside_tree():
			continue
		_hylas = candidate_2d
		_hylas_visual = candidate_2d.get_node_or_null("AnimatedSprite") as Node2D
		if _hylas_visual == null:
			_hylas_visual = candidate_2d
		return
