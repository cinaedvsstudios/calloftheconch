extends "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.gd"

const PICKUP_REWARD_FIN: StringName = &"fin"

@onready var _morph_audio: AudioStreamPlayer = %MorphAudio
@onready var _powerdown_audio: AudioStreamPlayer = %PowerdownAudio
@onready var _shield_audio: AudioStreamPlayer = %ShieldAudio
@onready var _invisibility_audio: AudioStreamPlayer = %InvisibilityAudio

var _connected_level: CotcSeaOfPillars
var _connected_game_state: CotcGameState
var _morph_tween: Tween

func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_disconnect_level_pickups()
	super.configure(context, level, hylas)
	_connected_level = level
	if is_instance_valid(_connected_level) and not _connected_level.greatfin_pickup_requested.is_connected(_on_greatfin_pickup_requested):
		_connected_level.greatfin_pickup_requested.connect(_on_greatfin_pickup_requested)

func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_game_state()
	super.bind_game_state(game_state)
	_connected_game_state = game_state
	if _connected_game_state != null and not _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
		_connected_game_state.greatfin_changed.connect(_on_greatfin_changed)
	_sync_greatfin_visual()

func _process(delta: float) -> void:
	super._process(delta)
	if _surge_remaining > 0.0 and not Input.is_action_pressed(&"utility_item"):
		_stop_surge()

func _exit_tree() -> void:
	_disconnect_level_pickups()
	_disconnect_game_state()

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
	return activated

func _activate_camouflage() -> bool:
	var activated: bool = super._activate_camouflage()
	if activated:
		_invisibility_audio.stop()
		_invisibility_audio.play()
	return activated

func _on_greatfin_pickup_requested(_pickup_type_id: StringName) -> void:
	if _active:
		_play_one_shot_video(_transform_effect)

func _on_greatfin_changed(_is_active: bool) -> void:
	_play_greatfin_transition()

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
	if _connected_game_state != null and _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
		_connected_game_state.greatfin_changed.disconnect(_on_greatfin_changed)
	_connected_game_state = null
