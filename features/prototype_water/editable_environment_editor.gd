@tool
class_name EditableEnvironmentEditor
extends RefCounted

const TILE_WIDTH: float = 2560.0
const TILE_COUNT: int = 3
const ART_SCALE: Vector2 = Vector2(2.56, 2.56)
const SKY_Y: float = -2427.52
const LOWER_ART_Y: float = 1760.0

const WATER_SKY_PATH: String = "res://assets/backgrounds/waterskybg.jpg"
const DEEP_WATER_PATH: String = "res://assets/backgrounds/waterbg.jpg"
const PARALLAX_PATH: String = "res://assets/backgrounds/waterbgparalax.webp"
const MOUNTAIN_A_PATH: String = "res://assets/backgrounds/mountainoverlay01.webp"
const MOUNTAIN_B_PATH: String = "res://assets/backgrounds/mountainoverlay03.webp"
const SAND_PATH: String = "res://assets/backgrounds/sandoverlay.webp"


static func ensure_scene_art(world: Node, water_layer: Node2D, scenery_layer: Node2D, foreground_layer: Node2D) -> void:
	if world == null or water_layer == null or scenery_layer == null or foreground_layer == null:
		return
	var scene_owner: Node = world
	for tile_index: int in range(TILE_COUNT):
		var x: float = TILE_WIDTH * float(tile_index)
		_ensure_sprite(water_layer, "WaterSky%02d" % (tile_index + 1), WATER_SKY_PATH, Vector2(x, SKY_Y), -30, true, null, scene_owner)
		_ensure_sprite(water_layer, "DeepWater%02d" % (tile_index + 1), DEEP_WATER_PATH, Vector2(x, LOWER_ART_Y), -30, true, null, scene_owner)
		_ensure_sprite(water_layer, "LowerWaterParallax%02d" % (tile_index + 1), PARALLAX_PATH, Vector2(x, LOWER_ART_Y), -20, false, _create_multiply_material(), scene_owner)
		var mountain_path: String = MOUNTAIN_A_PATH if tile_index % 2 == 0 else MOUNTAIN_B_PATH
		_ensure_sprite(scenery_layer, "MountainOverlay%02d" % (tile_index + 1), mountain_path, Vector2(x, LOWER_ART_Y), 0, true, null, scene_owner)
		_ensure_sprite(foreground_layer, "SandOverlay%02d" % (tile_index + 1), SAND_PATH, Vector2(x, LOWER_ART_Y), 20, true, null, scene_owner)
	_ensure_collision_layer(world, scene_owner)


static func has_scene_art(water_layer: Node2D) -> bool:
	return water_layer != null and water_layer.has_node("WaterSky01") and water_layer.has_node("DeepWater01")


static func get_scene_sprites(parent: Node2D, prefix: String) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if parent == null:
		return sprites
	for child: Node in parent.get_children():
		if child is Sprite2D and child.name.begins_with(prefix):
			sprites.append(child as Sprite2D)
	return sprites


static func _ensure_sprite(parent: Node2D, node_name: String, texture_path: String, position_value: Vector2, z_index_value: int, is_visible: bool, material: Material, scene_owner: Node) -> void:
	var sprite: Sprite2D = parent.get_node_or_null(NodePath(node_name)) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = node_name
		parent.add_child(sprite)
		sprite.owner = scene_owner
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	sprite.texture = texture
	sprite.centered = false
	sprite.position = position_value
	sprite.scale = ART_SCALE
	sprite.z_index = z_index_value
	sprite.visible = is_visible
	sprite.material = material


static func _ensure_collision_layer(world: Node, scene_owner: Node) -> void:
	if world.has_node("TerrainCollisionLayer"):
		return
	var collision_layer: Node2D = Node2D.new()
	collision_layer.name = "TerrainCollisionLayer"
	world.add_child(collision_layer)
	collision_layer.owner = scene_owner


static func _create_multiply_material() -> CanvasItemMaterial:
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	return material
