class_name CotcLeafSheepPickup
extends Area2D

const ITEM_ID: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"
const PICKUP_INSTANCE_ID: StringName = &"pirate_ship_leaf_sheep_v3"

@export var auto_equip_on_collect: bool = true
@export var auto_activate_on_collect: bool = true
@export_range(0.05, 1.0, 0.05) var collect_fade_seconds: float = 0.35

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _light: PointLight2D = %PickupLight
@onready var _pickup_audio: AudioStreamPlayer2D = %PickupAudio

var _collecting: bool = false


func _ready() -> void:
	monitoring = true
	var game_state: CotcGameState = _resolve_game_state()
	if game_state == null:
		push_warning(
			"Leaf Sheep pickup is present, but GameState could not be resolved. "
			+ "Run the full game through FrontEnd rather than running the ship scene alone."
		)
		return
	if game_state.is_pickup_collected(PICKUP_INSTANCE_ID):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _collecting or body == null:
		return
	if not (body is CotcHylas) and not body.is_in_group(&"hylas"):
		return

	var game_state: CotcGameState = _resolve_game_state()
	if game_state == null:
		push_warning("Leaf Sheep pickup touched Hylas but could not find GameState.")
		return

	_collecting = true
	monitoring = false

	var granted: bool = (
		game_state.has_permanent_inventory_item(ITEM_ID)
		or game_state.grant_permanent_inventory_item(ITEM_ID)
	)
	if not granted:
		_fail_collection("Leaf Sheep pickup could not grant permanent ownership.")
		return

	if auto_equip_on_collect and not game_state.equip_item(ITEM_ID, ITEM_SLOT_B):
		_fail_collection("Leaf Sheep was granted but could not be equipped into Item B.")
		return

	var activated: bool = true
	if auto_activate_on_collect:
		activated = _activate_shared_companion(game_state)
	if not activated:
		_fail_collection(
			"Leaf Sheep was granted and equipped, but the shared companion could not activate."
		)
		return

	game_state.mark_pickup_collected(PICKUP_INSTANCE_ID)
	_play_collection_feedback()


func _fail_collection(message: String) -> void:
	_collecting = false
	monitoring = true
	push_warning(message)


func _resolve_game_state() -> CotcGameState:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var current_root: Node = tree.current_scene
	var direct_state: CotcGameState = current_root.get_node_or_null("GameState") as CotcGameState
	if direct_state != null:
		return direct_state
	return current_root.find_child("GameState", true, false) as CotcGameState


func _resolve_gameplay_context() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var direct_context: Node = tree.current_scene.get_node_or_null("GameplayContext")
	if direct_context != null:
		return direct_context
	return tree.current_scene.find_child("GameplayContext", true, false)


func _resolve_shared_companion() -> CotcLeafSheep:
	var gameplay_context: Node = _resolve_gameplay_context()
	if gameplay_context == null:
		return null
	var direct_companion: CotcLeafSheep = gameplay_context.get_node_or_null(
		"ItemEffectController/LeafSheep"
	) as CotcLeafSheep
	if direct_companion != null:
		return direct_companion
	return gameplay_context.find_child("LeafSheep", true, false) as CotcLeafSheep


func _activate_shared_companion(game_state: CotcGameState) -> bool:
	var companion: CotcLeafSheep = _resolve_shared_companion()
	if companion == null:
		push_warning("Leaf Sheep pickup could not find the canonical shared companion.")
		return false

	var gameplay_context: Node = _resolve_gameplay_context()
	var room_level: Node = get_parent()
	var room_hylas: CotcHylas = null
	if room_level != null and room_level.has_method(&"get_hylas"):
		room_hylas = room_level.call(&"get_hylas") as CotcHylas
	if not is_instance_valid(room_hylas):
		push_warning("Leaf Sheep pickup could not find the pirate-ship Hylas.")
		return false

	companion.configure(gameplay_context, room_level, room_hylas)
	companion.bind_game_state(game_state)
	companion.set_gameplay_active(true)
	if companion.is_active():
		return true
	return companion.toggle_activation()


func _play_collection_feedback() -> void:
	if is_instance_valid(_pickup_audio) and _pickup_audio.stream != null:
		_pickup_audio.play()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	if is_instance_valid(_sprite):
		tween.tween_property(_sprite, ^"modulate:a", 0.0, collect_fade_seconds)
		tween.tween_property(_sprite, ^"scale", _sprite.scale * 1.35, collect_fade_seconds)
	if is_instance_valid(_light):
		tween.tween_property(_light, ^"energy", 0.0, collect_fade_seconds)
	await tween.finished
	queue_free()
