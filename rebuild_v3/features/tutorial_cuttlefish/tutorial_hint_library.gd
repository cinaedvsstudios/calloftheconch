class_name CotcTutorialHintLibrary
extends Resource

## Central collection of cuttlefish tutorial hint definitions.

@export var hints: Array[CotcTutorialHintDefinition] = []


func get_hint(hint_id: StringName) -> CotcTutorialHintDefinition:
	if String(hint_id).is_empty():
		return null
	for definition: CotcTutorialHintDefinition in hints:
		if definition != null and definition.hint_id == hint_id:
			return definition
	return null


func has_hint(hint_id: StringName) -> bool:
	return get_hint(hint_id) != null


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = []
	for definition: CotcTutorialHintDefinition in hints:
		if definition == null:
			lines.append("<null definition>")
			continue
		lines.append(
			"%s valid=%s action=%s once=%s" % [
				String(definition.hint_id),
				str(definition.is_valid_definition()),
				String(definition.required_action),
				str(definition.show_only_once),
			]
		)
	return lines
