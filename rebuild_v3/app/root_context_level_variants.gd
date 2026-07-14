extends "res://rebuild_v3/app/root_context.gd"

@onready var _level_version_selector: CotcLevelVersionSelector = %LevelVersionSelector


func _ready() -> void:
	super._ready()
	_level_version_selector.variant_changed.connect(_on_level_variant_changed)
	_gameplay_context.call(
		&"set_level_variant",
		_level_version_selector.get_selected_variant(),
	)
	_level_version_selector.activate()


func _on_new_game_requested() -> void:
	_level_version_selector.deactivate()
	_gameplay_context.call(
		&"set_level_variant",
		_level_version_selector.get_selected_variant(),
	)
	super._on_new_game_requested()


func _on_continue_requested() -> void:
	_level_version_selector.deactivate()
	super._on_continue_requested()


func _on_continue_back_requested() -> void:
	super._on_continue_back_requested()
	_level_version_selector.activate()


func _on_menu_settings_requested() -> void:
	_level_version_selector.deactivate()
	super._on_menu_settings_requested()


func _on_settings_back_requested() -> void:
	super._on_settings_back_requested()
	if _menu_context.visible:
		_level_version_selector.activate()
	else:
		_level_version_selector.deactivate()


func _on_menu_requested() -> void:
	await super._on_menu_requested()
	_level_version_selector.activate()


func _on_level_variant_changed(variant_id: StringName) -> void:
	if not _gameplay_context.call(&"set_level_variant", variant_id):
		_level_version_selector.set_selected_variant(
			StringName(str(_gameplay_context.call(&"get_level_variant"))),
			false,
		)


func build_debug_report() -> String:
	var report: String = super.build_debug_report()
	return "%s\nlevel_variant_selector=%s" % [
		report,
		String(_level_version_selector.get_selected_variant()),
	]
