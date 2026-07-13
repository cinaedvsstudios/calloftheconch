class_name CotcGameState
extends Node

signal state_changed
signal state_replaced(reason: StringName)
signal checkpoint_changed(level_id: StringName, spawn_id: StringName)
signal fins_changed(current_value: int, maximum_value: int, delta: int)
signal onos_changed(current_value: int, delta: int)
signal inventory_changed(item_id: StringName, quantity: int, delta: int)
signal shells_changed
signal star_pieces_changed
signal pickup_collection_changed(instance_id: StringName, collected: bool)
signal progression_changed(category: StringName, entry_id: StringName)
signal player_defeated

const STATE_SCHEMA_VERSION: int = 2
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
	_emit_replaced_state(&"new_game")


func set_gameplay_active(is_active: bool) -> void:
	_gameplay_active = is_active


func set_checkpoint(level_id: StringName, spawn_point_id: StringName) -> bool:
	var resolved_level: StringName = level_id if not String(level_id).is_empty() else DEFAULT_LEVEL_ID
	var resolved_spawn: StringName = spawn_point_id if not String(spawn_point_id).is_empty() else DEFAULT_SPAWN_POINT_ID
	if current_level_id == resolved_level and current_spawn_point_id == resolved_spawn:
		return false
	current_level_id = resolved_level
	current_spawn_point_id = resolved_spawn
	checkpoint_changed.emit(current_level_id, current_spawn_point_id)
	state_changed.emit()
	return true


func damage_fins(amount: int) -> int:
	var requested_damage: int = maxi(0, amount)
	if requested_damage <= 0 or current_fins <= 0:
		return 0
	var previous_fins: int = current_fins
	current_fins = maxi(0, current_fins - requested_damage)
	var applied_damage: int = previous_fins - current_fins
	fins_changed.emit(current_fins, max_fins, -applied_damage)
	state_changed.emit()
	if current_fins <= 0:
		player_defeated.emit()
	return applied_damage


func heal_fins(amount: int) -> int:
	var requested_healing: int = maxi(0, amount)
	if requested_healing <= 0 or current_fins >= max_fins:
		return 0
	var previous_fins: int = current_fins
	current_fins = mini(max_fins, current_fins + requested_healing)
	var applied_healing: int = current_fins - previous_fins
	fins_changed.emit(current_fins, max_fins, applied_healing)
	state_changed.emit()
	return applied_healing


func restore_fins() -> int:
	return heal_fins(max_fins - current_fins)


func set_fin_state(new_current_fins: int, new_max_fins: int) -> void:
	var previous_fins: int = current_fins
	var resolved_maximum: int = maxi(1, new_max_fins)
	var resolved_current: int = clampi(new_current_fins, 0, resolved_maximum)
	if max_fins == resolved_maximum and current_fins == resolved_current:
		return
	max_fins = resolved_maximum
	current_fins = resolved_current
	fins_changed.emit(current_fins, max_fins, current_fins - previous_fins)
	state_changed.emit()
	if current_fins <= 0 and previous_fins > 0:
		player_defeated.emit()


func set_max_fins(new_max_fins: int, fill_added_capacity: bool = false) -> void:
	var previous_maximum: int = max_fins
	var previous_current: int = current_fins
	max_fins = maxi(1, new_max_fins)
	if fill_added_capacity and max_fins > previous_maximum:
		current_fins += max_fins - previous_maximum
	current_fins = clampi(current_fins, 0, max_fins)
	if previous_maximum == max_fins and previous_current == current_fins:
		return
	fins_changed.emit(current_fins, max_fins, current_fins - previous_current)
	state_changed.emit()


func add_onos(amount: int) -> int:
	if amount == 0:
		return 0
	var previous_onos: int = onos
	onos = maxi(0, onos + amount)
	var applied_delta: int = onos - previous_onos
	if applied_delta != 0:
		onos_changed.emit(onos, applied_delta)
		state_changed.emit()
	return applied_delta


func set_onos(amount: int) -> void:
	var resolved_amount: int = maxi(0, amount)
	if onos == resolved_amount:
		return
	var previous_onos: int = onos
	onos = resolved_amount
	onos_changed.emit(onos, onos - previous_onos)
	state_changed.emit()


func can_afford_onos(amount: int) -> bool:
	return amount >= 0 and onos >= amount


func spend_onos(amount: int) -> bool:
	if amount < 0 or onos < amount:
		return false
	if amount == 0:
		return true
	add_onos(-amount)
	return true


func set_inventory_item(item_id: StringName, quantity: int) -> int:
	var key: String = String(item_id)
	if key.is_empty():
		return 0
	var previous_quantity: int = int(inventory.get(key, 0))
	var resolved_quantity: int = maxi(0, quantity)
	if previous_quantity == resolved_quantity:
		return resolved_quantity
	if resolved_quantity <= 0:
		inventory.erase(key)
	else:
		inventory[key] = resolved_quantity
	inventory_changed.emit(item_id, resolved_quantity, resolved_quantity - previous_quantity)
	state_changed.emit()
	return resolved_quantity


func add_inventory_item(item_id: StringName, quantity: int = 1) -> int:
	if String(item_id).is_empty() or quantity <= 0:
		return get_inventory_quantity(item_id)
	return set_inventory_item(item_id, get_inventory_quantity(item_id) + quantity)


func remove_inventory_item(item_id: StringName, quantity: int = 1) -> bool:
	if String(item_id).is_empty() or quantity < 0:
		return false
	if quantity == 0:
		return true
	var current_quantity: int = get_inventory_quantity(item_id)
	if current_quantity < quantity:
		return false
	set_inventory_item(item_id, current_quantity - quantity)
	return true


func get_inventory_quantity(item_id: StringName) -> int:
	return int(inventory.get(String(item_id), 0))


func has_inventory_item(item_id: StringName, quantity: int = 1) -> bool:
	return quantity >= 0 and get_inventory_quantity(item_id) >= quantity


func unlock_shell(shell_id: StringName) -> bool:
	var key: String = String(shell_id)
	if key.is_empty() or owned_shells.has(key):
		return false
	owned_shells.append(key)
	shells_changed.emit()
	progression_changed.emit(&"shell", shell_id)
	state_changed.emit()
	return true


func add_star_piece(piece_id: StringName) -> bool:
	var key: String = String(piece_id)
	if key.is_empty() or star_pieces.has(key):
		return false
	star_pieces.append(key)
	star_pieces_changed.emit()
	progression_changed.emit(&"star_piece", piece_id)
	state_changed.emit()
	return true


func set_story_flag(flag_id: StringName, value: Variant = true) -> void:
	var key: String = String(flag_id)
	if key.is_empty() or story_flags.get(key, null) == value:
		return
	story_flags[key] = value
	progression_changed.emit(&"story_flag", flag_id)
	state_changed.emit()


func mark_pickup_collected(instance_id: StringName) -> bool:
	var key: String = String(instance_id)
	if key.is_empty() or bool(collected_pickups.get(key, false)):
		return false
	collected_pickups[key] = true
	pickup_collection_changed.emit(instance_id, true)
	state_changed.emit()
	return true


func is_pickup_collected(instance_id: StringName) -> bool:
	return bool(collected_pickups.get(String(instance_id), false))


func mark_boss_defeated(boss_id: StringName) -> bool:
	var key: String = String(boss_id)
	if key.is_empty() or bool(defeated_bosses.get(key, false)):
		return false
	defeated_bosses[key] = true
	progression_changed.emit(&"boss", boss_id)
	state_changed.emit()
	return true


func unlock_whale_ground(whale_ground_id: StringName) -> bool:
	var key: String = String(whale_ground_id)
	if key.is_empty() or unlocked_whale_grounds.has(key):
		return false
	unlocked_whale_grounds.append(key)
	progression_changed.emit(&"whale_ground", whale_ground_id)
	state_changed.emit()
	return true


func record_shop_purchase(purchase_id: StringName, quantity: int = 1) -> int:
	var key: String = String(purchase_id)
	if key.is_empty() or quantity <= 0:
		return int(shop_purchases.get(key, 0))
	var new_quantity: int = int(shop_purchases.get(key, 0)) + quantity
	shop_purchases[key] = new_quantity
	progression_changed.emit(&"shop_purchase", purchase_id)
	state_changed.emit()
	return new_quantity


func to_save_dictionary() -> Dictionary:
	return {
		"state_schema_version": STATE_SCHEMA_VERSION,
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
	_emit_replaced_state(&"save_loaded")


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


func get_debug_lines() -> Array[String]:
	return [
		"[GameState]",
		"schema_version=%d" % STATE_SCHEMA_VERSION,
		"fins=%d/%d" % [current_fins, max_fins],
		"onos=%d" % onos,
		"inventory=%s" % str(inventory),
		"owned_shells=%s" % str(owned_shells),
		"star_pieces=%s" % str(star_pieces),
		"collected_pickups=%d" % collected_pickups.size(),
		"defeated_bosses=%d" % defeated_bosses.size(),
		"unlocked_whale_grounds=%s" % str(unlocked_whale_grounds),
	]


func _emit_replaced_state(reason: StringName) -> void:
	state_replaced.emit(reason)
	checkpoint_changed.emit(current_level_id, current_spawn_point_id)
	fins_changed.emit(current_fins, max_fins, 0)
	onos_changed.emit(onos, 0)
	shells_changed.emit()
	star_pieces_changed.emit()
	state_changed.emit()


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
