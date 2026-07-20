class_name CotcPirateShipCoordinator
extends Node

## Owns the local transition between the active Sea of Pillars level and the
## pirate-ship interior. The exterior level stays instantiated, so returning
## restores Hylas to the exact position and facing direction used on entry.

const INTERIOR_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/sea_of_pillars/levels/pirate_ship_interior.tscn"
)
const PIRATE_SHIP_GROUP: StringName = &"pirate_ship"
const HYLAS_GROUP: StringName = &"hylas"

@export_category("Context Nodes")
@export var level_path: NodePath = ^"../SeaOfPillars"
@export var environment_path: NodePath = ^"../SeaEnvironment"
@export var hud_path: NodePath = ^"../GameplayUI/GameplayHud"
@export var music_path: NodePath = ^"../GameplayMusic"
@export var tutorial_path: NodePath = ^"../CuttlefishTutorial"

@export_category("Return")
@export_range(0.0, 4.0, 0.05) var return_interaction_cooldown: float = 0.85

var _gameplay_context: Node
var _level: Node
var _environment: CanvasItem
var _hud: Node
var _music: AudioStreamPlayer
var _tutorial: Node
var _interior: CotcPirateShipInterior
var _active_entry: CotcPirateShipEntry
var _return_position: Vector2 = Vector2.ZERO
var _return_facing_left: bool = false
var _transition_active: bool = false
var _bound_entries: Array[CotcPirateShipEntry] = []


func _ready() -> void:
	_gameplay_context = get_parent()
	_environment = get_node_or_null(environment_path) as CanvasItem
	_hud = get_node_or_null(hud_path)
	_music = get_node_or_null(music_path) as AudioStreamPlayer
	_tutorial = get_node_or_null(tutorial_path)
	if _gameplay_context != null:
		if not _gameplay_context.child_entered_tree.is_connected(_on_context_child_changed):
			_gameplay_context.child_entered_tree.connect(_on_context_child_changed)
		if not _gameplay_context.child_exiting_tree.is_connected(_on_context_child_changed):
			_gameplay_context.child_exiting_tree.connect(_on_context_child_changed)
	call_deferred(&"_bind_current_level")


func _exit_tree() -> void:
	_disconnect_entries()


func _on_context_child_changed(_child: Node) -> void:
	call_deferred(&"_bind_current_level")


func _bind_current_level() -> void:
	var candidate: Node = get_node_or_null(level_path)
	if candidate == _level and not _bound_entries.is_empty():
		return
	_disconnect_entries()
	_level = candidate
	if _level == null:
		return
	for node: Node in get_tree().get_nodes_in_group(PIRATE_SHIP_GROUP):
		if not _level.is_ancestor_of(node):
			continue
		var entry: CotcPirateShipEntry = node as CotcPirateShipEntry
		if entry == null:
			continue
		var callback: Callable = Callable(self, "_on_interior_requested").bind(entry)
		if not entry.interior_requested.is_connected(callback):
			entry.interior_requested.connect(callback)
		_bound_entries.append(entry)


func _disconnect_entries() -> void:
	for entry: CotcPirateShipEntry in _bound_entries:
		if not is_instance_valid(entry):
			continue
		var callback: Callable = Callable(self, "_on_interior_requested").bind(entry)
		if entry.interior_requested.is_connected(callback):
			entry.interior_requested.disconnect(callback)
	_bound_entries.clear()


func _on_interior_requested(
		return_position: Vector2,
		facing_left: bool,
		entry: CotcPirateShipEntry,
	) -> void:
	if _transition_active or not is_instance_valid(entry) or not is_instance_valid(_level):
		return
	if _gameplay_context != null and _gameplay_context.has_method(&"is_game_active"):
		if not bool(_gameplay_context.call(&"is_game_active")):
			entry.cancel_entry_transition()
			return

	_transition_active = true
	_active_entry = entry
	_return_position = return_position
	_return_facing_left = facing_left
	_disable_open_sea_systems()

	_level.call(&"deactivate")
	if is_instance_valid(_environment):
		_environment.hide()
	if is_instance_valid(_music):
		_music.stop()

	var interior_instance: Node = INTERIOR_SCENE.instantiate()
	_interior = interior_instance as CotcPirateShipInterior
	if _interior == null:
		push_error("Pirate ship interior scene does not use CotcPirateShipInterior.")
		entry.cancel_entry_transition()
		_restore_open_sea_after_failed_entry()
		return

	_gameplay_context.add_child(_interior)
	_interior.exit_requested.connect(_on_interior_exit_requested)
	_interior.activate()
	_set_hud_location("Pirate Shipwreck")


func _on_interior_exit_requested() -> void:
	if not _transition_active or not is_instance_valid(_interior):
		return
	if not is_instance_valid(_level):
		_bind_current_level()
	if not is_instance_valid(_level):
		push_error("Cannot return from pirate ship because the Sea of Pillars level is missing.")
		return

	if is_instance_valid(_active_entry):
		_active_entry.prepare_return_from_interior(return_interaction_cooldown)

	if is_instance_valid(_environment):
		_environment.show()
	_activate_level_at_return_position()
	_restore_open_sea_systems()
	_set_hud_location("The Sea of Pillars")

	_interior.complete_exit_transition()
	await _interior.transition_finished
	if is_instance_valid(_interior):
		_interior.queue_free()
	_interior = null
	_active_entry = null
	_transition_active = false


func _activate_level_at_return_position() -> void:
	var spawn_point_id: StringName = &""
	var game_state: Object = null
	if _gameplay_context != null:
		game_state = _gameplay_context.get("_game_state") as Object
	if game_state != null:
		var stored_spawn: Variant = game_state.get("current_spawn_point_id")
		if stored_spawn != null:
			spawn_point_id = StringName(str(stored_spawn))

	_level.call(&"activate", spawn_point_id)
	var sea_hylas: CotcHylas = _find_level_hylas()
	if sea_hylas == null:
		push_error("Sea of Pillars Hylas was not found after leaving the pirate ship.")
		return
	sea_hylas.velocity = Vector2.ZERO
	sea_hylas.reset_to_start(_return_position)
	var sprite: AnimatedSprite2D = sea_hylas.get_node_or_null(^"AnimatedSprite") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = _return_facing_left
	var camera: Camera2D = sea_hylas.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
	sea_hylas.set_play_enabled(true)


func _find_level_hylas() -> CotcHylas:
	for candidate: Node in get_tree().get_nodes_in_group(HYLAS_GROUP):
		if _level.is_ancestor_of(candidate):
			return candidate as CotcHylas
	return null


func _disable_open_sea_systems() -> void:
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"deactivate"):
		_tutorial.call(&"deactivate")
	if _gameplay_context != null:
		if _gameplay_context.has_method(&"_force_deactivate_leaf_sheep"):
			_gameplay_context.call(&"_force_deactivate_leaf_sheep", &"pirate_ship")
		if _gameplay_context.has_method(&"_set_leaf_sheep_gameplay_active"):
			_gameplay_context.call(&"_set_leaf_sheep_gameplay_active", false)


func _restore_open_sea_systems() -> void:
	if is_instance_valid(_music):
		_music.play()
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"activate"):
		_tutorial.call(&"activate")
	if _gameplay_context != null and _gameplay_context.has_method(
			&"_set_leaf_sheep_gameplay_active"
		):
		_gameplay_context.call(&"_set_leaf_sheep_gameplay_active", true)


func _restore_open_sea_after_failed_entry() -> void:
	if is_instance_valid(_environment):
		_environment.show()
	if is_instance_valid(_level):
		_level.call(&"activate")
	_restore_open_sea_systems()
	_active_entry = null
	_transition_active = false


func _set_hud_location(location_name: String) -> void:
	if is_instance_valid(_hud) and _hud.has_method(&"set_location"):
		_hud.call(&"set_location", location_name)


func get_debug_lines() -> Array[String]:
	return [
		"[PirateShipCoordinator]",
		"transition_active=%s" % str(_transition_active),
		"interior_active=%s" % str(is_instance_valid(_interior)),
		"bound_entries=%d" % _bound_entries.size(),
		"return_position=%s" % str(_return_position),
	]
