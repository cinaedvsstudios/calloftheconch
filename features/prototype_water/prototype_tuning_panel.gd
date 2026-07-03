class_name PrototypeTuningPanel
extends Control
## Pause-menu tuning UI for Prototype 0.1. Changes apply live and export as a portable JSON file.

@onready var _form_content: VBoxContainer = %FormContent
@onready var _status_label: Label = %StatusLabel
@onready var _file_dialog: FileDialog = %ExportFileDialog

var _prototype_water: PrototypeWater
var _spin_boxes: Dictionary = {}
var _is_syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(close)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%ExportButton.pressed.connect(_on_export_pressed)
	_file_dialog.file_selected.connect(_on_export_file_selected)
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json ; JSON settings file"])
	_file_dialog.current_file = "Call_of_the_Conch_Prototype_Tuning.json"
	hide()


func bind_dependencies(prototype_water: PrototypeWater) -> void:
	_prototype_water = prototype_water
	_build_form()


func open() -> void:
	if _prototype_water == null:
		return
	_sync_from_world()
	_status_label.text = "Changes apply immediately. Export the JSON when the feel is right."
	show()
	%CloseButton.grab_focus()


func close() -> void:
	hide()


func _build_form() -> void:
	for child: Node in _form_content.get_children():
		child.queue_free()
	_spin_boxes.clear()

	var current_section: String = ""
	var current_grid: GridContainer
	for definition: Dictionary in PrototypeTuning.get_field_definitions():
		var section: String = str(definition["section"])
		if section != current_section:
			current_section = section
			var heading: Label = Label.new()
			heading.text = section
			heading.add_theme_color_override("font_color", Color(0.76, 0.91, 1.0, 1.0))
			heading.add_theme_font_size_override("font_size", 18)
			heading.add_theme_constant_override("outline_size", 1)
			_form_content.add_child(heading)

			current_grid = GridContainer.new()
			current_grid.columns = 2
			current_grid.add_theme_constant_override("h_separation", 24)
			current_grid.add_theme_constant_override("v_separation", 8)
			_form_content.add_child(current_grid)

		var label: Label = Label.new()
		label.text = str(definition["label"])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		current_grid.add_child(label)

		var spin_box: SpinBox = SpinBox.new()
		spin_box.min_value = float(definition["min"])
		spin_box.max_value = float(definition["max"])
		spin_box.step = float(definition["step"])
		spin_box.allow_greater = false
		spin_box.allow_lesser = false
		spin_box.rounded = spin_box.step >= 1.0
		spin_box.custom_minimum_size = Vector2(150.0, 0.0)
		spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: StringName = StringName(definition["key"])
		spin_box.value_changed.connect(_on_tuning_value_changed.bind(key))
		current_grid.add_child(spin_box)
		_spin_boxes[key] = spin_box


func _sync_from_world() -> void:
	if _prototype_water == null:
		return
	_is_syncing = true
	for key: Variant in _spin_boxes.keys():
		var typed_key: StringName = StringName(key)
		var spin_box: SpinBox = _spin_boxes[typed_key] as SpinBox
		spin_box.value = _prototype_water.get_tuning_value(typed_key)
	_is_syncing = false


func _on_tuning_value_changed(value: float, key: StringName) -> void:
	if _is_syncing or _prototype_water == null:
		return
	_prototype_water.set_tuning_value(key, value)
	if key == &"water_horizontal_tiles":
		_status_label.text = "Water tiles rebuilt. Hylas returned to the centre tile."
	else:
		_status_label.text = "%s updated live." % str(key).replace("_", " ")


func _on_reset_pressed() -> void:
	if _prototype_water == null:
		return
	_prototype_water.reset_tuning_defaults()
	_sync_from_world()
	_status_label.text = "Prototype defaults restored."


func _on_export_pressed() -> void:
	if _prototype_water == null:
		return
	_file_dialog.popup_centered_ratio(0.75)


func _on_export_file_selected(path: String) -> void:
	if _prototype_water == null:
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status_label.text = "Could not write the settings file. Choose a writable folder."
		return
	file.store_string(JSON.stringify(_prototype_water.get_tuning_export_dictionary(), "\t"))
	file.close()
	_status_label.text = "Exported: %s" % path
