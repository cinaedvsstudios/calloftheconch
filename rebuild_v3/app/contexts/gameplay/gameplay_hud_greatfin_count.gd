extends "res://rebuild_v3/app/contexts/gameplay/gameplay_hud.gd"


func _sync_from_state() -> void:
	super._sync_from_state()
	if _game_state != null and _game_state.greatfin_active:
		_fin_value.text = "5"
