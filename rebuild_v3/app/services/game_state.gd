class_name CotcGameState
extends Node

signal state_changed
signal checkpoint_changed(level_id: StringName, spawn_id: StringName)

const DEFAULT_LEVEL_ID: StringName = &"sea_of_pillars"
const DEFAULT_SPAWN_POINT_ID: StringName = &"sea_of_pillars_start"
const DEFAULT_FINS: int = 4

var current_level_id: StringName = DEFAULT_LEVEL_ID
var current_spawn_point_id: StringName = DEFAULT_SPAWN_POINT_ID
var current_fins: int = DEFAULT_FINS
var max_fins: int = DEFAULT_FINS
var onos: int = 0
var inventory: Dictionary = {}
var owned_shells: Array[String] = []
var permanent_upgrades: Dictionary = {}
var star_pieces: Array[String] = []
var story_flags: Dictionary = {}
var collected_pickups: Dictionary = {}
var defeated_bosses: Dictionary = {}
var unlocked_whale_grounds: Array[String] = []
var shop_purchases: Dictionary = {}
var playtime_seconds: float = 0.0
var active_save_id: String = ""
var active_save_name: String = ""

var _gameplay_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	if _gameplay_active and not get_tree().paused:
		playtime_seconds += maxf(delta, 0.0)


func start_new_game() -> void:
	current_level_id = DEFAULT_LEVEL_ID
	current_spawn_point_id = DEFAULT_SPAWN_POINT_ID
	current_fins = DEFAULT_FINS
	max_fins = DEFAULT_FINS
	onos = 0
	inventory.clear()
	owned_shells.clear()
	permanent_upgrades.clear()
	star_pieces.clear()
	story_flags.clear()
	collected_pickups.clear()
	defeated_bosses.clear()
	unlocked_whale_grounds.clear()
	shop_purchases.clear()
	playtime_seconds = 0.0
	active_save_id = ""
	active_save_name = ""
	state_changed.emit()
	checkpoint_changed.emit(current_level_id, current_spawn_point_id)


func set_gameplay_active(is_active: bool) -> void:
	_gameplay_active = is_active


func set_checkpoint(level_id: StringName, spawn_point_id: StringName) -> void:
	var resolved_level: StringName = level_id if not String(level_id).is_empty() else DEFAULT_LEVEL_ID
	var resolved_spawn: StringName = spawn_point_id if not String(spawn_point_id).is_empty() else DEFAULT_SPAWN_POINT_ID
	if current_level_id == resolved_level and current_spawn_point_id == resolved_spawn:
		return
	current_level_id = resolved_level
	current_spawn_point_id = resolved_spawn
	checkpoint_changed.emit(current_level_id, current_spawn_point_id)
	state_changed.emit()


func add_onos(amount: int) -> void:
	onos = maxi(0, onos + amount)
	state_changed.emit()


func set_onos(amount: int) -> void:
	onos = maxi(0, amount)
	state_changed.emit()


func set_inventory_item(item_id: StringName, quantity: int) -> void:
	var key: String = String(item_id)
	if key.is_empty():
		return
	if quantity <= 0:
		inventory.erase(key)
	else:
		inventory[key] = quantity
	state_changed.emit()


func add_inventory_item(item_id: StringName, quantity: int = 1) -> void:
	var key: String = String(item_id)
	if key.is_empty() or quantity == 0:
		return
	var current_quantity: int = int(inventory.get(key, 0))
	set_inventory_item(item_id, current_quantity + quantity)


func get_inventory_quantity(item_id: StringName) -> int:
	return int(inventory.get(String(item_id), 0))


func set_fin_state(new_current_fins: int, new_max_fins: int) -> void:
	max_fins = maxi(1, new_max_fins)
	current_fins = clampi(new_current_fins, 0, max_fins)
	state_changed.emit()


func to_save_dictionary() -> Dictionary:
	return {
		"current_level_id": String(current_level_id),
		"current_spawn_point_id": String(current_spawn_point_id),
		"current_fins": current_fins,
		"max_fins": max_fins,
		"onos": onos,
		"inventory": inventory.duplicate(true),
		"owned_shells": owned_shells.duplicate(),
		"permanent_upgrades": permanent_upgrades.duplicate(true),
		"star_pieces": star_pieces.duplicate(),
		"story_flags": story_flags.duplicate(true),
		"collected_pickups": collected_pickups.duplicate(true),
		"defeated_bosses": defeated_bosses.duplicate(true),
		"unlocked_whale_grounds": unlocked_whale_grounds.duplicate(),
		"shop_purchases": shop_purchases.duplicate(true),
		"playtime_seconds": playtime_seconds,
	}


func load_from_save_dictionary(data: Dictionary) -> void:
	current_level_id = StringName(str(data.get("current_level_id", String(DEFAULT_LEVEL_ID))))
	current_spawn_point_id = StringName(str(data.get("current_spawn_point_id", String(DEFAULT_SPAWN_POINT_ID))))
	max_fins = maxi(1, int(data.get("max_fins", DEFAULT_FINS)))
	current_fins = clampi(int(data.get("current_fins", max_fins)), 0, max_fins)
	onos = maxi(0, int(data.get("onos", data.get("money", 0))))
	inventory = _dictionary_value(data.get("inventory", {}))
	owned_shells = _string_array_value(data.get("owned_shells", []))
	permanent_upgrades = _dictionary_value(data.get("permanent_upgrades", {}))
	star_pieces = _string_array_value(data.get("star_pieces", []))
	story_flags = _dictionary_value(data.get("story_flags", {}))
	collected_pickups = _dictionary_value(data.get("collected_pickups", {}))
	defeated_bosses = _dictionary_value(data.get("defeated_bosses", {}))
	unlocked_whale_grounds = _string_array_value(data.get("unlocked_whale_grounds", []))
	shop_purchases = _dictionary_value(data.get("shop_purchases", {}))
	playtime_seconds = maxf(0.0, float(data.get("playtime_seconds", 0.0)))
	state_changed.emit()
	checkpoint_changed.emit(current_level_id, current_spawn_point_id)


func get_location_display_name() -> String:
	match current_level_id:
		&"sea_of_pillars":
			return "Sea of Pillars"
		_:
			return String(current_level_id).replace("_", " ").capitalize()


func get_playtime_display() -> String:
	var total_seconds: int = maxi(0, floori(playtime_seconds))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _dictionary_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _string_array_value(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for item: Variant in source:
		result.append(str(item))
	return result
