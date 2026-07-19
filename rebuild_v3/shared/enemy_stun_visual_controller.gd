class_name CotcEnemyStunVisualController
extends Node

const FLASH_OVERLAY_SHADER: Shader = preload(
	"res://rebuild_v3/shared/shaders/enemy_stun_flash_overlay.gdshader"
)
const DESATURATE_PROXY_SHADER: Shader = preload(
	"res://rebuild_v3/shared/shaders/enemy_stun_desaturate_proxy.gdshader"
)

const PROFILE_NORMAL: StringName = &"normal_conch"
const PROFILE_SUPER: StringName = &"super_conch"
const PROFILE_DRILL: StringName = &"terebridae"
const PROFILE_DART: StringName = &"conus_textile"

const NORMAL_COLOR: Color = Color(0.0, 0.82, 1.0, 1.0)
const SUPER_COLOR: Color = Color(0.02, 1.0, 0.08, 1.0)
const DRILL_COLOR: Color = Color(1.0, 0.08, 0.88, 1.0)
const DART_COLOR: Color = Color(1.0, 0.34, 0.08, 1.0)

const NORMAL_DURATION: float = 10.0
const SUPER_DURATION: float = 20.0
const DRILL_DURATION: float = 30.0
const DART_DURATION: float = 30.0

const FLASH_ON_SECONDS: float = 0.06
const FLASH_OFF_SECONDS: float = 0.07
const STUN_DESATURATION: float = 0.60

var _target: Node
var _sprite: AnimatedSprite2D
var _flash_overlay: Sprite2D
var _desaturated_proxy: Sprite2D
var _flash_tween: Tween
var _disabled_damage_areas: Array[Area2D] = []
var _disabled_damage_states: Array[bool] = []

var _pending_response_kind: StringName = &""
var _pending_profile_id: StringName = PROFILE_NORMAL
var _pending_duration: float = 0.0
var _pending_origin: Vector2 = Vector2.ZERO
var _pending_direction: Vector2 = Vector2.RIGHT
var _pending_distance: float = 0.0
var _pending_strength: float = 1.0
var _pending_source: Node2D

var _active_profile_priority: int = 0
var _active_stun_color: Color = NORMAL_COLOR
var _profile_visual_active: bool = false
var _sprite_was_visible: bool = true


static func request_conch_stun(
		target: Node,
		profile_id: StringName,
		origin: Vector2,
		direction: Vector2,
		distance: float,
		strength: float,
	) -> void:
	if not is_instance_valid(target):
		return
	var controller: CotcEnemyStunVisualController = _get_or_create_controller(target)
	if controller == null:
		target.call(&"receive_conch_hit", origin, direction, distance, strength)
		return
	controller._request_conch_stun(profile_id, origin, direction, distance, strength)


static func request_conus_stun(
		target: Node,
		source: Node2D,
		direction: Vector2,
		hit_position: Vector2,
	) -> void:
	if not is_instance_valid(target):
		return
	var controller: CotcEnemyStunVisualController = _get_or_create_controller(target)
	if controller == null:
		if target.has_method(&"receive_conus_dart"):
			target.call(&"receive_conus_dart", source)
		elif target.has_method(&"receive_conch_hit"):
			var source_position: Vector2 = source.global_position if is_instance_valid(source) else hit_position
			target.call(
				&"receive_conch_hit",
				source_position,
				direction,
				source_position.distance_to(hit_position),
				1.0,
			)
		return
	controller._request_conus_stun(source, direction, hit_position)


static func _get_or_create_controller(target: Node) -> CotcEnemyStunVisualController:
	var existing: CotcEnemyStunVisualController = target.get_node_or_null(
		"EnemyStunVisualController"
	) as CotcEnemyStunVisualController
	if existing != null:
		return existing
	var controller: CotcEnemyStunVisualController = CotcEnemyStunVisualController.new()
	controller.name = "EnemyStunVisualController"
	controller.process_mode = Node.PROCESS_MODE_ALWAYS
	target.add_child(controller)
	controller._bind_target(target)
	return controller


func _bind_target(target: Node) -> void:
	_target = target
	_sprite = _find_target_sprite()
	set_process(false)


func _request_conch_stun(
		profile_id: StringName,
		origin: Vector2,
		direction: Vector2,
		distance: float,
		strength: float,
	) -> void:
	_pending_response_kind = &"conch"
	_pending_profile_id = profile_id
	_pending_origin = origin
	_pending_direction = direction
	_pending_distance = distance
	_pending_strength = strength
	_pending_source = null
	_queue_profile_stun(profile_id)


func _request_conus_stun(source: Node2D, direction: Vector2, hit_position: Vector2) -> void:
	_pending_response_kind = &"conus"
	_pending_profile_id = PROFILE_DART
	_pending_source = source
	_pending_direction = direction
	_pending_origin = source.global_position if is_instance_valid(source) else hit_position
	_pending_distance = _pending_origin.distance_to(hit_position)
	_pending_strength = 1.0
	_queue_profile_stun(PROFILE_DART)


func _queue_profile_stun(profile_id: StringName) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	if not is_instance_valid(_sprite):
		_sprite = _find_target_sprite()

	var requested_duration: float = _duration_for_profile(profile_id)
	var current_remaining: float = _get_current_stun_remaining()
	_pending_duration = maxf(_pending_duration, maxf(requested_duration, current_remaining))

	var requested_priority: int = _priority_for_profile(profile_id)
	if current_remaining <= 0.0 or requested_priority >= _active_profile_priority:
		_active_profile_priority = requested_priority
		_active_stun_color = _color_for_profile(profile_id)

	_disable_damage_during_flash()
	_start_double_flash(_color_for_profile(profile_id))
	set_process(true)


func _start_double_flash(flash_color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_clear_flash_overlay()

	if is_instance_valid(_sprite) and _get_current_sprite_texture() != null:
		_create_flash_overlay(flash_color)
		_flash_tween = create_tween()
		_flash_tween.set_loops(2)
		_flash_tween.tween_property(
			_flash_overlay,
			^"modulate:a",
			1.0,
			FLASH_ON_SECONDS,
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_flash_tween.tween_property(
			_flash_overlay,
			^"modulate:a",
			0.0,
			FLASH_OFF_SECONDS,
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		_flash_tween = create_tween()
		_flash_tween.tween_interval((FLASH_ON_SECONDS + FLASH_OFF_SECONDS) * 2.0)
	_flash_tween.finished.connect(Callable(self, "_finish_double_flash"), Object.CONNECT_ONE_SHOT)


func _finish_double_flash() -> void:
	_flash_tween = null
	_clear_flash_overlay()
	_restore_damage_after_flash()
	_apply_pending_stun_response()


func _apply_pending_stun_response() -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var duration_overrides: Dictionary = _apply_temporary_duration_overrides(_pending_duration)
	if _pending_response_kind == &"conus" and _target.has_method(&"receive_conus_dart"):
		_target.call(&"receive_conus_dart", _pending_source)
	elif _target.has_method(&"receive_conch_hit"):
		_target.call(
			&"receive_conch_hit",
			_pending_origin,
			_pending_direction,
			_pending_distance,
			_pending_strength,
		)
	_restore_duration_overrides(duration_overrides)

	_pending_duration = 0.0
	_profile_visual_active = _target_is_stunned()
	if _profile_visual_active:
		_apply_active_profile_visual()
	else:
		_clear_active_profile_visual()
	set_process(_profile_visual_active)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	if is_instance_valid(_flash_overlay):
		_sync_flash_overlay()
	if is_instance_valid(_desaturated_proxy):
		_sync_proxy_transform()
	if _profile_visual_active and not _target_is_stunned():
		_profile_visual_active = false
		_active_profile_priority = 0
		_active_stun_color = NORMAL_COLOR
		_clear_active_profile_visual()
		set_process(_flash_tween != null and _flash_tween.is_valid())


func _apply_active_profile_visual() -> void:
	if not is_instance_valid(_sprite):
		return
	if _has_dedicated_stun_animation():
		var stun_material: ShaderMaterial = _sprite.material as ShaderMaterial
		if stun_material != null:
			stun_material.set_shader_parameter(&"glow_color", _active_stun_color)
		return
	_create_or_refresh_desaturated_proxy()


func _create_or_refresh_desaturated_proxy() -> void:
	if not is_instance_valid(_sprite):
		return
	var texture: Texture2D = _get_current_sprite_texture()
	if texture == null:
		return
	if not is_instance_valid(_desaturated_proxy):
		_desaturated_proxy = Sprite2D.new()
		_desaturated_proxy.name = "EnemyStunDesaturatedProxy"
		var proxy_material: ShaderMaterial = ShaderMaterial.new()
		proxy_material.resource_local_to_scene = true
		proxy_material.shader = DESATURATE_PROXY_SHADER
		_desaturated_proxy.material = proxy_material
		var sprite_parent: Node = _sprite.get_parent()
		if sprite_parent == null:
			_desaturated_proxy.queue_free()
			_desaturated_proxy = null
			return
		sprite_parent.add_child(_desaturated_proxy)
		_sprite_was_visible = _sprite.visible
		_sprite.hide()

	_desaturated_proxy.texture = texture
	var material: ShaderMaterial = _desaturated_proxy.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"glow_color", _active_stun_color)
		material.set_shader_parameter(&"desaturation_amount", STUN_DESATURATION)
	_desaturated_proxy.modulate = Color.WHITE
	if _has_property(_target, &"alert_opacity_max"):
		_desaturated_proxy.modulate.a = clampf(float(_target.get(&"alert_opacity_max")), 0.0, 1.0)
	_sync_proxy_transform()


func _clear_active_profile_visual() -> void:
	if is_instance_valid(_desaturated_proxy):
		_desaturated_proxy.queue_free()
	_desaturated_proxy = null
	if is_instance_valid(_sprite):
		_sprite.visible = _sprite_was_visible


func _create_flash_overlay(flash_color: Color) -> void:
	var texture: Texture2D = _get_current_sprite_texture()
	if texture == null or not is_instance_valid(_sprite):
		return
	_flash_overlay = Sprite2D.new()
	_flash_overlay.name = "EnemyStunFlashOverlay"
	_flash_overlay.texture = texture
	var overlay_material: ShaderMaterial = ShaderMaterial.new()
	overlay_material.resource_local_to_scene = true
	overlay_material.shader = FLASH_OVERLAY_SHADER
	overlay_material.set_shader_parameter(&"flash_color", flash_color)
	_flash_overlay.material = overlay_material
	_flash_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var sprite_parent: Node = _sprite.get_parent()
	if sprite_parent == null:
		_flash_overlay.queue_free()
		_flash_overlay = null
		return
	sprite_parent.add_child(_flash_overlay)
	_sync_flash_overlay()


func _sync_flash_overlay() -> void:
	if not is_instance_valid(_flash_overlay) or not is_instance_valid(_sprite):
		return
	var texture: Texture2D = _get_current_sprite_texture()
	if texture != null:
		_flash_overlay.texture = texture
	_copy_sprite_transform(_flash_overlay)
	_flash_overlay.z_index = _sprite.z_index + 2


func _sync_proxy_transform() -> void:
	if not is_instance_valid(_desaturated_proxy) or not is_instance_valid(_sprite):
		return
	_copy_sprite_transform(_desaturated_proxy)
	_desaturated_proxy.z_index = _sprite.z_index + 1


func _copy_sprite_transform(destination: Sprite2D) -> void:
	destination.position = _sprite.position
	destination.rotation = _sprite.rotation
	destination.scale = _sprite.scale
	destination.skew = _sprite.skew
	destination.offset = _sprite.offset
	destination.centered = _sprite.centered
	destination.flip_h = _sprite.flip_h
	destination.flip_v = _sprite.flip_v
	destination.texture_filter = _sprite.texture_filter
	destination.z_as_relative = _sprite.z_as_relative


func _clear_flash_overlay() -> void:
	if is_instance_valid(_flash_overlay):
		_flash_overlay.queue_free()
	_flash_overlay = null


func _disable_damage_during_flash() -> void:
	if not _disabled_damage_areas.is_empty():
		return
	var hurt_area: Area2D = _target.get_node_or_null("HurtArea") as Area2D
	if hurt_area != null:
		_remember_and_disable_area(hurt_area)
	var target_area: Area2D = _target as Area2D
	if target_area != null and _target.get_node_or_null("ContactShape") != null:
		_remember_and_disable_area(target_area)


func _remember_and_disable_area(area: Area2D) -> void:
	_disabled_damage_areas.append(area)
	_disabled_damage_states.append(area.monitoring)
	area.monitoring = false


func _restore_damage_after_flash() -> void:
	for index: int in range(_disabled_damage_areas.size()):
		var area: Area2D = _disabled_damage_areas[index]
		if is_instance_valid(area):
			area.monitoring = _disabled_damage_states[index]
	_disabled_damage_areas.clear()
	_disabled_damage_states.clear()


func _apply_temporary_duration_overrides(duration: float) -> Dictionary:
	var previous_values: Dictionary = {}
	for property_name: StringName in [
		&"freeze_duration",
		&"stun_duration",
		&"conus_dart_stun_seconds",
	]:
		if not _has_property(_target, property_name):
			continue
		previous_values[property_name] = _target.get(property_name)
		_target.set(property_name, duration)
	return previous_values


func _restore_duration_overrides(previous_values: Dictionary) -> void:
	for property_name: Variant in previous_values.keys():
		_target.set(property_name, previous_values[property_name])


func _get_current_stun_remaining() -> float:
	if _target.has_method(&"get_frozen_time_remaining"):
		return maxf(0.0, float(_target.call(&"get_frozen_time_remaining")))
	if _target.has_method(&"get_stun_time_remaining"):
		return maxf(0.0, float(_target.call(&"get_stun_time_remaining")))
	return 0.0


func _target_is_stunned() -> bool:
	if _target.has_method(&"is_frozen"):
		return bool(_target.call(&"is_frozen"))
	if _target.has_method(&"is_stunned"):
		return bool(_target.call(&"is_stunned"))
	return false


func _find_target_sprite() -> AnimatedSprite2D:
	if not is_instance_valid(_target):
		return null
	var direct_sprite: AnimatedSprite2D = _target.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if direct_sprite != null:
		return direct_sprite
	for child: Node in _target.find_children("*", "AnimatedSprite2D", true, false):
		var candidate: AnimatedSprite2D = child as AnimatedSprite2D
		if candidate != null:
			return candidate
	return null


func _get_current_sprite_texture() -> Texture2D:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)


func _has_dedicated_stun_animation() -> bool:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return false
	return (
		_sprite.sprite_frames.has_animation(&"frozen")
		or _sprite.sprite_frames.has_animation(&"stunned")
	)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property_data: Dictionary in object.get_property_list():
		if StringName(str(property_data.get("name", ""))) == property_name:
			return true
	return false


func _duration_for_profile(profile_id: StringName) -> float:
	match profile_id:
		PROFILE_SUPER:
			return SUPER_DURATION
		PROFILE_DRILL:
			return DRILL_DURATION
		PROFILE_DART:
			return DART_DURATION
		_:
			return NORMAL_DURATION


func _priority_for_profile(profile_id: StringName) -> int:
	match profile_id:
		PROFILE_SUPER:
			return 2
		PROFILE_DRILL, PROFILE_DART:
			return 3
		_:
			return 1


func _color_for_profile(profile_id: StringName) -> Color:
	match profile_id:
		PROFILE_SUPER:
			return SUPER_COLOR
		PROFILE_DRILL:
			return DRILL_COLOR
		PROFILE_DART:
			return DART_COLOR
		_:
			return NORMAL_COLOR
