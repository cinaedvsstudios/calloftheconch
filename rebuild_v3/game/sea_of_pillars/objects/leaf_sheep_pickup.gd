class_name CotcLeafSheepPickup
extends Area2D

const ITEM_ID: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"
## Versioned once because the first ship-pickup build could silently remove the
## collectible from existing test saves before it had ever worked correctly.
const PICKUP_INSTANCE_ID: StringName = &"pirate_ship_leaf_sheep_v2"

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
	# Ownership alone no longer removes the physical ship pickup. This lets old
	# developer/test saves still collect the correctly wired version once.
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
		_collecting = false
		monitoring = true
		push_warning("Leaf Sheep pickup could not grant permanent ownership.")
		return

	var equipped: bool = true
	if auto_equip_on_collect:
		equipped = game_state.equip_item(ITEM_ID, ITEM_SLOT_B)
	if not equipped:
		_collecting = false
		monitoring = true
		push_warning("Leaf Sheep was granted but could not be equipped into Item B.")
		return

	game_state.mark_pickup_collected(PICKUP_INSTANCE_ID)
	var activated: bool = true
	if auto_activate_on_collect:
		activated = _activate_leaf_sheep_companion()
	if not activated:
		push_warning(
			"Leaf Sheep was collected and equipped, but immediate activation failed. "
			+ "Use Item B once and check the Developer/Admin Leaf Sheep diagnostics."
		)
	_play_collection_feedback()


func _resolve_game_state() -> CotcGameState:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var current_root: Node = tree.current_scene
	var direct_state: CotcGameState = current_root.get_node_or_null("GameState") as CotcGameState
	if direct_state != null:
		return direct_state
	return current_root.find_child("GameState", true, false) as CotcGameState


func _resolve_item_controller() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var current_root: Node = tree.current_scene
	var direct_controller: Node = current_root.get_node_or_null(
		"GameplayContext/ItemEffectController"
	)
	if direct_controller != null:
		return direct_controller
	return current_root.find_child("ItemEffectController", true, false)


func _activate_leaf_sheep_companion() -> bool:
	var item_controller: Node = _resolve_item_controller()
	if item_controller == null:
		push_warning("Leaf Sheep pickup could not find ItemEffectController.")
		return false
	if item_controller.has_method(&"activate_leaf_sheep_from_pickup"):
		return bool(item_controller.call(&"activate_leaf_sheep_from_pickup"))
	if not item_controller.has_method(&"handle_item_behavior"):
		push_warning("ItemEffectController has no Leaf Sheep activation route.")
		return false
	return bool(
		item_controller.call(
			&"handle_item_behavior",
			ITEM_ID,
			ITEM_ID,
			ITEM_SLOT_B,
			global_position,
			Vector2.ZERO,
		)
	)


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
