extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.gd"

const PICKUP_REWARD_FIN: StringName = &"fin"

var _connected_level: CotcSeaOfPillars


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_disconnect_level_pickups()
	super.configure(context, level, hylas)
	_connected_level = level
	if (
			is_instance_valid(_connected_level)
			and not _connected_level.greatfin_pickup_requested.is_connected(
				_on_greatfin_pickup_requested
			)
		):
		_connected_level.greatfin_pickup_requested.connect(
			_on_greatfin_pickup_requested
		)


func _exit_tree() -> void:
	_disconnect_level_pickups()


func _activate_crown_sea_grapes() -> bool:
	var activated: bool = super._activate_crown_sea_grapes()
	if activated:
		_show_fin_feedback()
	return activated


func _activate_seaweed_grapes_box() -> bool:
	var healed: bool = super._activate_seaweed_grapes_box()
	if healed:
		_show_fin_feedback()
	return healed


func _on_greatfin_pickup_requested(_pickup_type_id: StringName) -> void:
	if _active:
		_play_one_shot_video(_transform_effect)


func _show_fin_feedback() -> void:
	if is_instance_valid(_level) and _level.has_method(&"show_item_reward_feedback"):
		_level.call(&"show_item_reward_feedback", PICKUP_REWARD_FIN)


func _disconnect_level_pickups() -> void:
	if (
			is_instance_valid(_connected_level)
			and _connected_level.greatfin_pickup_requested.is_connected(
				_on_greatfin_pickup_requested
			)
		):
		_connected_level.greatfin_pickup_requested.disconnect(
			_on_greatfin_pickup_requested
		)
	_connected_level = null
