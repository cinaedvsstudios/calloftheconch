class_name PrototypeWater
extends Node2D
## Layered open-water movement test with direct tiled world layers and alpha-shaped mountain collision.
## Direct tiles are used here deliberately: the base world must remain visible even while parallax tuning evolves.

const VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const ENVIRONMENT_TILE_SIZE: Vector2 = Vector2(2560.0, 2160.0)
const MINIMUM_HORIZONTAL_TILES: int = 1
const MAXIMUM_HORIZONTAL_TILES: int = 9
const MOUNTAIN_ALPHA_THRESHOLD: float = 0.10
const MOUNTAIN_COLLISION_SIMPLIFY_EPSILON: float = 4.0
const SURFACE_WATERLINE_FROM_BOTTOM: float = 100.0
const SPLASH_OPACITY: float = 0.65
const SPLASH_FRAME_DURATION: float = 0.08

@onready var _water_layer: Node2D = %WaterLayer
@onready var _scenery_layer: Node2D = %SceneryLayer
@onready var _foreground_layer: Node2D = %ForegroundLayer
@onready var _hylas: HylasController = %Hylas
@onready var _conch_pulse: ConchPulse = %ConchPulse
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay

var _tuning: PrototypeTuning = PrototypeTuning.new()
var _world_size: Vector2 = VIEWPORT_SIZE
var _has_built_world: bool = false
var _surface_waterline_y: float = 0.0
var _surface_splash: AnimatedSprite2D


func _ready() -> void:
	_hylas.bind_tuning(_tuning)
	_hylas.normal_conch_used.connect(_on_normal_conch_used)
	_hylas.surface_splash_requested.connect(_on_surface_splash_requested)
	_ensure_surface_splash_player()
	_build_world()
	_bubble_overlay.hide()
	set_process(false)


func activate() -> void:
	if not _has_built_world:
		_build_world()
	_hylas.reset_to_start()
	_hylas.set_play_enabled(true)
	_bubble_overlay.show()
	show()
	set_process(true)


func deactivate() -> void:
	_hylas.set_play_enabled(false)
	_bubble_overlay.hide()
	_conch_pulse.hide()
	if is_instance_valid(_surface_splash):
		_surface_splash.hide()
	set_process(false)
	hide()


func get_diagnostic_summary() -> String:
	return "World: %.0f x %.0f | Environment chunks: %d | Surface Y: %.0f | Far water setting: %.2f | Lower water setting: %.2f | %s" % [
		_world_size.x,
		_world_size.y,
		_get_horizontal_tile_count(),
		_surface_waterline_y,
		_tuning.water_parallax_scroll_scale,
		_tuning.lower_water_parallax_scroll_scale,
		_hylas.get_diagnostic_summary(),
	]


func get_tuning_value(key: StringName) -> float:
	return _tuning.get_value(key)


func set_tuning_value(key: StringName, value: float) -> void:
	_tuning.set_value(key, value)
	if _requires_world_rebuild(key):
		_rebuild_world()
	else:
		_hylas.refresh_tuning()


func reset_tuning_defaults() -> void:
	_tuning.reset_defaults()
	_hylas.refresh_tuning()
	_rebuild_world()


func get_tuning_export_dictionary() -> Dictionary:
	return _tuning.to_export_dictionary()


func _build_world() -> void:
	if _has_built_world:
		return
	_has_built_world = true
	_world_size = Vector2(ENVIRONMENT_TILE_SIZE.x * float(_get_horizontal_tile_count()), ENVIRONMENT_TILE_SIZE.y * 2.0)
	_surface_waterline_y = ENVIRONMENT_TILE_SIZE.y - SURFACE_WATERLINE_FROM_BOTTOM

	_build_surface_sky_tiles()
	_build_deep_water_tiles()
	_build_lower_water_overlay()
	_build_mountain_overlays()
	_build_sand_foreground()
	_hylas.configure_world(
		_world_size,
		Vector2(_world_size.x * 0.5, ENVIRONMENT_TILE_SIZE.y + 360.0),
		_surface_waterline_y,
	)


func _rebuild_world() -> void:
	_clear_children(_water_layer)
	_clear_children(_scenery_layer)
	_clear_children(_foreground_layer)
	if is_instance_valid(_surface_splash):
		_surface_splash.hide()
	_has_built_world = false
	_build_world()
	_hylas.reset_to_start()


func _build_surface_sky_tiles() -> void:
	var surface_texture: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.WATER_SKY_BACKGROUND_CANDIDATES)
	if surface_texture == null:
		return
	for tile_index: int in range(_get_horizontal_tile_count()):
		var tile_origin: Vector2 = Vector2(ENVIRONMENT_TILE_SIZE.x * float(tile_index), 0.0)
		_add_bottom_anchored_sprite(_water_layer, surface_texture, tile_origin, -30, null)


func _build_deep_water_tiles() -> void:
	var water_texture: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.WATER_BACKGROUND_CANDIDATES)
	if water_texture == null:
		_build_fallback_background()
		return
	for tile_index: int in range(_get_horizontal_tile_count()):
		var tile_origin: Vector2 = Vector2(ENVIRONMENT_TILE_SIZE.x * float(tile_index), ENVIRONMENT_TILE_SIZE.y)
		_add_bottom_anchored_sprite(_water_layer, water_texture, tile_origin, -30, null)


func _build_lower_water_overlay() -> void:
	var lower_water_texture: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.WATER_PARALLAX_OVERLAY_CANDIDATES)
	if lower_water_texture == null:
		return
	var multiply_material: CanvasItemMaterial = CanvasItemMaterial.new()
	multiply_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	for tile_index: int in range(_get_horizontal_tile_count()):
		var tile_origin: Vector2 = Vector2(ENVIRONMENT_TILE_SIZE.x * float(tile_index), ENVIRONMENT_TILE_SIZE.y)
		_add_bottom_anchored_sprite(_water_layer, lower_water_texture, tile_origin, -20, multiply_material)


func _build_mountain_overlays() -> void:
	var mountain_textures: Array[Texture2D] = []
	var mountain_one: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.MOUNTAIN_OVERLAY_01_CANDIDATES)
	var mountain_three: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.MOUNTAIN_OVERLAY_03_CANDIDATES)
	if mountain_one != null:
		mountain_textures.append(mountain_one)
	if mountain_three != null:
		mountain_textures.append(mountain_three)
	if mountain_textures.is_empty():
		return

	for tile_index: int in range(_get_horizontal_tile_count()):
		var texture: Texture2D = mountain_textures[tile_index % mountain_textures.size()]
		var tile_origin: Vector2 = Vector2(ENVIRONMENT_TILE_SIZE.x * float(tile_index), ENVIRONMENT_TILE_SIZE.y)
		var mountain_sprite: Sprite2D = _add_bottom_anchored_sprite(_scenery_layer, texture, tile_origin, 0, null)
		_create_alpha_collision(mountain_sprite, texture)


func _build_sand_foreground() -> void:
	var sand_texture: Texture2D = PrototypeAssets.load_texture(PrototypeAssets.SAND_OVERLAY_CANDIDATES)
	if sand_texture == null:
		return
	for tile_index: int in range(_get_horizontal_tile_count()):
		var tile_origin: Vector2 = Vector2(ENVIRONMENT_TILE_SIZE.x * float(tile_index), ENVIRONMENT_TILE_SIZE.y)
		_add_bottom_anchored_sprite(_foreground_layer, sand_texture, tile_origin, 20, null)


func _build_fallback_background() -> void:
	var fallback: Polygon2D = Polygon2D.new()
	fallback.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(_world_size.x, 0.0),
		_world_size,
		Vector2(0.0, _world_size.y),
	])
	fallback.color = Color(0.02, 0.19, 0.27, 1.0)
	fallback.z_index = -30
	_water_layer.add_child(fallback)


func _add_bottom_anchored_sprite(
	parent: Node,
	texture: Texture2D,
	tile_origin: Vector2,
	z_index_value: int,
	material_override: Material,
) -> Sprite2D:
	var texture_width: float = maxf(1.0, float(texture.get_width()))
	var scale_factor: float = ENVIRONMENT_TILE_SIZE.x / texture_width
	var scaled_height: float = float(texture.get_height()) * scale_factor
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = tile_origin + Vector2(0.0, ENVIRONMENT_TILE_SIZE.y - scaled_height)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.z_index = z_index_value
	sprite.material = material_override
	parent.add_child(sprite)
	return sprite


func _create_alpha_collision(mountain_sprite: Sprite2D, texture: Texture2D) -> void:
	var image: Image = texture.get_image()
	if image == null:
		return

	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, MOUNTAIN_ALPHA_THRESHOLD)
	var image_rect: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	var polygons: Array = bitmap.opaque_to_polygons(image_rect, MOUNTAIN_COLLISION_SIMPLIFY_EPSILON)
	if polygons.is_empty():
		return

	var static_body: StaticBody2D = StaticBody2D.new()
	static_body.name = "MountainCollision"
	static_body.position = mountain_sprite.position
	_scenery_layer.add_child(static_body)

	for polygon_variant: Variant in polygons:
		if not (polygon_variant is PackedVector2Array):
			continue
		var source_polygon: PackedVector2Array = polygon_variant
		if source_polygon.size() < 3:
			continue
		var collision_points: PackedVector2Array = PackedVector2Array()
		for source_point: Vector2 in source_polygon:
			collision_points.append(source_point * mountain_sprite.scale)
		var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
		collision_polygon.polygon = collision_points
		static_body.add_child(collision_polygon)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.queue_free()


func _requires_world_rebuild(key: StringName) -> bool:
	return key in [
		&"water_horizontal_tiles",
		&"water_parallax_scroll_scale",
		&"lower_water_parallax_scroll_scale",
	]


func _get_horizontal_tile_count() -> int:
	return clampi(int(_tuning.water_horizontal_tiles), MINIMUM_HORIZONTAL_TILES, MAXIMUM_HORIZONTAL_TILES)


func _on_normal_conch_used(origin: Vector2, facing_left: bool) -> void:
	_conch_pulse.trigger(origin, facing_left, _tuning)


func _ensure_surface_splash_player() -> void:
	if is_instance_valid(_surface_splash):
		return
	var splash_frames: Array[Texture2D] = _load_surface_splash_frames()
	if splash_frames.is_empty():
		return

	var frames: SpriteFrames = SpriteFrames.new()
	if not frames.has_animation(&"default"):
		frames.add_animation(&"default")
	frames.set_animation_speed(&"default", 1.0 / SPLASH_FRAME_DURATION)
	frames.set_animation_loop(&"default", false)
	for texture: Texture2D in splash_frames:
		frames.add_frame(&"default", texture, 1.0)

	_surface_splash = AnimatedSprite2D.new()
	_surface_splash.name = "SurfaceSplash"
	_surface_splash.sprite_frames = frames
	_surface_splash.animation = &"default"
	_surface_splash.centered = true
	_surface_splash.z_index = 9
	_surface_splash.modulate.a = SPLASH_OPACITY
	_surface_splash.hide()
	add_child(_surface_splash)


func _load_surface_splash_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_number: int in range(1, 6):
		var candidates: PackedStringArray = [
			"res://assets/effects/splash%d.webp" % frame_number,
			"res://assets/effects/splash%d.png" % frame_number,
			"res://assets/effects/splash_%02d.webp" % frame_number,
			"res://assets/effects/splash_%02d.png" % frame_number,
		]
		for path: String in candidates:
			if not ResourceLoader.exists(path):
				continue
			var resource: Resource = load(path)
			if resource is Texture2D:
				frames.append(resource as Texture2D)
				break
	return frames


func _on_surface_splash_requested(origin: Vector2) -> void:
	_ensure_surface_splash_player()
	if not is_instance_valid(_surface_splash):
		return
	_surface_splash.global_position = origin
	_surface_splash.frame = 0
	_surface_splash.show()
	_surface_splash.play(&"default")
	var duration: float = float(_surface_splash.sprite_frames.get_frame_count(&"default")) * SPLASH_FRAME_DURATION
	var hide_timer: SceneTreeTimer = get_tree().create_timer(maxf(SPLASH_FRAME_DURATION, duration), true)
	hide_timer.timeout.connect(_hide_surface_splash)


func _hide_surface_splash() -> void:
	if is_instance_valid(_surface_splash):
		_surface_splash.hide()
