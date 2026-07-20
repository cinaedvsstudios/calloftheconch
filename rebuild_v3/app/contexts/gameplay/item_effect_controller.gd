class_name CotcItemEffectController
extends Node2D

signal conch_used

const CONUS_TETHER_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/conus_textile/conus_tether_projectile.tscn"
)
const INK_BLOB_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/argonauta/ink_blob_projectile.tscn"
)
const INK_CLOUD_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/argonauta/ink_paralysis_cloud.tscn"
)

const BEHAVIOR_NORMAL_CONCH: StringName = &"normal_conch"
const BEHAVIOR_SUPER_CONCH: StringName = &"super_conch"
const BEHAVIOR_SONIC_DRILL: StringName = &"sonic_drill"
const BEHAVIOR_DART_TETHER: StringName = &"dart_tether"
const BEHAVIOR_PURPLE_SHIELD: StringName = &"purple_shield"
const BEHAVIOR_SURGE: StringName = &"surge"
const BEHAVIOR_CAMOUFLAGE: StringName = &"camouflage_veil"
const BEHAVIOR_INK_PRISON: StringName = &"ink_prison"
const BEHAVIOR_CROWN_SEA_GRAPES: StringName = &"crown_sea_grapes"
const BEHAVIOR_SEAWEED_GRAPES_BOX: StringName = &"seaweed_grapes_box"

const CONCH_PROFILE_NORMAL: StringName = &"normal_conch"
const CONCH_PROFILE_SUPER: StringName = &"super_conch"
const CONCH_PROFILE_TEREBRIDAE: StringName = &"terebridae"

@export_category("Consumables")
@export_range(1, 8, 1) var seaweed_grapes_heal_amount: int = 1

@export_category("Conch Pulse")
@export_range(0.0, 300.0, 1.0) var conch_origin_forward_offset: float = 105.0

@export_category("Item B Durations")
@export_range(0.1, 30.0, 0.1) var purple_shield_seconds: float = 30.0
@export_range(0.1, 10.0, 0.05) var surge_seconds: float = 0.90
@export_range(0.1, 30.0, 0.1) var camouflage_seconds: float = 30.0

@export_category("Special Conch Profiles")
@export var super_conch_tint: Color = Color(0.20, 1.0, 0.48, 1.0)
@export_range(1.0, 180.0, 1.0) var super_conch_arc_degrees: float = 78.0
@export_range(0.0, 8.0, 0.05) var super_conch_brightness: float = 2.10
@export var sonic_drill_tint: Color = Color(1.0, 0.08, 0.88, 1.0)
@export_range(1.0, 180.0, 1.0) var sonic_drill_arc_degrees: float = 18.0
@export_range(0.0, 8.0, 0.05) var sonic_drill_brightness: float = 2.25

@onready var _video_anchor: Node2D = %HylasVideoAnchor
@onready var _transform_effect: VideoStreamPlayer = %TransformEffect
@onready var _purple_shield_effect: VideoStreamPlayer = %PurpleShieldEffect
@onready var _surge_effect: VideoStreamPlayer = %SurgeEffect
@onready var _conch_pulse: CotcConchPulse = %ConchPulse
@onready var _projectiles: Node2D = %Projectiles
@onready var _clouds: Node2D = %Clouds

var _context: Node
var _level: CotcSeaOfPillars
var _hylas: CotcHylas
var _game_state: CotcGameState
var _active: bool = false
var _purple_shield_remaining: float = 0.0
var _surge_remaining: float = 0.0
var _camouflage_remaining: float = 0.0
var _active_conus_tether: CotcConusTetherProjectile
var _connected_conch_context: Node
var _connected_hylas_for_conch: CotcHylas

const PICKUP_REWARD_FIN: StringName = &"fin"
const ITEM_MUREX_PECTEN: StringName = &"murex_pecten"
const ITEM_HALIOTIS: StringName = &"haliotis"
const ITEM_ARGONAUTA: StringName = &"argonauta"
const BEHAVIOR_WORLD_FREEZE: StringName = &"world_freeze"
const BEHAVIOR_TYCHE: StringName = &"tyche_margarites"
const BEHAVIOR_LEAF_SHEEP: StringName = &"leaf_sheep"
const ITEM_LEAF_SHEEP: StringName = &"leaf_sheep"
const ITEM_SLOT_B: StringName = &"item_b"

@onready var _morph_audio: AudioStreamPlayer = %MorphAudio
@onready var _powerdown_audio: AudioStreamPlayer = %PowerdownAudio
@onready var _shield_audio: AudioStreamPlayer = %ShieldAudio
@onready var _invisibility_audio: AudioStreamPlayer = %InvisibilityAudio
@onready var _conus_audio: AudioStreamPlayer = %ConusAudio
@onready var _terebridae_audio: AudioStreamPlayer = %TerebridaeAudio
@onready var _mati_initial_audio: AudioStreamPlayer = %MatiInitialAudio
@onready var _mati_duration_audio: AudioStreamPlayer = %MatiDurationAudio
@onready var _leaf_sheep: CotcLeafSheep = %LeafSheep

var _connected_level: CotcSeaOfPillars
var _connected_game_state: CotcGameState
var _morph_tween: Tween
var _status_countdown: CotcStatusCountdownOverlay
var _mati_active: bool = false
var _mati_elapsed: float = 0.0
var _mati_phase: float = 0.0
var _gameplay_hud: CotcGameplayHud
var _mati_targets: Dictionary = {}
var _mati_tick_phase: float = 0.0
var _mati_hylas_process_mode: int = Node.PROCESS_MODE_INHERIT
var _mati_water_material: ShaderMaterial
var _mati_waterline_material: ShaderMaterial
var _mati_visual_time: float = 0.0
var _leaf_sheep_hud_active: bool = false


func _ready() -> void:
	_transform_effect.loop = false
	_purple_shield_effect.loop = true
	_surge_effect.loop = true
	_transform_effect.finished.connect(_on_transform_effect_finished)
	_stop_video(_transform_effect)
	_stop_video(_purple_shield_effect)
	_stop_video(_surge_effect)
	if is_instance_valid(_conch_pulse):
		_conch_pulse.stop()
	set_process(false)
	if not _shield_audio.finished.is_connected(_on_shield_audio_finished):
		_shield_audio.finished.connect(_on_shield_audio_finished)
	if not _invisibility_audio.finished.is_connected(_on_invisibility_audio_finished):
		_invisibility_audio.finished.connect(_on_invisibility_audio_finished)
	if not _mati_duration_audio.finished.is_connected(_on_mati_duration_audio_finished):
		_mati_duration_audio.finished.connect(_on_mati_duration_audio_finished)


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_disconnect_level_pickups()
	_disconnect_conch_context()
	_disconnect_hylas_normal_conch()
	_context = context
	_level = level
	_hylas = hylas
	_disconnect_level_normal_conch_route()
	_connect_conch_context()
	_connect_hylas_normal_conch()
	_update_video_anchor()

	_connected_level = level
	_status_countdown = null
	_gameplay_hud = null
	if context != null:
		_gameplay_hud = context.get_node_or_null("GameplayUI/GameplayHud") as CotcGameplayHud
		if is_instance_valid(_gameplay_hud):
			_status_countdown = (
				_gameplay_hud.get_node_or_null("ItemStatusCountdown") as CotcStatusCountdownOverlay
			)
	if (
		is_instance_valid(_connected_level)
		and not _connected_level.greatfin_pickup_requested.is_connected(
			_on_greatfin_pickup_requested
		)
	):
		_connected_level.greatfin_pickup_requested.connect(_on_greatfin_pickup_requested)
	_refresh_status_countdown()
	_leaf_sheep.configure(context, level, hylas)


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_game_state()
	_game_state = game_state
	_connected_game_state = game_state
	if _connected_game_state != null:
		if not _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
			_connected_game_state.greatfin_changed.connect(_on_greatfin_changed)
		if not _connected_game_state.defeat_state_changed.is_connected(_on_defeat_state_changed):
			_connected_game_state.defeat_state_changed.connect(_on_defeat_state_changed)
	_sync_greatfin_visual()
	_leaf_sheep.bind_game_state(game_state)


func set_active(is_active: bool) -> void:
	if not is_active:
		_leaf_sheep.force_deactivate(&"gameplay_inactive")
	_leaf_sheep.set_gameplay_active(is_active)
	_active = is_active
	set_process(is_active)
	if not is_active:
		clear_active_effects()


func handle_item_behavior(
	behavior_id: StringName,
	item_id: StringName,
	_slot_id: StringName,
	origin: Vector2,
	direction: Vector2,
) -> bool:
	if behavior_id == BEHAVIOR_LEAF_SHEEP and item_id == ITEM_LEAF_SHEEP:
		return _leaf_sheep.toggle_activation()
	if behavior_id == BEHAVIOR_WORLD_FREEZE:
		return _activate_mati()
	if behavior_id == BEHAVIOR_TYCHE:
		return _connected_game_state != null and _connected_game_state.activate_tyche_margarites()
	if not _active or not is_instance_valid(_hylas):
		return false
	match behavior_id:
		BEHAVIOR_SUPER_CONCH:
			return _activate_profiled_conch(behavior_id, origin, direction)
		BEHAVIOR_SONIC_DRILL:
			return _activate_profiled_conch(behavior_id, origin, direction)
		BEHAVIOR_DART_TETHER:
			return _activate_conus_dart(origin, direction)
		BEHAVIOR_PURPLE_SHIELD:
			return _activate_purple_shield()
		BEHAVIOR_SURGE:
			return _activate_surge()
		BEHAVIOR_CAMOUFLAGE:
			return _activate_camouflage()
		BEHAVIOR_INK_PRISON:
			return _activate_ink_prison(origin, direction)
		BEHAVIOR_CROWN_SEA_GRAPES:
			return _activate_crown_sea_grapes()
		BEHAVIOR_SEAWEED_GRAPES_BOX:
			return _activate_seaweed_grapes_box()
		_:
			return false


func _process(delta: float) -> void:
	_update_mati(delta)
	if _active:
		_update_video_anchor()

		if _purple_shield_remaining > 0.0:
			_purple_shield_remaining = maxf(0.0, _purple_shield_remaining - delta)
			if _purple_shield_remaining <= 0.0:
				_stop_purple_shield()

		if _surge_remaining > 0.0:
			_surge_remaining = maxf(0.0, _surge_remaining - delta)
			var surge_still_active: bool = (
				_hylas.has_method(&"is_item_surge_active")
				and bool(_hylas.call(&"is_item_surge_active"))
			)
			if _surge_remaining <= 0.0 or not surge_still_active:
				_stop_surge()

		if _camouflage_remaining > 0.0:
			_camouflage_remaining = maxf(0.0, _camouflage_remaining - delta)
			if _camouflage_remaining <= 0.0:
				_stop_camouflage()
	if _surge_remaining > 0.0 and not Input.is_action_pressed(&"utility_item"):
		_stop_surge()
	_refresh_status_countdown()
	_refresh_leaf_sheep_hud()


func clear_active_effects() -> void:
	_leaf_sheep.force_deactivate(&"effects_cleared")
	_clear_leaf_sheep_hud_active()
	_shield_audio.stop()
	_invisibility_audio.stop()
	_conus_audio.stop()
	_terebridae_audio.stop()
	_mati_initial_audio.stop()
	_mati_duration_audio.stop()
	if _mati_active:
		_finish_mati()

	_purple_shield_remaining = 0.0
	_surge_remaining = 0.0
	_camouflage_remaining = 0.0
	_stop_video(_transform_effect)
	_stop_video(_purple_shield_effect)
	_stop_video(_surge_effect)
	if is_instance_valid(_conch_pulse):
		_conch_pulse.stop()
	if is_instance_valid(_hylas) and _hylas.has_method(&"clear_item_effect_state"):
		_hylas.call(&"clear_item_effect_state")
	_active_conus_tether = null
	for child: Node in _projectiles.get_children():
		child.queue_free()
	for child: Node in _clouds.get_children():
		child.queue_free()
	if is_instance_valid(_status_countdown):
		_status_countdown.clear_countdown()


func _activate_profiled_conch(
	behavior_id: StringName,
	origin: Vector2,
	direction: Vector2,
) -> bool:
	if not _hylas.has_method(&"activate_item_a_pose"):
		return false
	if not bool(_hylas.call(&"activate_item_a_pose", direction)):
		return false
	var profile: Dictionary = {}
	if behavior_id == BEHAVIOR_SUPER_CONCH:
		profile = {
			"emission_profile_id": CONCH_PROFILE_SUPER,
			"arc_degrees": super_conch_arc_degrees,
			"close_range_arc_degrees": maxf(120.0, super_conch_arc_degrees),
			"brightness": super_conch_brightness,
			"tint": super_conch_tint,
			"flash_tint": super_conch_tint,
			"echo_alpha_decay": 0.08,
		}
	else:
		profile = {
			"emission_profile_id": CONCH_PROFILE_TEREBRIDAE,
			"arc_degrees": sonic_drill_arc_degrees,
			"close_range_arc_degrees": 38.0,
			"brightness": sonic_drill_brightness,
			"tint": sonic_drill_tint,
			"flash_tint": sonic_drill_tint,
			"echo_alpha_decay": 0.06,
			"pulse_interval_scale": 0.48,
			"stream_duration": 5.0,
		}
	_trigger_conch_pulse(origin, direction, profile)
	if behavior_id == BEHAVIOR_SONIC_DRILL and _terebridae_audio.stream != null:
		_terebridae_audio.stop()
		_terebridae_audio.play()
	return true


func _trigger_conch_pulse(origin: Vector2, direction: Vector2, profile: Dictionary) -> bool:
	if not is_instance_valid(_conch_pulse):
		return false
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()
	var pulse_origin: Vector2 = origin + pulse_direction * conch_origin_forward_offset
	if profile.is_empty():
		_conch_pulse.trigger_from_player(pulse_origin, pulse_direction, origin)
	elif _conch_pulse.has_method(&"trigger_profile_from_player"):
		(
			_conch_pulse
			. call(
				&"trigger_profile_from_player",
				pulse_origin,
				pulse_direction,
				origin,
				profile,
			)
		)
	else:
		_conch_pulse.trigger_from_player(pulse_origin, pulse_direction, origin)
	conch_used.emit()
	return true


func _on_hylas_normal_conch_used(origin: Vector2, direction: Vector2) -> void:
	if not _active:
		return
	_trigger_conch_pulse(origin, direction, {"emission_profile_id": CONCH_PROFILE_NORMAL})


func _connect_hylas_normal_conch() -> void:
	if not is_instance_valid(_hylas) or not _hylas.has_signal(&"normal_conch_used"):
		return
	var callback: Callable = Callable(self, "_on_hylas_normal_conch_used")
	if not _hylas.is_connected(&"normal_conch_used", callback):
		_hylas.connect(&"normal_conch_used", callback)
	_connected_hylas_for_conch = _hylas


func _disconnect_hylas_normal_conch() -> void:
	if not is_instance_valid(_connected_hylas_for_conch):
		_connected_hylas_for_conch = null
		return
	var callback: Callable = Callable(self, "_on_hylas_normal_conch_used")
	if _connected_hylas_for_conch.is_connected(&"normal_conch_used", callback):
		_connected_hylas_for_conch.disconnect(&"normal_conch_used", callback)
	_connected_hylas_for_conch = null


func _disconnect_level_normal_conch_route() -> void:
	if not is_instance_valid(_level) or not is_instance_valid(_hylas):
		return
	var level_callback: Callable = Callable(_level, "_on_hylas_normal_conch_used")
	if _hylas.is_connected(&"normal_conch_used", level_callback):
		_hylas.disconnect(&"normal_conch_used", level_callback)


func _connect_conch_context() -> void:
	if _context == null or not _context.has_method(&"_on_level_conch_used"):
		return
	var callback: Callable = Callable(_context, "_on_level_conch_used")
	if not conch_used.is_connected(callback):
		conch_used.connect(callback)
	_connected_conch_context = _context


func _disconnect_conch_context() -> void:
	if _connected_conch_context == null:
		return
	var callback: Callable = Callable(_connected_conch_context, "_on_level_conch_used")
	if conch_used.is_connected(callback):
		conch_used.disconnect(callback)
	_connected_conch_context = null


func _activate_conus_dart(origin: Vector2, direction: Vector2) -> bool:
	var was_retracting: bool = is_instance_valid(_active_conus_tether)
	if was_retracting:
		_active_conus_tether.retract()
		_active_conus_tether = null
		return true
	if not _hylas.has_method(&"activate_item_a_pose"):
		return false
	if not bool(_hylas.call(&"activate_item_a_pose", direction)):
		return false
	var resolved_direction: Vector2 = (
		direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	)
	var projectile: CotcConusTetherProjectile = (
		CONUS_TETHER_SCENE.instantiate() as CotcConusTetherProjectile
	)
	if projectile == null:
		return false
	_projectiles.add_child(projectile)
	_active_conus_tether = projectile
	(
		projectile
		. tether_finished
		. connect(
			_on_conus_tether_finished.bind(projectile),
			Object.CONNECT_ONE_SHOT,
		)
	)
	projectile.launch(origin + resolved_direction * 92.0, resolved_direction, _hylas)
	if _conus_audio.stream != null:
		_conus_audio.stop()
		_conus_audio.play()
	return true


func _on_conus_tether_finished(projectile: CotcConusTetherProjectile) -> void:
	if _active_conus_tether == projectile:
		_active_conus_tether = null


func _activate_purple_shield() -> bool:
	_purple_shield_remaining = purple_shield_seconds
	if _hylas.has_method(&"set_purple_shield_active"):
		_hylas.call(&"set_purple_shield_active", true)
	_play_looping_video(_purple_shield_effect)
	_shield_audio.stop()
	_shield_audio.play()
	_refresh_status_countdown()
	return true


func _stop_purple_shield() -> void:
	_shield_audio.stop()
	_purple_shield_remaining = 0.0
	if is_instance_valid(_hylas) and _hylas.has_method(&"set_purple_shield_active"):
		_hylas.call(&"set_purple_shield_active", false)
	_stop_video(_purple_shield_effect)


func _activate_surge() -> bool:
	if not _hylas.has_method(&"activate_item_surge"):
		return false
	if not bool(_hylas.call(&"activate_item_surge", surge_seconds)):
		return false
	_surge_remaining = surge_seconds
	if _hylas.has_method(&"set_surge_glow_active"):
		_hylas.call(&"set_surge_glow_active", true)
	_play_looping_video(_surge_effect)
	return true


func _stop_surge() -> void:
	_surge_remaining = 0.0
	if is_instance_valid(_hylas) and _hylas.has_method(&"set_surge_glow_active"):
		_hylas.call(&"set_surge_glow_active", false)
	_stop_video(_surge_effect)


func _activate_camouflage() -> bool:
	_camouflage_remaining = camouflage_seconds
	if _hylas.has_method(&"set_camouflage_active"):
		_hylas.call(&"set_camouflage_active", true)
	_invisibility_audio.stop()
	_invisibility_audio.play()
	_refresh_status_countdown()
	return true


func _stop_camouflage() -> void:
	_invisibility_audio.stop()
	_camouflage_remaining = 0.0
	if is_instance_valid(_hylas) and _hylas.has_method(&"set_camouflage_active"):
		_hylas.call(&"set_camouflage_active", false)


func _activate_ink_prison(origin: Vector2, direction: Vector2) -> bool:
	var resolved_direction: Vector2 = direction
	if resolved_direction.length_squared() <= 0.0001:
		var sprite: AnimatedSprite2D = _hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
		resolved_direction = Vector2.LEFT if sprite != null and sprite.flip_h else Vector2.RIGHT
	resolved_direction = resolved_direction.normalized()
	var projectile: CotcInkBlobProjectile = INK_BLOB_SCENE.instantiate() as CotcInkBlobProjectile
	if projectile == null:
		return false
	_projectiles.add_child(projectile)
	projectile.impacted.connect(_on_ink_blob_impacted)
	projectile.launch(origin + resolved_direction * 82.0, resolved_direction, _hylas)
	return true


func _on_ink_blob_impacted(impact_position: Vector2) -> void:
	var cloud: CotcInkParalysisCloud = INK_CLOUD_SCENE.instantiate() as CotcInkParalysisCloud
	if cloud == null:
		return
	_clouds.add_child(cloud)
	cloud.play_cloud(impact_position)


func _activate_crown_sea_grapes() -> bool:
	if _game_state == null or _game_state.greatfin_active:
		return false
	if not _game_state.activate_greatfin():
		return false
	_play_one_shot_video(_transform_effect)
	_show_fin_feedback()
	return true


func _activate_seaweed_grapes_box() -> bool:
	if _game_state == null:
		return false
	var healed: bool = _game_state.heal_fins(seaweed_grapes_heal_amount) > 0
	if healed:
		_show_fin_feedback()
	return healed


func _update_video_anchor() -> void:
	if not is_instance_valid(_hylas):
		return
	_video_anchor.global_position = _hylas.global_position
	var sprite: AnimatedSprite2D = _hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if sprite == null:
		return
	_surge_effect.rotation = sprite.rotation
	_surge_effect.scale.x = (
		-absf(_surge_effect.scale.x) if sprite.flip_h else absf(_surge_effect.scale.x)
	)


func _play_one_shot_video(video: VideoStreamPlayer) -> void:
	if video.stream == null:
		return
	video.loop = false
	video.modulate.a = 1.0
	video.show()
	video.stop()
	video.play()


func _play_looping_video(video: VideoStreamPlayer) -> void:
	if video.stream == null:
		return
	video.loop = true
	video.modulate.a = 1.0
	video.show()
	if not video.is_playing():
		video.play()


func _stop_video(video: VideoStreamPlayer) -> void:
	video.stop()
	video.hide()


func _on_transform_effect_finished() -> void:
	_transform_effect.hide()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[ItemEffectController]",
		"active=%s" % str(_active),
		"purple_shield_remaining=%.2f" % _purple_shield_remaining,
		"surge_remaining=%.2f" % _surge_remaining,
		"camouflage_remaining=%.2f" % _camouflage_remaining,
		"projectiles=%d" % _projectiles.get_child_count(),
		"ink_clouds=%d" % _clouds.get_child_count(),
	]
	if is_instance_valid(_conch_pulse):
		lines.append_array(_conch_pulse.get_debug_lines())
	if is_instance_valid(_leaf_sheep):
		lines.append_array(_leaf_sheep.get_debug_lines())
	lines.append("leaf_sheep_hud_active=%s" % str(_leaf_sheep_hud_active))
	return lines


func _on_shield_audio_finished() -> void:
	if _purple_shield_remaining > 0.0:
		_shield_audio.play()


func _on_invisibility_audio_finished() -> void:
	if _camouflage_remaining > 0.0:
		_invisibility_audio.play()


func _on_mati_duration_audio_finished() -> void:
	if _mati_active:
		_mati_duration_audio.play()


func _exit_tree() -> void:
	_disconnect_level_pickups()
	_disconnect_game_state()


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
			if (
				child == self
				or child.name == &"GameplayUI"
				or child.name == &"ItemEffectController"
			):
				continue
			_mati_targets[child.get_instance_id()] = {
				"node": child,
				"process_mode": child.process_mode,
			}
		var water_mottle: CanvasItem = (
			_context.get_node_or_null("SeaEnvironment/AtmosphereEffects/WaterMottle") as CanvasItem
		)
		if is_instance_valid(water_mottle) and water_mottle.material is ShaderMaterial:
			_mati_water_material = water_mottle.material as ShaderMaterial
			_mati_water_material.set_shader_parameter(&"mati_manual_time", _mati_visual_time)
			_mati_water_material.set_shader_parameter(&"mati_use_manual_time", true)
	if is_instance_valid(_connected_level):
		var waterlines: CanvasItem = (
			_connected_level.get_node_or_null("ParallaxLayer/waterlines") as CanvasItem
		)
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


func _refresh_status_countdown() -> void:
	if not is_instance_valid(_status_countdown):
		return
	if _mati_active:
		_set_item_b_timed_active(true)
		_status_countdown.set_mati_progress(_mati_elapsed)
		return
	if _purple_shield_remaining > 0.0:
		_set_item_b_timed_active(true)
		(
			_status_countdown
			. set_countdown(
				ITEM_MUREX_PECTEN,
				_purple_shield_remaining,
				purple_shield_seconds,
			)
		)
		return
	if _camouflage_remaining > 0.0:
		_set_item_b_timed_active(true)
		(
			_status_countdown
			. set_countdown(
				ITEM_HALIOTIS,
				_camouflage_remaining,
				camouflage_seconds,
			)
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
	if (
		is_instance_valid(_connected_level)
		and _connected_level.greatfin_pickup_requested.is_connected(_on_greatfin_pickup_requested)
	):
		_connected_level.greatfin_pickup_requested.disconnect(_on_greatfin_pickup_requested)
	_connected_level = null


func _disconnect_game_state() -> void:
	if _connected_game_state != null:
		if _connected_game_state.greatfin_changed.is_connected(_on_greatfin_changed):
			_connected_game_state.greatfin_changed.disconnect(_on_greatfin_changed)
		if _connected_game_state.defeat_state_changed.is_connected(_on_defeat_state_changed):
			_connected_game_state.defeat_state_changed.disconnect(_on_defeat_state_changed)
	_connected_game_state = null


func force_deactivate_leaf_sheep(reason: StringName) -> void:
	_leaf_sheep.force_deactivate(reason)
	_refresh_leaf_sheep_hud()


func set_leaf_sheep_gameplay_active(is_active: bool) -> void:
	_leaf_sheep.set_gameplay_active(is_active)


func set_leaf_sheep_darkness_profile(
	profile_id: StringName,
	darkness_strength: float,
	darkness_tint: Color = Color(0.004, 0.012, 0.055, 1.0),
) -> void:
	_leaf_sheep.set_darkness_profile(profile_id, darkness_strength, darkness_tint)


func _refresh_leaf_sheep_hud() -> void:
	if not is_instance_valid(_leaf_sheep):
		return
	var leaf_sheep_equipped: bool = (
		_game_state != null and _game_state.get_equipped_item(ITEM_SLOT_B) == ITEM_LEAF_SHEEP
	)
	if _leaf_sheep.is_active():
		_set_item_b_timed_active(true)
		_leaf_sheep_hud_active = true
	elif _leaf_sheep_hud_active:
		_clear_leaf_sheep_hud_active()
	if not is_instance_valid(_status_countdown):
		return
	if _leaf_sheep.get_phase_remaining() > 0.0:
		(
			_status_countdown
			. set_countdown(
				ITEM_LEAF_SHEEP,
				_leaf_sheep.get_phase_remaining(),
				_leaf_sheep.get_phase_duration(),
			)
		)
	elif (
		leaf_sheep_equipped
		and _leaf_sheep.is_cooling_down()
		and _leaf_sheep.get_cooldown_remaining() > 0.0
	):
		(
			_status_countdown
			. set_countdown(
				ITEM_LEAF_SHEEP,
				_leaf_sheep.get_cooldown_remaining(),
				_leaf_sheep.cooldown_duration,
			)
		)
	elif _status_countdown.get_active_item_id() == ITEM_LEAF_SHEEP:
		_status_countdown.clear_countdown()


func _clear_leaf_sheep_hud_active() -> void:
	if not _leaf_sheep_hud_active:
		return
	_leaf_sheep_hud_active = false
	_set_item_b_timed_active(false)
