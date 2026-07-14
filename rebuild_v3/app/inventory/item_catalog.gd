class_name CotcItemCatalog
extends RefCounted

const SLOT_A: StringName = &"item_a"
const SLOT_B: StringName = &"item_b"

const TYPE_ACTIVE: StringName = &"active"
const TYPE_PASSIVE: StringName = &"passive"
const TYPE_QUEST: StringName = &"quest"

const OWNERSHIP_SHELLS: StringName = &"owned_shells"
const OWNERSHIP_INVENTORY: StringName = &"inventory"
const OWNERSHIP_PERMANENT: StringName = &"permanent_inventory_items"
const OWNERSHIP_STAR_PIECES: StringName = &"star_pieces"

const NORMAL_CONCH_ID: StringName = &"normal_conch"

# Stable inventory records. Shells are permanent, unlimited-use unlocks.
# Shop objects use quantity stacks and are only consumed after a successful use.
const ITEMS: Dictionary = {
	"normal_conch": {
		"id": "normal_conch",
		"display_name": "Normal Conch",
		"slot_id": "item_a",
		"item_type": "active",
		"icon_path": "res://assets/ui/shell_normal_conch.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 0,
		"behavior_id": "normal_conch",
		"price_onos": 0,
		"description": "Main sonar tool. Reveals secrets, scares ordinary sharks and affects targets by echo range.",
	},
	"charonia_tritonis": {
		"id": "charonia_tritonis",
		"display_name": "Charonia tritonis — Super Conch",
		"slot_id": "item_a",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_charonia_tritonis.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 10,
		"behavior_id": "super_conch",
		"price_onos": 0,
		"description": "Charged larger sonar call with longer reach and a wider final wave.",
	},
	"terebridae": {
		"id": "terebridae",
		"display_name": "Terebridae — Sonic Drill",
		"slot_id": "item_a",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_terebridae.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 20,
		"behavior_id": "sonic_drill",
		"price_onos": 0,
		"description": "Focused sonic drill and weapon used on marked rock, seabed and valid targets.",
	},
	"conus_textile": {
		"id": "conus_textile",
		"display_name": "Conus textile — Dart & Tether",
		"slot_id": "item_a",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_conus_textile.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 30,
		"behavior_id": "dart_tether",
		"price_onos": 0,
		"description": "Precision poison dart and grapple tether for marked anchors in strong currents.",
	},
	"murex_pecten": {
		"id": "murex_pecten",
		"display_name": "Murex pecten — Purple Shield",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_murex_pecten.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 40,
		"behavior_id": "purple_shield",
		"price_onos": 0,
		"description": "Creates a temporary purple protective veil around Hylas.",
	},
	"tridacna_gigas": {
		"id": "tridacna_gigas",
		"display_name": "Tridacna gigas — Surge",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_tridacna_gigas.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 50,
		"behavior_id": "surge",
		"price_onos": 0,
		"description": "Directional burst for speed, current resistance and ramming marked pushable objects.",
	},
	"haliotis": {
		"id": "haliotis",
		"display_name": "Haliotis — Veil",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_haliotis.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 60,
		"behavior_id": "camouflage_veil",
		"price_onos": 0,
		"description": "Pearlescent camouflage that prevents ordinary enemy detection while active.",
	},
	"argonauta": {
		"id": "argonauta",
		"display_name": "Argonauta — Ink Prison",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/shell_argonauta.png",
		"ownership_source": "owned_shells",
		"has_quantity": false,
		"activates_on_use": true,
		"sort_order": 70,
		"behavior_id": "ink_prison",
		"price_onos": 0,
		"description": "Creates an ink cloud that briefly paralyses smaller enemies caught inside it.",
	},
	"tyche_margarites": {
		"id": "tyche_margarites",
		"display_name": "Tyche Margarites",
		"slot_id": "item_b",
		"item_type": "passive",
		"icon_path": "res://assets/objects/item_tyche_margarites.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": false,
		"sort_order": 100,
		"behavior_id": "tyche_margarites",
		"price_onos": 15,
		"description": "Lucky pearl crown that stores multiplied eligible treasure value until cashed in at Myra.",
	},
	"crown_sea_grapes": {
		"id": "crown_sea_grapes",
		"display_name": "Crown Sea Grapes",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/food_crown_sea_grapes.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": true,
		"sort_order": 110,
		"behavior_id": "crown_sea_grapes",
		"price_onos": 20,
		"description": "Restores all normal Fins and activates Greatfin.",
	},
	"seaweed_grapes_box": {
		"id": "seaweed_grapes_box",
		"display_name": "Seaweed Grapes Box",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/item_seaweed_grapes_box.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": true,
		"sort_order": 120,
		"behavior_id": "seaweed_grapes_box",
		"price_onos": 15,
		"description": "Carried healing pack that restores Fins when used.",
	},
	"kestos_himas": {
		"id": "kestos_himas",
		"display_name": "Kestos Himas",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/item_kestos_himas.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": true,
		"sort_order": 130,
		"behavior_id": "field_checkpoint",
		"price_onos": 30,
		"description": "Single-use field checkpoint belt. Only one temporary checkpoint may be active.",
	},
	"pelanos_cake": {
		"id": "pelanos_cake",
		"display_name": "Pelanos Cake",
		"slot_id": "item_b",
		"item_type": "quest",
		"icon_path": "res://assets/objects/item_pelanos_cake.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": false,
		"sort_order": 140,
		"behavior_id": "oracle_hint_offering",
		"price_onos": 30,
		"description": "Offering consumed at Ostraka for one additional, clearer hint.",
	},
	"mati_amulet": {
		"id": "mati_amulet",
		"display_name": "Mati Amulet",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/item_mati_amulet.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": true,
		"sort_order": 150,
		"behavior_id": "world_freeze",
		"price_onos": 30,
		"description": "Single-use world freeze: five seconds slowing, twenty frozen and five returning.",
	},
	"echo_amphora": {
		"id": "echo_amphora",
		"display_name": "Echo Amphora",
		"slot_id": "item_b",
		"item_type": "active",
		"icon_path": "res://assets/objects/item_echo_amphora.png",
		"ownership_source": "inventory",
		"has_quantity": true,
		"activates_on_use": true,
		"sort_order": 160,
		"behavior_id": "echo_amphora",
		"price_onos": 30,
		"description": "Records an eligible creature's natural ability for temporary use without harming it.",
	},
}


static func has_item(item_id: StringName) -> bool:
	return ITEMS.has(String(item_id))


static func get_item(item_id: StringName) -> Dictionary:
	var definition: Dictionary = _get_definition(item_id)
	return definition.duplicate(true)


static func get_slot(item_id: StringName) -> StringName:
	return StringName(str(_get_definition(item_id).get("slot_id", "")))


static func get_item_type(item_id: StringName) -> StringName:
	return StringName(str(_get_definition(item_id).get("item_type", "")))


static func get_ownership_source(item_id: StringName) -> StringName:
	return StringName(str(_get_definition(item_id).get("ownership_source", "")))


static func item_has_quantity(item_id: StringName) -> bool:
	return bool(_get_definition(item_id).get("has_quantity", false))


static func activates_on_use(item_id: StringName) -> bool:
	return bool(_get_definition(item_id).get("activates_on_use", false))


static func get_behavior_id(item_id: StringName) -> StringName:
	return StringName(str(_get_definition(item_id).get("behavior_id", "")))


static func get_price_onos(item_id: StringName) -> int:
	return maxi(0, int(_get_definition(item_id).get("price_onos", 0)))


static func get_description(item_id: StringName) -> String:
	return str(_get_definition(item_id).get("description", ""))


static func get_all_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in ITEMS.keys():
		result.append(StringName(str(key)))
	result.sort_custom(_sort_item_ids)
	return result


static func get_shell_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id: StringName in get_all_item_ids():
		if get_ownership_source(item_id) == OWNERSHIP_SHELLS:
			result.append(item_id)
	return result


static func get_quantity_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id: StringName in get_all_item_ids():
		if item_has_quantity(item_id):
			result.append(item_id)
	return result


static func _get_definition(item_id: StringName) -> Dictionary:
	var value: Variant = ITEMS.get(String(item_id), {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value as Dictionary


static func _sort_item_ids(a: StringName, b: StringName) -> bool:
	var a_order: int = int(_get_definition(a).get("sort_order", 0))
	var b_order: int = int(_get_definition(b).get("sort_order", 0))
	if a_order == b_order:
		return String(a) < String(b)
	return a_order < b_order
