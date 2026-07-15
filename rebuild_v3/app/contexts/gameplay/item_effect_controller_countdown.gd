extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller_world_sync.gd"

const COUNTDOWN_NONE: StringName = &""
const COUNTDOWN_SHIELD: StringName = &"purple_shield"
const COUNTDOWN_CAMOUFLAGE: StringName = &"camouflage"
const COUNTDOWN_INK: StringName = &"argonauta_cloud"
const SLOT_B: StringName = &"item_b"

var _countdown_source: StringName = COUNTDOWN_NONE
var _countdown_hud: Node
var _tracked_ink_cloud: CotcInkParalysisCloud


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	super.configure(context, level, hylas)
	_countdown_hud = context.get_node_or_null("%GameplayHud") if context != null else null
	_clear_hud_countdown()


func _process(delta: float) -> void:
	super._process(delta)
	match _countdown_source:
		COUNTDOWN_SHIELD:
			_update_hud_countdown(_purple_shield_remaining, purple_shield_seconds)
		COUNTDOWN_CAMOUFLAGE:
			_update_hud_countdown(_camouflage_remaining, camouflage_seconds)


func clear_active_effects() -> void:
	_countdown_source = COUNTDOWN_NONE
	_tracked_ink_cloud = null
	_clear_hud_countdown()
	super.clear_active_effects()


func _activate_purple_shield() -> bool:
	var activated: bool = super._activate_purple_shield()
	if activated:
		_tracked_ink_cloud = null
		_countdown_source = COUNTDOWN_SHIELD
		_update_hud_countdown(_purple_shield_remaining, purple_shield_seconds)
	return activated


func _stop_purple_shield() -> void:
	super._stop_purple_shield()
	if _countdown_source == COUNTDOWN_SHIELD:
		_countdown_source = COUNTDOWN_NONE
		_clear_hud_countdown()


func _activate_camouflage() -> bool:
	var activated: bool = super._activate_camouflage()
	if activated:
		_tracked_ink_cloud = null
		_countdown_source = COUNTDOWN_CAMOUFLAGE
		_update_hud_countdown(_camouflage_remaining, camouflage_seconds)
	return activated


func _stop_camouflage() -> void:
	super._stop_camouflage()
	if _countdown_source == COUNTDOWN_CAMOUFLAGE:
		_countdown_source = COUNTDOWN_NONE
		_clear_hud_countdown()


func _on_ink_blob_impacted(impact_position: Vector2) -> void:
	var cloud_count_before: int = _clouds.get_child_count()
	super._on_ink_blob_impacted(impact_position)
	if _clouds.get_child_count() <= cloud_count_before:
		return
	var cloud: CotcInkParalysisCloud = _clouds.get_child(_clouds.get_child_count() - 1) as CotcInkParalysisCloud
	if cloud == null:
		return
	_tracked_ink_cloud = cloud
	_countdown_source = COUNTDOWN_INK
	cloud.countdown_changed.connect(_on_ink_countdown_changed.bind(cloud))
	cloud.cloud_finished.connect(_on_ink_cloud_finished.bind(cloud))
	_update_hud_countdown(cloud.get_active_remaining_seconds(), cloud.active_seconds)


func _on_ink_countdown_changed(
		remaining_seconds: float,
		total_seconds: float,
		cloud: CotcInkParalysisCloud,
	) -> void:
	if cloud != _tracked_ink_cloud or _countdown_source != COUNTDOWN_INK:
		return
	_update_hud_countdown(remaining_seconds, total_seconds)


func _on_ink_cloud_finished(cloud: CotcInkParalysisCloud) -> void:
	if cloud != _tracked_ink_cloud:
		return
	_tracked_ink_cloud = null
	if _countdown_source == COUNTDOWN_INK:
		_countdown_source = COUNTDOWN_NONE
		_clear_hud_countdown()


func _update_hud_countdown(remaining_seconds: float, total_seconds: float) -> void:
	if not is_instance_valid(_countdown_hud):
		return
	if remaining_seconds <= 0.0 or total_seconds <= 0.0:
		_clear_hud_countdown()
		return
	if _countdown_hud.has_method(&"set_item_effect_countdown"):
		_countdown_hud.call(
			&"set_item_effect_countdown",
			SLOT_B,
			remaining_seconds,
			total_seconds,
		)


func _clear_hud_countdown() -> void:
	if (
		is_instance_valid(_countdown_hud)
		and _countdown_hud.has_method(&"clear_item_effect_countdown")
	):
		_countdown_hud.call(&"clear_item_effect_countdown", SLOT_B)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("countdown_source=%s" % String(_countdown_source))
	lines.append("countdown_hud_valid=%s" % str(is_instance_valid(_countdown_hud)))
	lines.append("tracked_ink_cloud=%s" % str(is_instance_valid(_tracked_ink_cloud)))
	return lines
