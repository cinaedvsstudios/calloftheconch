class_name CotcTreasureCatalog
extends RefCounted

# Locked environmental treasure values from the current design bible.
const TREASURES: Dictionary = {
	"ancient_greek_coins": {
		"id": "ancient_greek_coins",
		"display_name": "Ancient Greek Coins",
		"icon_path": "res://assets/ui/01_ancient_greek_coins.png",
		"onos_value": 1,
		"sort_order": 0,
		"description": "Common stamped human coins recovered from shipwrecks and drowned towns.",
	},
	"floor_mosaic_tile": {
		"id": "floor_mosaic_tile",
		"display_name": "Floor Mosaic Tile",
		"icon_path": "res://assets/objects/02_floor_mosaic_tiles.png",
		"onos_value": 2,
		"sort_order": 10,
		"description": "Decorative coloured tile fragment from an ancient floor.",
	},
	"terracotta_figurine_human": {
		"id": "terracotta_figurine_human",
		"display_name": "Terracotta Figurine — Human",
		"icon_path": "res://assets/objects/03_terracotta_figurine_human.png",
		"onos_value": 3,
		"sort_order": 20,
		"description": "Small fired-clay human figure.",
	},
	"terracotta_figurine_animal": {
		"id": "terracotta_figurine_animal",
		"display_name": "Terracotta Figurine — Animal",
		"icon_path": "res://assets/objects/04_terracotta_figurine_animal.png",
		"onos_value": 3,
		"sort_order": 30,
		"description": "Small fired-clay animal figure.",
	},
	"bell_shaped_block_of_lead": {
		"id": "bell_shaped_block_of_lead",
		"display_name": "Bell-shaped Block of Lead",
		"icon_path": "res://assets/objects/10_bell_shaped_block_of_lead.png",
		"onos_value": 3,
		"sort_order": 40,
		"description": "Heavy ancient cargo and trade object.",
	},
	"terracotta_figurine_deity": {
		"id": "terracotta_figurine_deity",
		"display_name": "Terracotta Figurine — Deity / Idol",
		"icon_path": "res://assets/objects/05_terracotta_figurine_deity_idol.png",
		"onos_value": 5,
		"sort_order": 50,
		"description": "Small god, hero or votive idol.",
	},
	"oil_lamp": {
		"id": "oil_lamp",
		"display_name": "Oil Lamp",
		"icon_path": "res://assets/objects/06_oil_lamp.png",
		"onos_value": 5,
		"sort_order": 60,
		"description": "Human-made lamp, intriguing to merfolk because it was designed to hold fire.",
	},
	"obsidian_arrowheads": {
		"id": "obsidian_arrowheads",
		"display_name": "Obsidian Arrowheads",
		"icon_path": "res://assets/objects/07_obsidian_arrowhead.png",
		"onos_value": 5,
		"sort_order": 70,
		"description": "Sharp black stone arrowheads.",
	},
	"perfume_bottle": {
		"id": "perfume_bottle",
		"display_name": "Perfume Bottle",
		"icon_path": "res://assets/objects/08_perfume_bottle.png",
		"onos_value": 7,
		"sort_order": 80,
		"description": "Ancient glass or ceramic scent bottle.",
	},
	"soldier_helmet": {
		"id": "soldier_helmet",
		"display_name": "Soldier Helmet",
		"icon_path": "res://assets/objects/09_soldier_helmet.png",
		"onos_value": 20,
		"sort_order": 90,
		"description": "Valuable military artefact.",
	},
	"antikythera_mechanism": {
		"id": "antikythera_mechanism",
		"display_name": "Antikythera Mechanism",
		"icon_path": "res://assets/objects/Antikythera Mechanism.png",
		"onos_value": 30,
		"sort_order": 100,
		"description": "Highest-value regular treasure pickup.",
	},
}


static func has_treasure(treasure_id: StringName) -> bool:
	return TREASURES.has(String(treasure_id))


static func get_treasure(treasure_id: StringName) -> Dictionary:
	var definition: Dictionary = _get_definition(treasure_id)
	return definition.duplicate(true)


static func get_display_name(treasure_id: StringName) -> String:
	return str(_get_definition(treasure_id).get("display_name", String(treasure_id)))


static func get_icon_path(treasure_id: StringName) -> String:
	return str(_get_definition(treasure_id).get("icon_path", ""))


static func get_onos_value(treasure_id: StringName) -> int:
	return maxi(0, int(_get_definition(treasure_id).get("onos_value", 0)))


static func get_description(treasure_id: StringName) -> String:
	return str(_get_definition(treasure_id).get("description", ""))


static func get_all_treasure_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in TREASURES.keys():
		result.append(StringName(str(key)))
	result.sort_custom(_sort_treasure_ids)
	return result


static func _get_definition(treasure_id: StringName) -> Dictionary:
	var value: Variant = TREASURES.get(String(treasure_id), {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _sort_treasure_ids(a: StringName, b: StringName) -> bool:
	var a_order: int = int(_get_definition(a).get("sort_order", 0))
	var b_order: int = int(_get_definition(b).get("sort_order", 0))
	if a_order == b_order:
		return String(a) < String(b)
	return a_order < b_order
