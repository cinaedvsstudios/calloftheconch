extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.gd"

const PICKUP_REWARD_FIN: StringName = &"fin"
const ITEM_MUREX_PECTEN: StringName = &"murex_pecten"
const ITEM_HALIOTIS: StringName = &"haliotis"
const ITEM_ARGONAUTA: StringName = &"argonauta"
const BEHAVIOR_WORLD_FREEZE: StringName = &"world_freeze"
const BEHAVIOR_TYCHE: StringName = &"tyche_margarites"

@onready var _morph_audio: AudioStreamPlayer = %MorphAudio
@onready var _powerdown_audio: AudioStreamPlayer = %PowerdownAudio
@onready var _shield_audio: AudioStreamPlayer = %ShieldAudio
@onready var _invisibility_audio: AudioStreamPlayer = %InvisibilityAudio
@onready var _mati_overlay: CotcMatiOverlay = %MatiOverlay

var _connected_level: CotcSeaOfPillars
var _connected_game_state: CotcGameState
var _morph_tween: Tween
var _status_countdown: CotcStatusCountdownOverlay
var _ink_cloud_status: Dictionary = {}
var _mati_active := false
var _mati_elapsed := 0.0
var _mati_phase := 0.0
var _hylas_previous_process_mode := Node.PROCESS_MODE_INHERIT


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_disconnect_level_pickups()
	super.configure(context, level, hylas)
	_connected_level = level
	_status_countdown = null
	if context != null:
		_status_countdown = context.get_node_or_null(
			"GameplayUI/GameplayHud/ItemBIcon/ItemStatusCountdown"
		) as CotcStatusCountdownOverlay
		if _status_countdown == null:
			_status_countdown = context.get_node_or_null("%ItemStatusCountdown") as CotcStatusCountdownOverlay
	if is_instance_valid(_connected_level) and not _connected_level.greatfin_pickup_requested.is_connected(_on_greatfin_pickup_requested):
		_connected_level.greatfin_pickup_requested.connect(_on_greatfin_pickup_requested)
	_refresh_status_countdown()


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_game_state()
	super.bind_game_state(game_state)
	_connected_game_state = game_state
	if _connected_game_state != null:
		if not _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
			_connected_game_state.greatfin_changed.connect(_on_greatfin_changed)
		if not _connected_game_state.defeat_state_changed.is_connected(_on_defeat_state_changed):
			_connected_game_state.defeat_state_changed.connect(_on_defeat_state_changed)
	_sync_greatfin_visual()


func _process(delta: float) -> void:
	_update_mati(delta)
	super._process(delta)
	if _surge_remaining > 0.0 and not Input.is_action_pressed(&"utility_item"):
		_stop_surge()
	_refresh_status_countdown()


func _exit_tree() -> void:
	_disconnect_level_pickups()
	_disconnect_game_state()


func handle_item_behavior(behavior_id: StringName, item_id: StringName, slot_id: StringName, origin: Vector2, direction: Vector2) -> bool:
	if behavior_id == BEHAVIOR_WORLD_FREEZE: return _activate_mati()
	if behavior_id == BEHAVIOR_TYCHE: return _connected_game_state != null and _connected_game_state.activate_tyche_margarites()
	return super.handle_item_behavior(behavior_id,item_id,slot_id,origin,direction)

func _activate_mati() -> bool:
	if _mati_active or not is_instance_valid(_hylas): return false
	_mati_active = true
	_mati_elapsed = 0.0
	_hylas_previous_process_mode = _hylas.process_mode
	_hylas.process_mode = Node.PROCESS_MODE_ALWAYS
	_mati_overlay.set_elapsed(0.0)
	return true

func _update_mati(delta: float) -> void:
	if not _mati_active: return
	_mati_elapsed = minf(30.0,_mati_elapsed+maxf(delta,0.0))
	_mati_overlay.set_elapsed(_mati_elapsed)
	var ratio := 1.0
	if _mati_elapsed < 5.0: ratio = _mati_elapsed/5.0
	elif _mati_elapsed >= 25.0: ratio = 1.0-((_mati_elapsed-25.0)/5.0)
	_mati_phase = fmod(_mati_phase + delta*12.0,1.0)
	get_tree().paused = ratio >= 0.999 or _mati_phase < ratio
	if _mati_elapsed >= 30.0: _finish_mati()

func _finish_mati() -> void:
	get_tree().paused = false
	if is_instance_valid(_hylas): _hylas.process_mode = _hylas_previous_process_mode
	_mati_overlay.clear()
	_mati_active = false
	_mati_elapsed = 0.0

func clear_active_effects() -> void:
	_ink_cloud_status.clear()
	if _mati_active: _finish_mati()
	super.clear_active_effects()
	if is_instance_valid(_status_countdown):
		_status_countdown.clear_countdown()


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


func _activate_purple_shield() -> bool:
	var activated: bool = super._activate_purple_shield()
	if activated:
		_shield_audio.stop()
		_shield_audio.play()
		_refresh_status_countdown()
	return activated


func _activate_camouflage() -> bool:
	var activated: bool = super._activate_camouflage()
	if activated:
		_invisibility_audio.stop()
		_invisibility_audio.play()
		_refresh_status_countdown()
	return activated


func _on_ink_blob_impacted(impact_position: Vector2) -> void:
	var cloud: CotcInkParalysisCloud = INK_CLOUD_SCENE.instantiate() as CotcInkParalysisCloud
	if cloud == null:
		return
	_clouds.add_child(cloud)
	var cloud_id: int = cloud.get_instance_id()
	_ink_cloud_status[cloud_id] = Vector2(cloud.active_seconds, cloud.active_seconds)
	cloud.time_remaining_changed.connect(_on_ink_cloud_time_changed.bind(cloud_id))
	cloud.cloud_finished.connect(_on_ink_cloud_finished.bind(cloud_id))
	cloud.play_cloud(impact_position)
	_refresh_status_countdown()


func _on_ink_cloud_time_changed(
		remaining_seconds: float,
		duration_seconds: float,
		cloud_id: int,
	) -> void:
	_ink_cloud_status[cloud_id] = Vector2(remaining_seconds, duration_seconds)
	_refresh_status_countdown()


func _on_ink_cloud_finished(cloud_id: int) -> void:
	_ink_cloud_status.erase(cloud_id)
	_refresh_status_countdown()


func _refresh_status_countdown() -> void:
	if not is_instance_valid(_status_countdown):
		return
	if _purple_shield_remaining > 0.0:
		_status_countdown.set_countdown(
			ITEM_MUREX_PECTEN,
			_purple_shield_remaining,
			purple_shield_seconds,
		)
		return
	if _camouflage_remaining > 0.0:
		_status_countdown.set_countdown(
			ITEM_HALIOTIS,
			_camouflage_remaining,
			camouflage_seconds,
		)
		return

	var longest_remaining: float = 0.0
	var longest_duration: float = 0.0
	for status_value: Variant in _ink_cloud_status.values():
		if not (status_value is Vector2):
			continue
		var status: Vector2 = status_value
		if status.x > longest_remaining:
			longest_remaining = status.x
			longest_duration = status.y
	if longest_remaining > 0.0:
		_status_countdown.set_countdown(ITEM_ARGONAUTA, longest_remaining, longest_duration)
		return
	_status_countdown.clear_countdown()


func _on_greatfin_pickup_requested(_pickup_type_id: StringName) -> void:
	if _active:
		_play_one_shot_video(_transform_effect)


func _on_greatfin_changed(_is_active: bool) -> void:
	if not _active:
		_sync_greatfin_visual()
		return
	_play_greatfin_transition()


func _on_defeat_state_changed(is_defeated: bool) -> void:
	if is_defeated:
		clear_active_effects()


func _play_greatfin_transition() -> void:
	if not is_instance_valid(_hylas):
		return
	var item_visuals: Node = _hylas.get_node_or_null("ItemVisuals")
	if item_visuals == null:
		return
	if _morph_tween != null and _morph_tween.is_valid():
		_morph_tween.kill()
	item_visuals.call(&"set_transforming_active", true)
	_play_one_shot_video(_transform_effect)
	if _connected_game_state != null and _connected_game_state.greatfin_active:
		_morph_audio.stop()
		_morph_audio.play()
	else:
		_powerdown_audio.stop()
		_powerdown_audio.play()
	_morph_tween = create_tween()
	_morph_tween.tween_interval(0.42)
	_morph_tween.tween_callback(_apply_greatfin_sprite_state)
	_morph_tween.tween_interval(0.55)
	_morph_tween.tween_callback(item_visuals.set_transforming_active.bind(false))


func _apply_greatfin_sprite_state() -> void:
	if not is_instance_valid(_hylas) or _connected_game_state == null:
		return
	var item_visuals: Node = _hylas.get_node_or_null("ItemVisuals")
	if item_visuals != null:
		item_visuals.call(&"set_greatfin_active", _connected_game_state.greatfin_active)


func _sync_greatfin_visual() -> void:
	if not is_instance_valid(_hylas) or _connected_game_state == null:
		return
	var item_visuals: Node = _hylas.get_node_or_null("ItemVisuals")
	if item_visuals != null:
		item_visuals.call(&"set_greatfin_active", _connected_game_state.greatfin_active)


func _show_fin_feedback() -> void:
	if is_instance_valid(_level) and _level.has_method(&"show_item_reward_feedback"):
		_level.call(&"show_item_reward_feedback", PICKUP_REWARD_FIN)


func _disconnect_level_pickups() -> void:
	if is_instance_valid(_connected_level) and _connected_level.greatfin_pickup_requested.is_connected(_on_greatfin_pickup_requested):
		_connected_level.greatfin_pickup_requested.disconnect(_on_greatfin_pickup_requested)
	_connected_level = null


func _disconnect_game_state() -> void:
	if _connected_game_state != null:
		if _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
			_connected_game_state.greatfin_changed.disconnect(_on_greatfin_changed)
		if _connected_game_state.defeat_state_changed.is_connected(_on_defeat_state_changed):
			_connected_game_state.defeat_state_changed.disconnect(_on_defeat_state_changed)
	_connected_game_state = null
