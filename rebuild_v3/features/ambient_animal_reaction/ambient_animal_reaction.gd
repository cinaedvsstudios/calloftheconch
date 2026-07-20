class_name CotcAmbientAnimalReaction
extends Node

## Optional playful physics for individual decoration animals. The host keeps
## ownership of its normal patrol movement. This component temporarily pauses
## that controller for Tail Flip knockback or a water-surface pop, then restores
## it. Enemies and fish schools receive nothing unless this child is explicitly
## added to their scene.

signal playful_tail_flip_received(direction: Vector2, source: Node)
signal surface_pop_started
signal surface_pop_finished

const MODE_NONE: StringName = &"none"
const MODE_PUSH_ONLY: StringName = &"push_only"
const MODE_KNOCKABLE: StringName = &"knockable"
const MODE_SPECIAL: StringName = &"special"
const SURFACE_SPLASH_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/surface_splash.tscn"
)

@export_category("Playful Reaction")
@export var reaction_enabled: bool = true
@export_enum("none", "push_only", "knockable", "special") var reaction_mode: String = "knockable"
@export_range(50.0, 600.0, 5.0) var tail_flip_forward_reach: float = 285.0
@export_range(20.0, 300.0, 5.0) var tail_flip_half_width: float = 125.0
@export_range(20.0, 240.0, 5.0) var tail_flip_close_radius: float = 105.0
@export_range(50.0, 1600.0, 10.0) var tail_flip_knock_speed: float = 720.0
@export_range(0.0, 600.0, 10.0) var tail_flip_upward_lift: float = 115.0
@export_range(0.10, 3.0, 0.05) var knock_duration: float = 1.10
@export_range(10.0, 2000.0, 10.0) var knock_drag: float = 520.0
@export_range(0.0, 720.0, 5.0) var knock_spin_degrees_per_second: float = 300.0
@export_range(0.10, 3.0, 0.05) var reaction_cooldown: float = 0.65

@export_category("Water Surface")
@export var keep_below_waterline: bool = true
@export var surface_pop_enabled: bool = true
@export_range(0.0, 160.0, 1.0) var underwater_margin: float = 28.0
@export_range(0.20, 2.0, 0.05) var surface_pop_duration: float = 0.82
@export_range(10.0, 300.0, 5.0) var surface_arc_height: float = 95.0
@export_range(20.0, 600.0, 5.0) var surface_return_side_distance: float = 215.0
@export_range(5.0, 180.0, 1.0) var surface_return_depth: float = 46.0
@export_range(0.0, 500.0, 5.0) var recovery_horizontal_speed: float = 110.0
@export_range(0.0, 500.0, 5.0) var minimum_upward_pop_speed: float = 45.0
@export var use_waterline_y_override: bool = false
@export var waterline_y_override: float = 0.0

@export_category("Optional Host Paths")
@export var animated_sprite_path: NodePath
@export var body_collision_shape_path: NodePath

var _host: CharacterBody2D
var _sprite: AnimatedSprite2D
var _body_collision_shapes: Array[CollisionShape2D] = []
var _connected_hylas: Array[Node] = []
var _connection_refresh_remaining: float = 0.0
var _waterline_refresh_remaining: float = 0.0
var _waterline_y: float = 0.0
var _waterline_valid: bool = false
var _last_host_position: Vector2 = Vector2.ZERO
var _reaction_velocity: Vector2 = Vector2.ZERO
var _reaction_remaining: float = 0.0
var _reaction_cooldown_remaining: float = 0.0
var _reaction_spin_radians: float = 0.0
var _reaction_active: bool = false
var _surface_pop_active: bool = false
var _surface_pop_elapsed: float = 0.0
var _surface_start_x: float = 0.0
var _surface_target_x: float = 0.0
var _surface_side_sign: float = 1.0
var _surface_reentry_splash_played: bool = false
var _host_controller_suspended: bool = false
var _host_controller_was_processing: bool = true
var _base_sprite_rotation: float = 0.0


func _ready() -> void:
	process_priority = 100
	_host = get_parent() as CharacterBody2D
	if _host == null:
		push_warning("AmbientAnimalReaction requires a CharacterBody2D parent.")
		set_physics_process(false)
		return
	_resolve_host_nodes()
	_base_sprite_rotation = _sprite.rotation if is_instance_valid(_sprite) else 0.0
	_last_host_position = _host.global_position
	_refresh_hylas_connections()
	_resolve_waterline()
	set_physics_process(true)


func _exit_tree() -> void:
	_restore_host_controller()
	_set_body_collision_disabled(false)


func _physics_process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var safe_delta: float = maxf(delta, 0.0)
	_reaction_cooldown_remaining = maxf(0.0, _reaction_cooldown_remaining - safe_delta)
	_connection_refresh_remaining -= safe_delta
	_waterline_refresh_remaining -= safe_delta
	if _connection_refresh_remaining <= 0.0:
		_connection_refresh_remaining = 0.75
		_refresh_hylas_connections()
	if _waterline_refresh_remaining <= 0.0:
		_waterline_refresh_remaining = 1.0
		_resolve_waterline()

	if _surface_pop_active:
		_update_surface_pop(safe_delta)
		_last_host_position = _host.global_position
		return
	if _reaction_active:
		_update_knock_reaction(safe_delta)
		_last_host_position = _host.global_position
		return

	_enforce_waterline_after_host_motion()
	_last_host_position = _host.global_position


func is_reacting() -> bool:
	return _reaction_active or _surface_pop_active


func force_playful_knock(direction: Vector2, source: Node = null) -> bool:
	if not _can_receive_tail_flip():
		return false
	return _begin_knock(direction, source)


func get_debug_lines() -> Array[String]:
	return [
		"[AmbientAnimalReaction]",
		"enabled=%s" % str(reaction_enabled),
		"mode=%s" % reaction_mode,
		"reaction_active=%s" % str(_reaction_active),
		"surface_pop_active=%s" % str(_surface_pop_active),
		"waterline_valid=%s" % str(_waterline_valid),
		"waterline_y=%.1f" % _waterline_y,
		"connected_hylas=%d" % _connected_hylas.size(),
	]


func _resolve_host_nodes() -> void:
	if not animated_sprite_path.is_empty():
		_sprite = _host.get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	if _sprite == null:
		_sprite = _host.get_node_or_null("%AnimatedSprite") as AnimatedSprite2D
	if _sprite == null:
		for candidate: Node in _host.find_children("*", "AnimatedSprite2D", true, false):
			_sprite = candidate as AnimatedSprite2D
			if _sprite != null:
				break

	_body_collision_shapes.clear()
	if not body_collision_shape_path.is_empty():
		var configured_shape: CollisionShape2D = (
			_host.get_node_or_null(body_collision_shape_path) as CollisionShape2D
		)
		if configured_shape != null:
			_body_collision_shapes.append(configured_shape)
	if _body_collision_shapes.is_empty():
		for candidate: Node in _host.find_children("*", "CollisionShape2D", true, false):
			var collision_shape: CollisionShape2D = candidate as CollisionShape2D
			if collision_shape != null and collision_shape.get_parent() == _host:
				_body_collision_shapes.append(collision_shape)


func _refresh_hylas_connections() -> void:
	for index: int in range(_connected_hylas.size() - 1, -1, -1):
		if not is_instance_valid(_connected_hylas[index]):
			_connected_hylas.remove_at(index)
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		if not is_instance_valid(candidate) or not candidate.has_signal(&"tail_flip_started"):
			continue
		if _connected_hylas.has(candidate):
			continue
		var callback: Callable = Callable(self, "_on_hylas_tail_flip_started").bind(candidate)
		candidate.connect(&"tail_flip_started", callback)
		_connected_hylas.append(candidate)


func _on_hylas_tail_flip_started(
		origin: Vector2,
		direction: Vector2,
		hylas: Node,
	) -> void:
	if not _can_receive_tail_flip() or direction.length_squared() <= 0.0001:
		return
	var resolved_direction: Vector2 = direction.normalized()
	var to_host: Vector2 = _host.global_position - origin
	var close_enough: bool = to_host.length() <= tail_flip_close_radius
	var forward_distance: float = to_host.dot(resolved_direction)
	var lateral_distance: float = absf(to_host.cross(resolved_direction))
	var inside_forward_corridor: bool = (
		forward_distance >= -tail_flip_close_radius * 0.25
		and forward_distance <= tail_flip_forward_reach
		and lateral_distance <= tail_flip_half_width
	)
	if not close_enough and not inside_forward_corridor:
		return

	if StringName(reaction_mode) == MODE_SPECIAL and _host.has_method(
			&"receive_playful_tail_flip_special"
		):
		var special_result: Variant = _host.call(
			&"receive_playful_tail_flip_special",
			resolved_direction,
			hylas,
		)
		if special_result is bool and not bool(special_result):
			return
	_begin_knock(resolved_direction, hylas)


func _can_receive_tail_flip() -> bool:
	if not reaction_enabled or _reaction_cooldown_remaining > 0.0:
		return false
	var mode: StringName = StringName(reaction_mode)
	return mode == MODE_KNOCKABLE or mode == MODE_SPECIAL


func _begin_knock(direction: Vector2, source: Node) -> bool:
	if _surface_pop_active or direction.length_squared() <= 0.0001:
		return false
	_suspend_host_controller()
	_reaction_active = true
	_reaction_remaining = knock_duration
	_reaction_cooldown_remaining = reaction_cooldown
	var resolved_direction: Vector2 = direction.normalized()
	_reaction_velocity = resolved_direction * tail_flip_knock_speed
	_reaction_velocity.y -= tail_flip_upward_lift
	_reaction_spin_radians = deg_to_rad(knock_spin_degrees_per_second)
	if resolved_direction.x < 0.0:
		_reaction_spin_radians *= -1.0
	if is_instance_valid(_sprite):
		_sprite.play()
	playful_tail_flip_received.emit(resolved_direction, source)
	return true


func _update_knock_reaction(delta: float) -> void:
	_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	_reaction_velocity = _reaction_velocity.move_toward(Vector2.ZERO, knock_drag * delta)
	_reaction_velocity.y += 36.0 * delta
	_host.velocity = _reaction_velocity
	_host.move_and_slide()
	_reaction_velocity = _host.velocity
	if is_instance_valid(_sprite):
		_sprite.rotation += _reaction_spin_radians * delta

	if _should_begin_surface_pop(_last_host_position, _host.global_position, _reaction_velocity):
		_begin_surface_pop(_find_nearest_hylas(), _reaction_velocity.x, true)
		return
	if _reaction_remaining > 0.0 and _reaction_velocity.length() > 35.0:
		return
	_finish_knock_reaction()


func _finish_knock_reaction() -> void:
	_reaction_active = false
	_reaction_velocity = Vector2.ZERO
	_restore_sprite_rotation()
	_restore_host_controller()
	_request_host_resume_swimming()


func _enforce_waterline_after_host_motion() -> void:
	if not reaction_enabled or not keep_below_waterline or not _waterline_valid:
		return
	var surface_limit: float = _waterline_y + underwater_margin
	if _host.global_position.y >= surface_limit:
		return
	var moved_across_surface: bool = _last_host_position.y >= surface_limit
	var upward_velocity: Vector2 = _host.velocity
	var was_forced_upward: bool = upward_velocity.y <= -minimum_upward_pop_speed
	if (
			surface_pop_enabled
			and StringName(reaction_mode) != MODE_NONE
			and (moved_across_surface or was_forced_upward)
		):
		_begin_surface_pop(_find_nearest_hylas(), upward_velocity.x, true)
		return
	_host.global_position.y = surface_limit
	if _host.velocity.y < 0.0:
		_host.velocity.y = 0.0


func _should_begin_surface_pop(
		previous_position: Vector2,
		current_position: Vector2,
		motion_velocity: Vector2,
	) -> bool:
	if not surface_pop_enabled or not keep_below_waterline or not _waterline_valid:
		return false
	var surface_limit: float = _waterline_y + underwater_margin
	return (
		current_position.y < surface_limit
		and (
			previous_position.y >= surface_limit
			or motion_velocity.y <= -minimum_upward_pop_speed
		)
	)


func _begin_surface_pop(hylas: Node2D, horizontal_velocity: float, play_exit_splash: bool) -> void:
	if _surface_pop_active or not _waterline_valid:
		return
	_suspend_host_controller()
	_reaction_active = false
	_surface_pop_active = true
	_surface_pop_elapsed = 0.0
	_surface_reentry_splash_played = false
	_surface_start_x = _host.global_position.x
	_surface_side_sign = _resolve_surface_side(hylas, horizontal_velocity)
	_surface_target_x = _surface_start_x + _surface_side_sign * surface_return_side_distance
	if is_instance_valid(hylas):
		_surface_target_x = hylas.global_position.x + (
			_surface_side_sign * surface_return_side_distance
		)
	_host.global_position.y = _waterline_y
	_host.velocity = Vector2.ZERO
	_set_body_collision_disabled(true)
	if is_instance_valid(_sprite):
		_sprite.play()
	if play_exit_splash:
		_spawn_surface_splash(true, horizontal_velocity)
	surface_pop_started.emit()


func _update_surface_pop(delta: float) -> void:
	_surface_pop_elapsed += delta
	var duration: float = maxf(0.20, surface_pop_duration)
	var progress: float = clampf(_surface_pop_elapsed / duration, 0.0, 1.0)
	var airborne_end: float = 0.78
	var x_position: float = lerpf(_surface_start_x, _surface_target_x, progress)
	var y_position: float
	if progress < airborne_end:
		var airborne_progress: float = progress / airborne_end
		y_position = _waterline_y - sin(airborne_progress * PI) * surface_arc_height
	else:
		var entry_progress: float = (progress - airborne_end) / (1.0 - airborne_end)
		y_position = lerpf(_waterline_y, _waterline_y + surface_return_depth, entry_progress)
		if not _surface_reentry_splash_played:
			_surface_reentry_splash_played = true
			_spawn_surface_splash(false, _surface_side_sign * recovery_horizontal_speed)

	_host.global_position = Vector2(x_position, y_position)
	if is_instance_valid(_sprite):
		_sprite.rotation = _base_sprite_rotation + (
			sin(progress * PI) * deg_to_rad(22.0) * _surface_side_sign
		)
	if progress >= 1.0:
		_finish_surface_pop()


func _finish_surface_pop() -> void:
	_surface_pop_active = false
	_surface_pop_elapsed = 0.0
	_reaction_velocity = Vector2.ZERO
	_set_body_collision_disabled(false)
	_restore_sprite_rotation()
	_host.velocity = Vector2(
		_surface_side_sign * recovery_horizontal_speed,
		maxf(20.0, surface_return_depth * 0.75),
	)
	_restore_host_controller()
	_request_host_resume_swimming()
	surface_pop_finished.emit()


func _resolve_surface_side(hylas: Node2D, horizontal_velocity: float) -> float:
	if absf(horizontal_velocity) >= 10.0:
		return signf(horizontal_velocity)
	if is_instance_valid(hylas):
		var horizontal_difference: float = _host.global_position.x - hylas.global_position.x
		if absf(horizontal_difference) >= 4.0:
			return signf(horizontal_difference)
	return -1.0 if randf() < 0.5 else 1.0


func _find_nearest_hylas() -> Node2D:
	var nearest: Node2D
	var nearest_distance_squared: float = INF
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		var candidate_2d: Node2D = candidate as Node2D
		if not is_instance_valid(candidate_2d):
			continue
		var distance_squared: float = _host.global_position.distance_squared_to(
			candidate_2d.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = candidate_2d
	return nearest


func _resolve_waterline() -> void:
	if use_waterline_y_override:
		_waterline_y = waterline_y_override
		_waterline_valid = true
		return
	var marker: Node2D = get_tree().get_first_node_in_group(&"waterline_marker") as Node2D
	if marker == null and get_tree().current_scene != null:
		marker = get_tree().current_scene.find_child(
			"WaterlineMarker",
			true,
			false,
		) as Node2D
	if marker == null:
		_waterline_valid = false
		return
	_waterline_y = marker.global_position.y
	_waterline_valid = true


func _spawn_surface_splash(is_exit: bool, horizontal_velocity: float) -> void:
	var splash: CotcSurfaceSplash = SURFACE_SPLASH_SCENE.instantiate() as CotcSurfaceSplash
	if splash == null:
		return
	var host_parent: Node = _host.get_parent()
	if host_parent == null:
		host_parent = get_tree().current_scene
	if host_parent == null:
		splash.queue_free()
		return
	host_parent.add_child(splash)
	splash.z_as_relative = false
	splash.z_index = 110
	splash.trigger(
		Vector2(_host.global_position.x, _waterline_y),
		is_exit,
		horizontal_velocity,
	)
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(1.10)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(splash):
			splash.queue_free()
	)


func _suspend_host_controller() -> void:
	if _host_controller_suspended:
		return
	_host_controller_suspended = true
	_host_controller_was_processing = _host.is_physics_processing()
	_host.set_physics_process(false)


func _restore_host_controller() -> void:
	if not _host_controller_suspended or not is_instance_valid(_host):
		return
	_host_controller_suspended = false
	_host.set_physics_process(_host_controller_was_processing)


func _set_body_collision_disabled(disabled: bool) -> void:
	for collision_shape: CollisionShape2D in _body_collision_shapes:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred(&"disabled", disabled)


func _restore_sprite_rotation() -> void:
	if is_instance_valid(_sprite):
		_sprite.rotation = _base_sprite_rotation


func _request_host_resume_swimming() -> void:
	if _host.has_method(&"_begin_swim_burst"):
		_host.call(&"_begin_swim_burst")
	if _host.has_method(&"_choose_next_patrol_target"):
		_host.call(&"_choose_next_patrol_target", false)
