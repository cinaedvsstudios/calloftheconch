extends "res://rebuild_v3/app/contexts/gameplay/gameplay_hud.gd"

@onready var _item_b_countdown: CotcEffectCountdownOverlay = %ItemBCountdown


func _ready() -> void:
	super._ready()
	_item_b_countdown.clear_countdown()


func _apply_element_layout() -> void:
	super._apply_element_layout()
	if is_instance_valid(_item_b_countdown):
		_apply_control_rect(_item_b_countdown, item_b_icon_rect)


func set_item_effect_countdown(
		slot_id: StringName,
		remaining_seconds: float,
		total_seconds: float,
	) -> void:
	if slot_id != SLOT_B:
		return
	_item_b_countdown.set_countdown(remaining_seconds, total_seconds)


func clear_item_effect_countdown(slot_id: StringName) -> void:
	if slot_id != SLOT_B:
		return
	_item_b_countdown.clear_countdown()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("item_b_countdown_visible=%s" % str(_item_b_countdown.visible))
	lines.append("item_b_countdown_frame=%d" % _item_b_countdown.get_frame_index())
	return lines
