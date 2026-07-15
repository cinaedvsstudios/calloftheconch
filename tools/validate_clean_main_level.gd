extends SceneTree

const MAIN_SCENE: String = "res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_main.tscn"
const PROTOTYPE_SCENE: String = "res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_prototype.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	await _validate_main_scene()
	_validate_prototype_scene()

	if _failures.is_empty():
		print("CLEAN_MAIN_LEVEL_VALIDATION_OK")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("CLEAN_MAIN_LEVEL_VALIDATION_FAILED count=%d" % _failures.size())
	quit(1)


func _load_scene(path: String) -> PackedScene:
	var scene: PackedScene = ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as PackedScene
	if scene == null:
		_failures.append("Could not load scene: %s" % path)
	return scene


func _validate_main_scene() -> void:
	var packed: PackedScene = _load_scene(MAIN_SCENE)
	if packed == null:
		return
	var level: Node = packed.instantiate()
	if level == null:
		_failures.append("Could not instantiate the clean main level.")
		return
	root.add_child(level)
	await process_frame

	for required_path: String in [
		"BackgroundLayer/sea gradient",
		"BackgroundLayer/sky gradient",
		"BackgroundLayer/horizon2",
		"BackgroundLayer/clouds/cloud effect",
		"ParallaxLayer/waterlines",
		"BubbleOverlayLayer/BubbleOverlay",
		"Hylas",
		"TriggersLayer/WaterlineMarker",
		"SpawnPoints/HylasStart",
		"SpawnPoints/WorldTopLeft",
		"SpawnPoints/WorldBottomRight",
	]:
		if level.get_node_or_null(required_path) == null:
			_failures.append("Clean main level is missing: %s" % required_path)

	var starter: Node = level.get_node_or_null("TerrainArtLayer/StarterTerrain")
	if starter == null:
		_failures.append("Clean main level is missing StarterTerrain.")
	else:
		for starter_name: String in ["Beach", "Rock", "Island"]:
			if starter.get_node_or_null(starter_name) == null:
				_failures.append("StarterTerrain is missing %s." % starter_name)
		if starter.get_child_count() != 3:
			_failures.append("StarterTerrain should contain exactly Beach, Rock and Island.")

	var enemies: Node = level.get_node_or_null("Enemies")
	if enemies == null or enemies.get_child_count() != 0:
		_failures.append("Clean main level Enemies container is not empty.")
	if level.get_node_or_null("BlackBloomHazard") != null:
		_failures.append("Clean main level still contains Black Bloom hazards.")
	if level.get_node_or_null("Citymain") == null:
		_failures.append("Clean main level is missing the hidden compatibility Citymain node.")
	else:
		var city: CanvasItem = level.get_node("Citymain") as CanvasItem
		if city != null and city.visible:
			_failures.append("Compatibility Citymain must remain hidden.")

	level.queue_free()
	await process_frame


func _validate_prototype_scene() -> void:
	var packed: PackedScene = _load_scene(PROTOTYPE_SCENE)
	if packed == null:
		return
	var prototype: Node = packed.instantiate()
	if prototype == null:
		_failures.append("Could not instantiate the populated prototype.")
		return
	if prototype.get_node_or_null("TerrainArtLayer/ground") == null:
		_failures.append("Prototype lost its populated ground hierarchy.")
	if prototype.get_node_or_null("Citymain") == null:
		_failures.append("Prototype lost its city artwork.")
	if prototype.get_node_or_null("BlackBloomHazard") == null:
		_failures.append("Prototype lost its hazard population.")
	var prototype_enemies: Node = prototype.get_node_or_null("Enemies")
	if prototype_enemies == null or prototype_enemies.get_child_count() == 0:
		_failures.append("Prototype enemy container is no longer populated.")
	prototype.free()
