class_name CotcLeafSheepPickup
extends Area2D

const ITEM_ID: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"
const PICKUP_INSTANCE_ID: StringName = &"pirate_ship_leaf_sheep"

@export var auto_equip_on_collect: bool = true
@export var auto_activate_on_collect: bool = true
@export_range(0.05, 1.0, 0.05) var collect_fade_seconds: float = 0.35

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _light: PointLight2D = %PickupLight
@onready var _pickup_audio: AudioStreamPlayer2D = %PickupAudio

var _collecting: bool = false


func _ready() -> void:
	var game_state: CotcGameState = _resolve_game_state()
	if game_state == null:
		return
	if (
		game_state.has_permanent_inventory_item(ITEM_ID)
		or game_state.is_pickup_collected(PICKUP_INSTANCE_ID)
	):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _collecting or body == null or not body.is_in_group(&"hylas"):
		return
	var game_state: CotcGameState = _resolve_game_state()
	if game_state == null:
		push_warning("Leaf Sheep pickup could not find GameState.")
		return

	_collecting = true
	monitoring = false
	game_state.grant_permanent_inventory_item(ITEM_ID)
	game_state.mark_pickup_collected(PICKUP_INSTANCE_ID)
	if auto_equip_on_collect:
		game_state.equip_item(ITEM_ID, ITEM_SLOT_B)
	if auto_activate_on_collect:
		_activate_leaf_sheep_companion()
	_play_collection_feedback()


func _resolve_game_state() -> CotcGameState:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("GameState") as CotcGameState


func _activate_leaf_sheep_companion() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var item_controller: Node = tree.current_scene.get_node_or_null(
		"GameplayContext/ItemEffectController"
	)
	if item_controller == null or not item_controller.has_method(&"handle_item_behavior"):
		return
	item_controller.call(
		&"handle_item_behavior",
		ITEM_ID,
		ITEM_ID,
		ITEM_SLOT_B,
		global_position,
		Vector2.ZERO,
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
