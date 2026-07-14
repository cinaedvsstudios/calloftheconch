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

# Add records only when the stable item ID, slot, icon and behaviour are known.
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


static func get_all_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in ITEMS.keys():
		result.append(StringName(str(key)))
	result.sort_custom(_sort_item_ids)
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
