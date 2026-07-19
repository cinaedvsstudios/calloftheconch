class_name CotcTutorialHintDefinition
extends Resource

## Inspector-editable content and completion rules for one cuttlefish tutorial hint.

enum DismissMode {
	AFTER_DURATION,
	REQUIRED_ACTION,
	ACTION_OR_DURATION,
}

@export var hint_id: StringName = &""
@export_multiline var text: String = ""
@export_range(0.5, 30.0, 0.1) var display_duration: float = 7.0
@export_enum("After Duration", "Required Action", "Action or Duration")
var dismiss_mode: int = DismissMode.ACTION_OR_DURATION
@export var required_action: StringName = &""
@export var show_only_once: bool = true
@export_range(0.5, 2.0, 0.05) var ink_scale: float = 1.0
@export var text_color: Color = Color(0.17, 0.67, 0.82, 1.0)


func is_valid_definition() -> bool:
	return not String(hint_id).is_empty() and not text.strip_edges().is_empty()
