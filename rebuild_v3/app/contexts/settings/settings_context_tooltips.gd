extends "res://rebuild_v3/app/contexts/settings/settings_context.gd"

## Reuses the former control-hint row as the cuttlefish tutorial-tooltip toggle.

@onready var _tooltips_label: Label = $SettingsPanel/Margin/Content/SettingsScroll/SettingsVBox/AccessibilityGrid/HintsLabel
@onready var _tooltips_check: CheckButton = %ControlHintsCheck


func _hide_old_control_hint_setting() -> void:
	# The row is now the live tutorial-tooltip setting, so it must remain visible.
	pass


func _ready() -> void:
	super._ready()
	_tooltips_label.text = "Tutorial tooltips"
	if not _tooltips_check.toggled.is_connected(_on_tooltips_toggled):
		_tooltips_check.toggled.connect(_on_tooltips_toggled)
	_sync_tooltip_control()


func _sync_from_settings() -> void:
	super._sync_from_settings()
	_sync_tooltip_control()


func _sync_tooltip_control() -> void:
	if not is_instance_valid(_tooltips_check):
		return
	_syncing_controls = true
	var enabled: bool = true
	if _settings != null:
		enabled = _settings.show_control_hints
	_tooltips_check.button_pressed = enabled
	_tooltips_check.text = "Enabled" if enabled else "Disabled"
	_syncing_controls = false


func _on_tooltips_toggled(enabled: bool) -> void:
	_tooltips_check.text = "Enabled" if enabled else "Disabled"
	if not _syncing_controls and _settings != null:
		_settings.set_show_control_hints(enabled)
