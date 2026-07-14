class_name CotcLevelVersionSelector
extends PanelContainer

signal variant_changed(variant_id: StringName)

const VARIANT_PROTOTYPE: StringName = &"prototype"
const VARIANT_MAIN: StringName = &"main"

@onready var _option: OptionButton = %LevelVersionOption
@onready var _status: Label = %LevelVersionStatus

var _selected_variant: StringName = VARIANT_PROTOTYPE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_option.clear()
	_option.add_item("Sea of Pillars — Prototype")
	_option.set_item_metadata(0, VARIANT_PROTOTYPE)
	_option.add_item("Sea of Pillars — Main")
	_option.set_item_metadata(1, VARIANT_MAIN)
	_option.item_selected.connect(_on_option_selected)
	set_selected_variant(VARIANT_PROTOTYPE, false)
	hide()


func activate() -> void:
	show()


func deactivate() -> void:
	hide()


func get_selected_variant() -> StringName:
	return _selected_variant


func set_selected_variant(variant_id: StringName, emit_change: bool = true) -> void:
	var resolved_variant: StringName = VARIANT_MAIN if variant_id == VARIANT_MAIN else VARIANT_PROTOTYPE
	_selected_variant = resolved_variant
	for index: int in range(_option.item_count):
		if StringName(str(_option.get_item_metadata(index))) == resolved_variant:
			_option.select(index)
			break
	_refresh_status()
	if emit_change:
		variant_changed.emit(_selected_variant)


func _on_option_selected(index: int) -> void:
	_selected_variant = StringName(str(_option.get_item_metadata(index)))
	_refresh_status()
	variant_changed.emit(_selected_variant)


func _refresh_status() -> void:
	if _selected_variant == VARIANT_MAIN:
		_status.text = "MAIN selected — production work copy"
	else:
		_status.text = "PROTOTYPE selected — current working level"
