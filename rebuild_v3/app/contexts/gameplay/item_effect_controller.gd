class_name CotcItemEffectController
extends Node2D

const CONUS_TETHER_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/conus_textile/conus_tether_projectile.tscn"
)
const INK_BLOB_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/argonauta/ink_blob_projectile.tscn"
)
const INK_CLOUD_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/shared/items/argonauta/ink_paralysis_cloud.tscn"
)

const BEHAVIOR_SUPER_CONCH: StringName = &"super_conch"
const BEHAVIOR_SONIC_DRILL: StringName = &"sonic_drill"
const BEHAVIOR_DART_TETHER: StringName = &"dart_tether"
const BEHAVIOR_PURPLE_SHIELD: StringName = &"purple_shield"
const BEHAVIOR_SURGE: StringName = &"surge"
const BEHAVIOR_CAMOUFLAGE: StringName = &"camouflage_veil"
const BEHAVIOR_INK_PRISON: StringName = &"ink_prison"
const BEHAVIOR_CROWN_SEA_GRAPES: StringName = &"crown_sea_grapes"
const BEHAVIOR_SEAWEED_GRAPES_BOX: StringName = &"seaweed_grapes_box"

@export_category("Consumables")
@export_range(1, 8, 1) var seaweed_grapes_heal_amount: int = 1

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


func _ready() -> void:
	_transform_effect.loop = false
	_purple_shield_effect.loop = true
	_surge_effect.loop = true
	_transform_effect.finished.connect(_on_transform_effect_finished)
	_stop_video(_transform_effect)
	_stop_video(_purple_shield_effect)
	_stop_video(_surge_effect)
	set_process(false)


func configure(context: Node, level: CotcSeaOfPillars, hylas: CotcHylas) -> void:
	_context = context
	_level = level
	_hylas = hylas
	_update_video_anchor()


func bind_game_state(game_state: CotcGameState) -> void:
	_game_state = game_state


func set_active(is_active: bool) -> void:
	_active = is_active
	set_process(is_active)
	if not is_active:
		clear_active_effects()


func handle_item_behavior(
		behavior_id: StringName,
		_item_id: StringName,
		_slot_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
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
	if not _active:
		return
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


func clear_active_effects() -> void:
	_purple_shield_remaining = 0.0
	_surge_remaining = 0.0
	_camouflage_remaining = 0.0
	_stop_video(_transform_effect)
	_stop_video(_purple_shield_effect)
	_stop_video(_surge_effect)
	if is_instance_valid(_hylas):
		if _hylas.has_method(&"clear_item_effect_state"):
			_hylas.call(&"clear_item_effect_state")
	_active_conus_tether = null
	for child: Node in _projectiles.get_children():
		child.queue_free()
	for child: Node in _clouds.get_children():
		child.queue_free()


func _activate_profiled_conch(
		behavior_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	if not _hylas.has_method(&"activate_item_a_pose"):
		return false
	if not bool(_hylas.call(&"activate_item_a_pose", direction)):
		return false
	if not is_instance_valid(_level) or not _level.has_method(&"trigger_special_conch"):
		return false
	var profile: Dictionary = {}
	if behavior_id == BEHAVIOR_SUPER_CONCH:
		profile = {
			"arc_degrees": super_conch_arc_degrees,
			"close_range_arc_degrees": maxf(120.0, super_conch_arc_degrees),
			"brightness": super_conch_brightness,
			"tint": super_conch_tint,
			"flash_tint": super_conch_tint,
			"echo_alpha_decay": 0.08,
		}
	else:
		profile = {
			"arc_degrees": sonic_drill_arc_degrees,
			"close_range_arc_degrees": 38.0,
			"brightness": sonic_drill_brightness,
			"tint": sonic_drill_tint,
			"flash_tint": sonic_drill_tint,
			"echo_alpha_decay": 0.06,
			"pulse_interval_scale": 0.48,
			"duration": 5.0,
		}
	_level.call(&"trigger_special_conch", origin, direction, profile)
	return true


func _activate_conus_dart(origin: Vector2, direction: Vector2) -> bool:
	if is_instance_valid(_active_conus_tether):
		_active_conus_tether.retract()
		_active_conus_tether = null
		return true
	if not _hylas.has_method(&"activate_item_a_pose"):
		return false
	if not bool(_hylas.call(&"activate_item_a_pose", direction)):
		return false
	var resolved_direction: Vector2 = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var projectile: CotcConusTetherProjectile = CONUS_TETHER_SCENE.instantiate() as CotcConusTetherProjectile
	if projectile == null:
		return false
	_projectiles.add_child(projectile)
	_active_conus_tether = projectile
	projectile.tether_finished.connect(
		_on_conus_tether_finished.bind(projectile),
		Object.CONNECT_ONE_SHOT,
	)
	projectile.launch(origin + resolved_direction * 92.0, resolved_direction, _hylas)
	return true


func _on_conus_tether_finished(projectile: CotcConusTetherProjectile) -> void:
	if _active_conus_tether == projectile:
		_active_conus_tether = null


func _activate_purple_shield() -> bool:
	_purple_shield_remaining = purple_shield_seconds
	if _hylas.has_method(&"set_purple_shield_active"):
		_hylas.call(&"set_purple_shield_active", true)
	_play_looping_video(_purple_shield_effect)
	return true


func _stop_purple_shield() -> void:
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
	return true


func _stop_camouflage() -> void:
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
	return true


func _activate_seaweed_grapes_box() -> bool:
	if _game_state == null:
		return false
	return _game_state.heal_fins(seaweed_grapes_heal_amount) > 0


func _update_video_anchor() -> void:
	if not is_instance_valid(_hylas):
		return
	_video_anchor.global_position = _hylas.global_position
	var sprite: AnimatedSprite2D = _hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if sprite == null:
		return
	_surge_effect.rotation = sprite.rotation
	_surge_effect.scale.x = -absf(_surge_effect.scale.x) if sprite.flip_h else absf(_surge_effect.scale.x)


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
	return [
		"[ItemEffectController]",
		"active=%s" % str(_active),
		"purple_shield_remaining=%.2f" % _purple_shield_remaining,
		"surge_remaining=%.2f" % _surge_remaining,
		"camouflage_remaining=%.2f" % _camouflage_remaining,
		"projectiles=%d" % _projectiles.get_child_count(),
		"ink_clouds=%d" % _clouds.get_child_count(),
	]
