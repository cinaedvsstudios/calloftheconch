extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.gd"

## Retargets the already-bound item system to a temporary local-room Hylas
## without disconnecting the persistent Sea of Pillars pickup routes.

func retarget_local_room(context: Node, room_level: Node, room_hylas: CotcHylas) -> bool:
	if not is_instance_valid(room_hylas):
		push_warning("ItemEffectController could not retarget because the local-room Hylas is missing.")
		return false
	_disconnect_hylas_normal_conch()
	_context = context
	_hylas = room_hylas
	_connect_hylas_normal_conch()
	_update_video_anchor()
	_leaf_sheep.configure(context, room_level, room_hylas)
	_leaf_sheep.set_gameplay_active(_active)
	_sync_greatfin_visual()
	return true
