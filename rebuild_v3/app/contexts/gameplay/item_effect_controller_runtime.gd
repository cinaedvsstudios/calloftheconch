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


## Used only by the physical Leaf Sheep pickup. This is deliberately not a
## toggle: collection must leave the companion on, even if an older save left it
## active, cooling down or partially configured.
func activate_leaf_sheep_from_pickup() -> bool:
	if not is_instance_valid(_leaf_sheep):
		push_warning("Leaf Sheep pickup could not find the shared companion node.")
		return false
	_leaf_sheep.set_gameplay_active(true)
	var activated: bool = false
	if _leaf_sheep.has_method(&"activate_from_pickup"):
		activated = bool(_leaf_sheep.call(&"activate_from_pickup"))
	else:
		activated = _leaf_sheep.is_active() or _leaf_sheep.toggle_activation()
	_refresh_leaf_sheep_hud()
	if not activated:
		push_warning("Leaf Sheep pickup granted and equipped the item, but the companion did not activate.")
	return activated
