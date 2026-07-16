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
@onready var _conus_audio: AudioStreamPlayer = %ConusAudio
@onready var _terebridae_audio: AudioStreamPlayer = %TerebridaeAudio
@onready var _mati_initial_audio: AudioStreamPlayer = %MatiInitialAudio
@onready var _mati_duration_audio: AudioStreamPlayer = %MatiDurationAudio

var _connected_level: CotcSeaOfPillars
var _connected_game_state: CotcGameState
var _morph_tween: Tween
var _status_countdown: CotcStatusCountdownOverlay
var _mati_active := false
var _mati_elapsed := 0.0
var _mati_phase := 0.0
var _gameplay_hud: CotcGameplayHud
var _mati_targets: Dictionary = {}
var _mati_tick_phase: float = 0.0
var _mati_hylas_process_mode: int = Node.PROCESS_MODE_INHERIT
var _mati_water_material: ShaderMaterial
var _mati_waterline_material: ShaderMaterial
var _mati_visual_time: float = 0.0


func _ready() -> void:
	super._ready()
	if not _shield_audio.finished.is_connected(_on_shield_audio_finished):
		_shield_audio.finished.connect(_on_shield_audio_finished)
	if not _invisibility_audio.finished.is_connected(_on_invisibility_audio_finished):
		_invisibility_audio.finished.connect(_on_invisibility_audio_finished)
	if not _mati_duration_audio.finished.is_connected(_on_mati_duration_audio_finished):
		_mati_duration_audio.finished.connect(_on_mati_duration_audio_finished)


func _on_shield_audio_finished() -> void:
	if _purple_shield_remaining > 0.0:
		_shield_audio.play()


func _on_invisibility_audio_finished() -> void:
	if _camouflage_remaining > 0.0:
		_invisibility_audio.play()


func _on_mati_duration_audio_finished() -> void:
	if _mati_active:
		_mati_duration_audio.play()


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_disconnect_level_pickups()
	super.configure(context, level, hylas)
	_connected_level = level
	_status_countdown = null
	_gameplay_hud = null
	if context != null:
		_gameplay_hud = context.get_node_or_null("GameplayUI/GameplayHud") as CotcGameplayHud
		_status_countdown = _gameplay_hud.get_node_or_null("ItemStatusCountdown") as CotcStatusCountdownOverlay if is_instance_valid(_gameplay_hud) else null
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


func _activate_profiled_conch(
		behavior_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	var activated: bool = super._activate_profiled_conch(behavior_id, origin, direction)
	if activated and behavior_id == BEHAVIOR_SONIC_DRILL and _terebridae_audio.stream != null:
		_terebridae_audio.stop()
		_terebridae_audio.play()
	return activated


func _activate_conus_dart(origin: Vector2, direction: Vector2) -> bool:
	var was_retracting: bool = is_instance_valid(_active_conus_tether)
	var activated: bool = super._activate_conus_dart(origin, direction)
	if activated and not was_retracting and _conus_audio.stream != null:
		_conus_audio.stop()
		_conus_audio.play()
	return activated


func _activate_mati() -> bool:
	if _mati_active or not is_instance_valid(_hylas):
		return false
	_mati_active = true
	_mati_elapsed = 0.0
	_mati_tick_phase = 0.0
	if _mati_initial_audio.stream != null:
		_mati_initial_audio.stop()
		_mati_initial_audio.play()
	if _mati_duration_audio.stream != null:
		_mati_duration_audio.stop()
		_mati_duration_audio.play()
	_capture_mati_targets()
	_set_item_b_timed_active(true)
	if is_instance_valid(_status_countdown):
		_status_countdown.set_mati_progress(0.0)
	return true


func _update_mati(delta: float) -> void:
	if not _mati_active:
		return
	_mati_elapsed = minf(30.0, _mati_elapsed + maxf(delta, 0.0))
	var world_activity: float
	if _mati_elapsed < 5.0:
		world_activity = 1.0 - (_mati_elapsed / 5.0)
	elif _mati_elapsed < 25.0:
		world_activity = 0.0
	else:
		world_activity = (_mati_elapsed - 25.0) / 5.0
	_apply_mati_world_activity(clampf(world_activity, 0.0, 1.0), delta)
	if is_instance_valid(_status_countdown):
		_status_countdown.set_mati_progress(_mati_elapsed)
	if _mati_elapsed >= 30.0:
		_finish_mati()


func _capture_mati_targets() -> void:
	_mati_targets.clear()
	_mati_tick_phase = 0.0
	_mati_visual_time = float(Time.get_ticks_msec()) / 1000.0
	_mati_water_material = null
	_mati_waterline_material = null
	if is_instance_valid(_hylas):
		_mati_hylas_process_mode = _hylas.process_mode
		_hylas.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(_context):
		for child: Node in _context.get_children():
			if child == self or child.name == &"GameplayUI" or child.name == &"ItemEffectController":
				continue
			_mati_targets[child.get_instance_id()] = {
				"node": child,
				"process_mode": child.process_mode,
			}
		var water_mottle: CanvasItem = _context.get_node_or_null(
			"SeaEnvironment/AtmosphereEffects/WaterMottle"
		) as CanvasItem
		if is_instance_valid(water_mottle) and water_mottle.material is ShaderMaterial:
			_mati_water_material = water_mottle.material as ShaderMaterial
			_mati_water_material.set_shader_parameter(&"mati_manual_time", _mati_visual_time)
			_mati_water_material.set_shader_parameter(&"mati_use_manual_time", true)
	if is_instance_valid(_connected_level):
		var waterlines: CanvasItem = _connected_level.get_node_or_null("ParallaxLayer/waterlines") as CanvasItem
		if is_instance_valid(waterlines) and waterlines.material is ShaderMaterial:
			_mati_waterline_material = waterlines.material as ShaderMaterial
			_mati_waterline_material.set_shader_parameter(&"mati_manual_time", _mati_visual_time)
			_mati_waterline_material.set_shader_parameter(&"mati_use_manual_time", true)


func _apply_mati_world_activity(activity: float, delta: float) -> void:
	_mati_tick_phase = fmod(_mati_tick_phase + maxf(delta, 0.0) * 12.0, 1.0)
	_mati_visual_time += maxf(delta, 0.0) * activity
	if is_instance_valid(_mati_water_material):
		_mati_water_material.set_shader_parameter(&"mati_manual_time", _mati_visual_time)
	if is_instance_valid(_mati_waterline_material):
		_mati_waterline_material.set_shader_parameter(&"mati_manual_time", _mati_visual_time)
	var allow_tick: bool = activity >= 0.999 or _mati_tick_phase < activity
	for entry_value: Variant in _mati_targets.values():
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var node: Node = entry.get("node") as Node
		if not is_instance_valid(node):
			continue
		var original_mode: int = int(entry.get("process_mode", Node.PROCESS_MODE_INHERIT))
		node.process_mode = original_mode if allow_tick else Node.PROCESS_MODE_DISABLED


func _finish_mati() -> void:
	_mati_initial_audio.stop()
	_mati_duration_audio.stop()
	for entry_value: Variant in _mati_targets.values():
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var node: Node = entry.get("node") as Node
		if is_instance_valid(node):
			node.process_mode = int(entry.get("process_mode", Node.PROCESS_MODE_INHERIT))
	_mati_targets.clear()
	if is_instance_valid(_hylas):
		_hylas.process_mode = _mati_hylas_process_mode
	if is_instance_valid(_mati_water_material):
		_mati_water_material.set_shader_parameter(&"mati_use_manual_time", false)
	_mati_water_material = null
	if is_instance_valid(_mati_waterline_material):
		_mati_waterline_material.set_shader_parameter(&"mati_use_manual_time", false)
	_mati_waterline_material = null
	_mati_active = false
	_mati_elapsed = 0.0
	_set_item_b_timed_active(false)
	if is_instance_valid(_status_countdown):
		_status_countdown.clear_countdown()


func _set_item_b_timed_active(is_active: bool) -> void:
	if is_instance_valid(_gameplay_hud):
		_gameplay_hud.set_item_b_timed_active(is_active)


func clear_active_effects() -> void:
	_shield_audio.stop()
	_invisibility_audio.stop()
	_conus_audio.stop()
	_terebridae_audio.stop()
	_mati_initial_audio.stop()
	_mati_duration_audio.stop()
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


func _stop_purple_shield() -> void:
	_shield_audio.stop()
	super._stop_purple_shield()


func _stop_camouflage() -> void:
	_invisibility_audio.stop()
	super._stop_camouflage()


func _on_ink_blob_impacted(impact_position: Vector2) -> void:
	var cloud: CotcInkParalysisCloud = INK_CLOUD_SCENE.instantiate() as CotcInkParalysisCloud
	if cloud == null:
		return
	_clouds.add_child(cloud)
	cloud.play_cloud(impact_position)


func _refresh_status_countdown() -> void:
	if not is_instance_valid(_status_countdown):
		return
	if _mati_active:
		_set_item_b_timed_active(true)
		_status_countdown.set_mati_progress(_mati_elapsed)
		return
	if _purple_shield_remaining > 0.0:
		_set_item_b_timed_active(true)
		_status_countdown.set_countdown(
			ITEM_MUREX_PECTEN,
			_purple_shield_remaining,
			purple_shield_seconds,
		)
		return
	if _camouflage_remaining > 0.0:
		_set_item_b_timed_active(true)
		_status_countdown.set_countdown(
			ITEM_HALIOTIS,
			_camouflage_remaining,
			camouflage_seconds,
		)
		return
	_status_countdown.clear_countdown()
	_set_item_b_timed_active(false)


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
