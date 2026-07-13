class_name CotcSeaOfPillars
extends Node2D

const CONCH_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/effects/ConchImpact/conch_impact_effect.tscn"
)
const LEVEL_ID: StringName = &"sea_of_pillars"
const DEFAULT_SPAWN_POINT_ID: StringName = &"sea_of_pillars_start"

signal conch_target_hit(target: Node2D, hit_position: Vector2, pulse_index: int)
signal greatfin_pickup_requested(pickup_type_id: StringName)

@export_category("Level")
@export var auto_play_ambience: bool = true
@export var auto_play_bubble_overlay: bool = true

@export_category("Conch Pulse")
@export_range(0.0, 300.0, 1.0) var conch_origin_forward_offset: float = 105.0

@export_category("Fin Damage and Respawn")
@export_range(0.0, 10.0, 0.1) var damage_invulnerability_seconds: float = 1.0
@export var auto_respawn_on_zero_fins: bool = true
@export var restore_full_fins_on_respawn: bool = true

@export_category("Bubble Overlay")
@export_range(0.001, 0.1, 0.001) var bubble_waterline_fade: float = 0.012
@export_range(0.1, 10.0, 0.1) var bubble_waterline_update_interval: float = 2.0

@onready var _hylas: CotcHylas = %Hylas
@onready var _start_marker: Marker2D = %HylasStart
@onready var _waterline_marker: Marker2D = %WaterlineMarker
@onready var _world_top_left: Marker2D = %WorldTopLeft
@onready var _world_bottom_right: Marker2D = %WorldBottomRight
@onready var _underwater_ambience: AudioStreamPlayer = %UnderwaterAmbience
@onready var _bubble_overlay: VideoStreamPlayer = %BubbleOverlay
@onready var _conch_pulse: CotcConchPulse = %ConchPulse
@onready var _exit_surface_splash: CotcSurfaceSplash = %ExitSurfaceSplash
@onready var _entry_surface_splash: CotcSurfaceSplash = %EntrySurfaceSplash

var _active: bool = false
var _bubble_material: ShaderMaterial
var _bubble_waterline_update_elapsed: float = 0.0
var _base_camera_shake_strength: float = 10.0
var _game_state: CotcGameState
var _active_spawn_point_id: StringName = DEFAULT_SPAWN_POINT_ID
var _last_damage_time_msec: int = -1000000
var _respawn_pending: bool = false


func _ready() -> void:
	_base_camera_shake_strength = _hylas.camera_shake_strength
	_underwater_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_hylas.normal_conch_used.connect(_on_hylas_normal_conch_used)
	_hylas.surface_splash_requested.connect(_on_hylas_surface_splash_requested)
	_conch_pulse.target_hit.connect(_on_conch_pulse_target_hit)
	_prepare_bubble_material()
	configure_player()
	_connect_spawn_checkpoints()
	_connect_runtime_state_sources()
	deactivate()


func _process(delta: float) -> void:
	_bubble_waterline_update_elapsed += delta
	if _bubble_waterline_update_elapsed < bubble_waterline_update_interval:
		return
	_bubble_waterline_update_elapsed = 0.0
	_update_bubble_waterline_mask()


func bind_game_state(game_state: CotcGameState) -> void:
	if _game_state != null:
		if _game_state.state_replaced.is_connected(_on_game_state_replaced):
			_game_state.state_replaced.disconnect(_on_game_state_replaced)
		if _game_state.player_defeated.is_connected(_on_player_defeated):
			_game_state.player_defeated.disconnect(_on_player_defeated)
	_game_state = game_state
	if _game_state == null:
		return
	_game_state.state_replaced.connect(_on_game_state_replaced)
	_game_state.player_defeated.connect(_on_player_defeated)
	_connect_runtime_state_sources()
	_apply_persistent_world_state()


func configure_player() -> void:
	var top_left: Vector2 = _world_top_left.global_position
	var bottom_right: Vector2 = _world_bottom_right.global_position
	var world_bounds: Rect2 = Rect2(top_left, bottom_right - top_left)
	_hylas.configure_world(world_bounds, _waterline_marker.global_position.y, _start_marker.global_position)


func set_screen_shake_scale(value: float) -> void:
	_hylas.camera_shake_strength = _base_camera_shake_strength * clampf(value, 0.0, 1.0)


func activate(spawn_point_id: StringName = &"") -> void:
	_active = true
	_respawn_pending = false
	_last_damage_time_msec = -1000000
	show()
	configure_player()
	_connect_runtime_state_sources()
	_apply_persistent_world_state()
	_active_spawn_point_id = _resolve_spawn_point_id(spawn_point_id)
	var spawn_position: Vector2 = _resolve_spawn_position(_active_spawn_point_id)
	_hylas.reset_to_start(spawn_position)
	if _game_state != null:
		_game_state.set_checkpoint(LEVEL_ID, _active_spawn_point_id)
	_hylas.set_play_enabled(true)
	_play_underwater_ambience()
	_bubble_waterline_update_elapsed = 0.0
	_update_bubble_waterline_mask()
	set_process(true)
	if auto_play_bubble_overlay and _bubble_overlay.stream != null:
		_bubble_overlay.show()
		_bubble_overlay.play()


func deactivate() -> void:
	_active = false
	_respawn_pending = false
	set_process(false)
	_bubble_waterline_update_elapsed = 0.0
	_hylas.set_play_enabled(false)
	_underwater_ambience.stop()
	_bubble_overlay.stop()
	_bubble_overlay.hide()
	_conch_pulse.stop()
	_clear_conch_impacts()
	_exit_surface_splash.stop_splash()
	_entry_surface_splash.stop_splash()
	hide()


func activate_checkpoint(spawn_point_id: StringName) -> void:
	var resolved_id: StringName = _resolve_spawn_point_id(spawn_point_id)
	_active_spawn_point_id = resolved_id
	if _game_state != null:
		_game_state.set_checkpoint(LEVEL_ID, resolved_id)
		_game_state.unlock_whale_ground(resolved_id)


func _resolve_spawn_point_id(requested_id: StringName) -> StringName:
	if String(requested_id).is_empty():
		return DEFAULT_SPAWN_POINT_ID
	if requested_id == DEFAULT_SPAWN_POINT_ID:
		return requested_id
	for checkpoint: Node in get_tree().get_nodes_in_group(&"cotc_spawn_point"):
		if not is_ancestor_of(checkpoint):
			continue
		if StringName(str(checkpoint.get("spawn_point_id"))) == requested_id:
			return requested_id
	push_warning("Unknown Sea of Pillars spawn point '%s'; using the level start." % String(requested_id))
	return DEFAULT_SPAWN_POINT_ID


func _resolve_spawn_position(spawn_point_id: StringName) -> Vector2:
	if spawn_point_id == DEFAULT_SPAWN_POINT_ID:
		return _start_marker.global_position
	for checkpoint: Node in get_tree().get_nodes_in_group(&"cotc_spawn_point"):
		if not is_ancestor_of(checkpoint):
			continue
		if StringName(str(checkpoint.get("spawn_point_id"))) != spawn_point_id:
			continue
		var checkpoint_2d: Node2D = checkpoint as Node2D
		if checkpoint_2d != null:
			return checkpoint_2d.global_position
	return _start_marker.global_position


func _connect_spawn_checkpoints() -> void:
	for checkpoint: Node in get_tree().get_nodes_in_group(&"cotc_spawn_point"):
		if not is_ancestor_of(checkpoint):
			continue
		if checkpoint.has_signal(&"checkpoint_activated") and not checkpoint.is_connected(
			&"checkpoint_activated",
			_on_spawn_checkpoint_activated,
		):
			checkpoint.connect(&"checkpoint_activated", _on_spawn_checkpoint_activated)


func _on_spawn_checkpoint_activated(level_id: StringName, spawn_point_id: StringName) -> void:
	if level_id != LEVEL_ID:
		return
	activate_checkpoint(spawn_point_id)


func _connect_runtime_state_sources() -> void:
	var damage_callback: Callable = Callable(self, "_on_damage_requested")
	var shark_callback: Callable = Callable(self, "_on_shark_contacted")
	for node: Node in find_children("*", "", true, false):
		if node.has_signal(&"damage_requested") and not node.is_connected(&"damage_requested", damage_callback):
			node.connect(&"damage_requested", damage_callback)
		if node.has_signal(&"hylas_contacted") and not node.is_connected(&"hylas_contacted", shark_callback):
			node.connect(&"hylas_contacted", shark_callback)
		if node.has_signal(&"pickup_collected"):
			var pickup_callback: Callable = Callable(self, "_on_food_pickup_collected").bind(node)
			if not node.is_connected(&"pickup_collected", pickup_callback):
				node.connect(&"pickup_collected", pickup_callback)
			_assign_pickup_persistent_id(node)


func _assign_pickup_persistent_id(pickup: Node) -> StringName:
	if pickup.has_method(&"assign_persistent_id"):
		return StringName(str(pickup.call(&"assign_persistent_id", LEVEL_ID)))
	return &""


func _apply_persistent_world_state() -> void:
	if _game_state == null:
		return
	for node: Node in find_children("*", "", true, false):
		if not node.has_signal(&"pickup_collected"):
			continue
		var persistent_id: StringName = _assign_pickup_persistent_id(node)
		if String(persistent_id).is_empty():
			continue
		if node.has_method(&"set_persistently_collected"):
			node.call(&"set_persistently_collected", _game_state.is_pickup_collected(persistent_id))


func _on_damage_requested(hylas_body: Node, amount: int) -> void:
	if not _active or _game_state == null or hylas_body == null:
		return
	if hylas_body != _hylas and not hylas_body.is_in_group(&"hylas"):
		return
	var now_msec: int = Time.get_ticks_msec()
	var immunity_msec: int = roundi(maxf(0.0, damage_invulnerability_seconds) * 1000.0)
	if now_msec - _last_damage_time_msec < immunity_msec:
		return
	var applied_damage: int = _game_state.damage_fins(amount)
	if applied_damage <= 0:
		return
	_last_damage_time_msec = now_msec
	if _hylas.has_method(&"play_fin_loss_sound"):
		_hylas.call(&"play_fin_loss_sound")


func _on_shark_contacted(hylas_body: Node2D) -> void:
	_on_damage_requested(hylas_body, 1)


func _on_food_pickup_collected(
		pickup_type_id: StringName,
		pickup_instance_id: StringName,
		heal_amount: int,
		restores_full: bool,
		activates_greatfin: bool,
		full_health_onos_value: int,
		pickup_node: Node,
	) -> void:
	if not _active or _game_state == null:
		return
	var persistent_id: StringName = pickup_instance_id
	if String(persistent_id).is_empty():
		persistent_id = _assign_pickup_persistent_id(pickup_node)
	if String(persistent_id).is_empty():
		push_warning("A pickup was collected without a persistent instance ID.")
		return
	if _game_state.is_pickup_collected(persistent_id):
		return

	var healed_fins: int = 0
	if restores_full:
		healed_fins = _game_state.restore_fins()
	else:
		healed_fins = _game_state.heal_fins(heal_amount)
	if healed_fins <= 0 and full_health_onos_value > 0:
		_game_state.add_onos(full_health_onos_value)
	if activates_greatfin:
		greatfin_pickup_requested.emit(pickup_type_id)
	_game_state.mark_pickup_collected(persistent_id)


func _on_game_state_replaced(_reason: StringName) -> void:
	_apply_persistent_world_state()


func _on_player_defeated() -> void:
	if not _active or not auto_respawn_on_zero_fins or _respawn_pending:
		return
	_respawn_pending = true
	call_deferred(&"_respawn_at_tracked_checkpoint")


func _respawn_at_tracked_checkpoint() -> void:
	if not _active or _game_state == null:
		_respawn_pending = false
		return
	_hylas.set_play_enabled(false)
	_active_spawn_point_id = _resolve_spawn_point_id(_game_state.current_spawn_point_id)
	if restore_full_fins_on_respawn:
		_game_state.restore_fins()
	else:
		_game_state.set_fin_state(1, _game_state.max_fins)
	_hylas.reset_to_start(_resolve_spawn_position(_active_spawn_point_id))
	_last_damage_time_msec = Time.get_ticks_msec()
	_hylas.set_play_enabled(true)
	_respawn_pending = false


func _prepare_bubble_material() -> void:
	var source_material: ShaderMaterial = _bubble_overlay.material as ShaderMaterial
	if source_material == null:
		return
	_bubble_material = source_material.duplicate() as ShaderMaterial
	_bubble_overlay.material = _bubble_material
	_bubble_material.set_shader_parameter(&"waterline_fade", bubble_waterline_fade)


func _update_bubble_waterline_mask() -> void:
	if _bubble_material == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	if viewport_height <= 0.0:
		return
	var waterline_screen_position: Vector2 = get_viewport().get_canvas_transform() * _waterline_marker.global_position
	var waterline_screen_y: float = waterline_screen_position.y / viewport_height
	_bubble_material.set_shader_parameter(&"waterline_screen_y", waterline_screen_y)


func _play_underwater_ambience() -> void:
	if not auto_play_ambience or _underwater_ambience.stream == null:
		return
	_underwater_ambience.stream_paused = false
	if not _underwater_ambience.playing:
		_underwater_ambience.play()


func _on_hylas_normal_conch_used(origin: Vector2, direction: Vector2) -> void:
	if not _active:
		return
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()
	var pulse_origin: Vector2 = origin + pulse_direction * conch_origin_forward_offset
	_conch_pulse.trigger(pulse_origin, pulse_direction)


func _on_conch_pulse_target_hit(target: Node2D, hit_position: Vector2, pulse_index: int) -> void:
	if not _active:
		return
	_spawn_conch_impact(hit_position)
	conch_target_hit.emit(target, hit_position, pulse_index)


func _spawn_conch_impact(hit_position: Vector2) -> void:
	var impact: Node2D = CONCH_IMPACT_SCENE.instantiate() as Node2D
	if impact == null:
		return
	add_child(impact)
	impact.global_position = hit_position
	if impact.has_method(&"play_effect"):
		impact.call(&"play_effect")


func _clear_conch_impacts() -> void:
	for child: Node in get_children():
		if child.is_in_group(&"conch_impact_effect"):
			child.queue_free()


func _on_hylas_surface_splash_requested(origin: Vector2, is_exit: bool) -> void:
	if not _active:
		return
	if is_exit:
		_exit_surface_splash.trigger(origin)
	else:
		_entry_surface_splash.trigger(origin)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[SeaOfPillars]",
		"active=%s" % str(_active),
		"spawn_point_id=%s" % String(_active_spawn_point_id),
		"bubble_overlay_visible=%s" % str(_bubble_overlay.visible),
		"bubble_waterline_update_interval=%.2f" % bubble_waterline_update_interval,
		"ambience_playing=%s" % str(_underwater_ambience.playing),
		"respawn_pending=%s" % str(_respawn_pending),
	]
	if _game_state != null:
		lines.append("fins=%d/%d" % [_game_state.current_fins, _game_state.max_fins])
		lines.append("onos=%d" % _game_state.onos)
		lines.append("collected_pickups=%d" % _game_state.collected_pickups.size())
	lines.append_array(_conch_pulse.get_debug_lines())
	lines.append_array(_hylas.get_debug_lines())
	return lines
