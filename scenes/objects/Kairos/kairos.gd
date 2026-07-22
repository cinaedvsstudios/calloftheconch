class_name CotcKairos
extends StaticBody2D

## Kairos is a one-eyed chance/beggar octopus. He is not a normal enemy.
## The player gets one gamble per Kairos instance per life/session. The used
## state is deliberately not saved, so death, reload, quit, or session restart
## gives the player another chance.

signal kairos_interacted(kairos: CotcKairos)
signal kairos_outcome_started(kairos: CotcKairos, outcome: StringName)
signal kairos_outcome_finished(kairos: CotcKairos, outcome: StringName)
signal kairos_refused(kairos: CotcKairos)
signal kairos_stunned(kairos: CotcKairos)

enum KairosState {
	IDLE,
	INTERACTING,
	RESULT,
	USED,
	STUNNED,
}

const OUTCOME_GIVE_ONOS: StringName = &"give_onos"
const OUTCOME_TAKE_ONOS: StringName = &"take_onos"
const OUTCOME_GIVE_FIN: StringName = &"give_fin"
const OUTCOME_TAKE_FIN: StringName = &"take_fin"
const OUTCOME_CROWN_GRAPES: StringName = &"crown_sea_grapes"
const OUTCOME_HIGH_VALUE: StringName = &"high_value_pickup"
const OUTCOME_REMOVE_ENEMIES: StringName = &"remove_visible_enemies"
const OUTCOME_DOUBLE_ENEMIES: StringName = &"double_visible_enemies"
const OUTCOME_BAD_LUCK: StringName = &"bad_luck"

const GREETING_LINE: String = "Care to try your luck, friend?"
const ALREADY_USED_LINE: String = "Sorry, my friend. You already had your chance today."
const STUNNED_LINE: String = "No luck for the violent, friend."
const NO_MONEY_LINE: String = "Nothing in your shell. How tragic."
const LAST_FIN_BLOCKED_LINE: String = "Ah. Not that. Even I have rules."
const NOTHING_TO_TAKE_LINE: String = "Ah. Nothing worth taking today."
const QUIET_SEA_LINE: String = "The sea is quiet. Lucky you."

@export_category("Presentation")
@export_range(20.0, 420.0, 1.0) var display_height: float = 155.0
@export_range(0.0, 32.0, 0.5) var idle_bob_amplitude: float = 8.0
@export_range(0.01, 2.0, 0.01) var idle_bob_frequency: float = 0.38
@export_range(0.0, 32.0, 0.5) var idle_drift_amplitude: float = 3.0
@export_range(0.01, 2.0, 0.01) var idle_drift_frequency: float = 0.23
@export_range(0.05, 1.5, 0.01) var interaction_shake_seconds: float = 0.38
@export_range(0.0, 28.0, 0.5) var interaction_shake_pixels: float = 7.0
@export_range(0.2, 5.0, 0.1) var dialogue_seconds: float = 2.4
@export var good_flash_color: Color = Color(0.74, 1.0, 0.35, 1.0)
@export var bad_flash_color: Color = Color(0.74, 0.28, 1.0, 1.0)
@export var neutral_flash_color: Color = Color(0.22, 1.0, 0.92, 1.0)

@export_category("Interaction")
@export_range(0.1, 12.0, 0.1) var stun_seconds: float = 3.5
@export var reset_chance_on_game_state_replace: bool = true
@export var reset_chance_on_respawn: bool = true

@export_category("Outcome Weights")
@export_range(0.0, 100.0, 0.5) var give_onos_weight: float = 20.0
@export_range(0.0, 100.0, 0.5) var take_onos_weight: float = 20.0
@export_range(0.0, 100.0, 0.5) var give_fin_weight: float = 12.0
@export_range(0.0, 100.0, 0.5) var take_fin_weight: float = 12.0
@export_range(0.0, 100.0, 0.5) var crown_grapes_weight: float = 8.0
@export_range(0.0, 100.0, 0.5) var high_value_weight: float = 8.0
@export_range(0.0, 100.0, 0.5) var remove_enemies_weight: float = 10.0
@export_range(0.0, 100.0, 0.5) var double_enemies_weight: float = 10.0

@export_category("Onos Outcomes")
@export_range(0, 999, 1) var give_onos_min: int = 5
@export_range(0, 999, 1) var give_onos_max: int = 15
@export_range(0, 999, 1) var take_onos_min: int = 5
@export_range(0, 999, 1) var take_onos_max: int = 15
@export_range(0, 999, 1) var high_value_onos_min: int = 25
@export_range(0, 999, 1) var high_value_onos_max: int = 50
@export_range(0, 999, 1) var quiet_sea_fallback_onos: int = 5

@export_category("Visible Enemy Outcomes")
@export_range(0.0, 480.0, 1.0) var camera_query_padding: float = 120.0
@export_range(0, 30, 1) var maximum_doubled_enemies: int = 5
@export var duplicate_enemy_offset: Vector2 = Vector2(72.0, -28.0)

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _interaction_area: Area2D = %InteractionArea
@onready var _dialogue_label: Label = %DialogueLabel
@onready var _outcome_spawn_marker: Marker2D = %OutcomeSpawnMarker

var used_this_life: bool = false
var current_result: StringName = &""
var placed_id: StringName = &""

var _state: KairosState = KairosState.IDLE
var _game_state: CotcGameState
var _active_hylas: Node
var _sprite_rest_position: Vector2 = Vector2.ZERO
var _sprite_rest_scale: Vector2 = Vector2.ONE
var _elapsed: float = 0.0
var _shake_remaining: float = 0.0
var _dialogue_remaining: float = 0.0
var _stun_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()
var _flash_tween: Tween


func _ready() -> void:
	_rng.randomize()
	placed_id = StringName(name)
	_sprite_rest_position = _sprite.position
	_apply_display_scale()
	_connect_interaction_area()
	_resolve_game_state()
	_connect_game_state_signals()
	_set_state(KairosState.IDLE)
	set_process(true)


func _exit_tree() -> void:
	_disconnect_hylas_interaction()
	_disconnect_game_state_signals()


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	_update_dialogue(delta)
	_update_stun(delta)
	_update_presentation(delta)


func bind_game_state(game_state: CotcGameState) -> void:
	if _game_state == game_state:
		return
	_disconnect_game_state_signals()
	_game_state = game_state
	_connect_game_state_signals()


func interact(source: Node) -> void:
	if source == null:
		source = _active_hylas
	if _state == KairosState.STUNNED:
		_show_dialogue(STUNNED_LINE)
		kairos_refused.emit(self)
		return
	if used_this_life:
		_set_state(KairosState.USED)
		_show_dialogue(ALREADY_USED_LINE)
		_start_flash(neutral_flash_color)
		kairos_refused.emit(self)
		return
	_begin_gamble(source)


func receive_tail_flip_bash(
		_contact_position: Vector2,
		_normal: Vector2,
		_source: Node,
	) -> void:
	_begin_stun()


func has_used_chance() -> bool:
	return used_this_life


func reset_chance_for_life() -> void:
	used_this_life = false
	current_result = &""
	if _state == KairosState.USED:
		_set_state(KairosState.IDLE)


func get_debug_lines() -> Array[String]:
	return [
		"[Kairos]",
		"used_this_life=%s" % str(used_this_life),
		"state=%s" % KairosState.keys()[_state],
		"last_outcome=%s" % String(current_result),
		"eligible_visible_enemies=%d" % _get_visible_enemy_candidates().size(),
		"hylas_near=%s" % str(is_instance_valid(_active_hylas)),
	]


func _connect_interaction_area() -> void:
	if not _interaction_area.body_entered.is_connected(_on_interaction_body_entered):
		_interaction_area.body_entered.connect(_on_interaction_body_entered)
	if not _interaction_area.body_exited.is_connected(_on_interaction_body_exited):
		_interaction_area.body_exited.connect(_on_interaction_body_exited)


func _on_interaction_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group(&"hylas"):
		return
	_active_hylas = body
	if body.has_method(&"set_interaction_available"):
		body.call(&"set_interaction_available", true)
	if body.has_signal(&"interaction_requested"):
		var callback: Callable = Callable(self, "_on_hylas_interaction_requested")
		if not body.is_connected(&"interaction_requested", callback):
			body.connect(&"interaction_requested", callback)


func _on_interaction_body_exited(body: Node2D) -> void:
	if body == null or body != _active_hylas:
		return
	if body.has_method(&"set_interaction_available"):
		body.call(&"set_interaction_available", false)
	_disconnect_hylas_interaction()
	_active_hylas = null


func _disconnect_hylas_interaction() -> void:
	if not is_instance_valid(_active_hylas):
		return
	var callback: Callable = Callable(self, "_on_hylas_interaction_requested")
	if _active_hylas.has_signal(&"interaction_requested") and _active_hylas.is_connected(&"interaction_requested", callback):
		_active_hylas.disconnect(&"interaction_requested", callback)


func _on_hylas_interaction_requested() -> void:
	if not is_instance_valid(_active_hylas):
		return
	interact(_active_hylas)


func _begin_gamble(source: Node) -> void:
	used_this_life = true
	_set_state(KairosState.INTERACTING)
	kairos_interacted.emit(self)
	_show_dialogue(GREETING_LINE, 1.1)
	_start_shake(interaction_shake_seconds)
	current_result = _roll_outcome()
	kairos_outcome_started.emit(self, current_result)
	apply_kairos_outcome(current_result, source)
	kairos_outcome_finished.emit(self, current_result)
	_set_state(KairosState.RESULT)


func _begin_stun() -> void:
	_stun_remaining = stun_seconds
	_set_state(KairosState.STUNNED)
	_start_shake(interaction_shake_seconds)
	_start_flash(bad_flash_color)
	_show_dialogue(STUNNED_LINE)
	kairos_stunned.emit(self)


func _set_state(new_state: KairosState) -> void:
	_state = new_state
	match _state:
		KairosState.STUNNED:
			_sprite.play(&"stunned")
		KairosState.USED:
			_sprite.play(&"used")
		KairosState.INTERACTING, KairosState.RESULT:
			_sprite.play(&"interact")
		_:
			_sprite.play(&"idle")


func _roll_outcome() -> StringName:
	var entries: Array[Dictionary] = [
		{"outcome": OUTCOME_GIVE_ONOS, "weight": give_onos_weight},
		{"outcome": OUTCOME_TAKE_ONOS, "weight": take_onos_weight},
		{"outcome": OUTCOME_GIVE_FIN, "weight": give_fin_weight},
		{"outcome": OUTCOME_TAKE_FIN, "weight": take_fin_weight},
		{"outcome": OUTCOME_CROWN_GRAPES, "weight": crown_grapes_weight},
		{"outcome": OUTCOME_HIGH_VALUE, "weight": high_value_weight},
		{"outcome": OUTCOME_REMOVE_ENEMIES, "weight": remove_enemies_weight},
		{"outcome": OUTCOME_DOUBLE_ENEMIES, "weight": double_enemies_weight},
	]
	var total_weight: float = 0.0
	for entry: Dictionary in entries:
		total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		return OUTCOME_BAD_LUCK
	var roll: float = _rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0
	for entry: Dictionary in entries:
		cursor += maxf(0.0, float(entry.get("weight", 0.0)))
		if roll <= cursor:
			return entry.get("outcome", OUTCOME_BAD_LUCK) as StringName
	return OUTCOME_BAD_LUCK


func apply_kairos_outcome(outcome: StringName, source: Node) -> void:
	_resolve_game_state()
	match outcome:
		OUTCOME_GIVE_ONOS:
			_apply_give_onos()
		OUTCOME_TAKE_ONOS:
			_apply_take_onos()
		OUTCOME_GIVE_FIN:
			_apply_give_fin()
		OUTCOME_TAKE_FIN:
			_apply_take_fin()
		OUTCOME_CROWN_GRAPES:
			_apply_crown_grapes()
		OUTCOME_HIGH_VALUE:
			_apply_high_value()
		OUTCOME_REMOVE_ENEMIES:
			_apply_remove_visible_enemies()
		OUTCOME_DOUBLE_ENEMIES:
			_apply_double_visible_enemies()
		_:
			_show_dialogue("Kairos watches the current pass by.")
			_start_flash(neutral_flash_color)
	if is_instance_valid(source) and source.has_method(&"cancel_pending_interaction"):
		source.call(&"cancel_pending_interaction")


func _apply_give_onos() -> void:
	var amount: int = _random_int_range(give_onos_min, give_onos_max)
	if _game_state != null:
		_game_state.add_onos(amount)
	_show_dialogue("Fortune smiles. Take %d onos." % amount)
	_start_flash(good_flash_color)


func _apply_take_onos() -> void:
	if _game_state == null or _game_state.onos <= 0:
		_show_dialogue(NO_MONEY_LINE)
		_start_flash(bad_flash_color)
		return
	var amount: int = mini(_random_int_range(take_onos_min, take_onos_max), _game_state.onos)
	if amount <= 0:
		_show_dialogue(NO_MONEY_LINE)
		_start_flash(bad_flash_color)
		return
	_game_state.add_onos(-amount)
	_show_dialogue("Ah, a small offering for Kairos. -%d onos." % amount)
	_start_flash(bad_flash_color)


func _apply_give_fin() -> void:
	if _game_state == null:
		_show_dialogue("Life returns when chance allows it.")
		_start_flash(good_flash_color)
		return
	var healed: int = _game_state.heal_fins(1)
	if healed > 0:
		_show_dialogue("Life returns when chance allows it. +1 fin.")
	else:
		var amount: int = _random_int_range(give_onos_min, give_onos_max)
		_game_state.add_onos(amount)
		_show_dialogue("Your fins are full. Take %d onos instead." % amount)
	_start_flash(good_flash_color)


func _apply_take_fin() -> void:
	if _game_state == null:
		_show_dialogue(LAST_FIN_BLOCKED_LINE)
		_start_flash(neutral_flash_color)
		return
	if not _game_state.greatfin_active and _game_state.current_fins <= 1:
		if _game_state.onos > 0:
			_apply_take_onos()
		else:
			_show_dialogue(NOTHING_TO_TAKE_LINE)
			_start_flash(neutral_flash_color)
		return
	_game_state.damage_fins(1)
	_show_dialogue("Chance bites as often as it blesses. -1 fin.")
	_start_flash(bad_flash_color)


func _apply_crown_grapes() -> void:
	if _game_state != null:
		_game_state.use_crown_sea_grapes(5)
	_show_dialogue("A rare sweetness, from one friend to another.")
	_start_flash(good_flash_color)


func _apply_high_value() -> void:
	var amount: int = _random_int_range(high_value_onos_min, high_value_onos_max)
	if _game_state != null:
		_game_state.add_onos(amount)
	_show_dialogue("Not all beggars are poor. +%d onos." % amount)
	_start_flash(good_flash_color)


func _apply_remove_visible_enemies() -> void:
	var removed_count: int = _remove_visible_enemies()
	if removed_count <= 0:
		_apply_quiet_sea_fallback()
		return
	_show_dialogue("Let the sea clear your path. %d gone." % removed_count)
	_start_flash(good_flash_color)


func _apply_double_visible_enemies() -> void:
	var doubled_count: int = _double_visible_enemies()
	if doubled_count <= 0:
		_apply_quiet_sea_fallback()
		return
	_show_dialogue("More company for you, friend. +%d." % doubled_count)
	_start_flash(bad_flash_color)


func _apply_quiet_sea_fallback() -> void:
	if _game_state != null and quiet_sea_fallback_onos > 0:
		_game_state.add_onos(quiet_sea_fallback_onos)
		_show_dialogue("%s +%d onos." % [QUIET_SEA_LINE, quiet_sea_fallback_onos])
	else:
		_show_dialogue(QUIET_SEA_LINE)
	_start_flash(neutral_flash_color)


func _remove_visible_enemies() -> int:
	var enemies: Array[Node2D] = _get_visible_enemy_candidates()
	for enemy: Node2D in enemies:
		if enemy.has_method(&"kairos_remove_from_view"):
			enemy.call(&"kairos_remove_from_view", self)
		else:
			enemy.queue_free()
	return enemies.size()


func _double_visible_enemies() -> int:
	var enemies: Array[Node2D] = _get_visible_enemy_candidates()
	var doubled_count: int = 0
	for enemy: Node2D in enemies:
		if doubled_count >= maximum_doubled_enemies:
			break
		if enemy == null or not is_instance_valid(enemy):
			continue
		var parent: Node = enemy.get_parent()
		if parent == null:
			continue
		var duplicate_node: Node = enemy.duplicate()
		var duplicate_2d: Node2D = duplicate_node as Node2D
		if duplicate_2d == null:
			duplicate_node.queue_free()
			continue
		parent.add_child(duplicate_2d)
		duplicate_2d.global_position = enemy.global_position + _duplicate_offset_for_index(doubled_count)
		doubled_count += 1
	return doubled_count


func _get_visible_enemy_candidates() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var camera_rect: Rect2 = _get_visible_world_rect().grow(camera_query_padding)
	for candidate: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy: Node2D = candidate as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not _is_enemy_eligible(enemy):
			continue
		if not camera_rect.has_point(enemy.global_position):
			continue
		candidates.append(enemy)
	return candidates


func _is_enemy_eligible(enemy: Node) -> bool:
	if enemy == self:
		return false
	if enemy.is_in_group(&"boss") or enemy.is_in_group(&"mini_boss"):
		return false
	if enemy.is_in_group(&"protected_enemy") or enemy.is_in_group(&"non_duplicate_enemy"):
		return false
	if enemy.is_in_group(&"npc") or enemy.is_in_group(&"shop") or enemy.is_in_group(&"kairos"):
		return false
	return true


func _get_visible_world_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return Rect2(global_position - viewport_size * 0.5, viewport_size)
	var zoom: Vector2 = Vector2(
		maxf(0.001, absf(camera.zoom.x)),
		maxf(0.001, absf(camera.zoom.y)),
	)
	var visible_size: Vector2 = Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
	return Rect2(camera.get_screen_center_position() - visible_size * 0.5, visible_size)


func _duplicate_offset_for_index(index: int) -> Vector2:
	var sign: float = -1.0 if index % 2 == 0 else 1.0
	var row: float = float(index / 2)
	return Vector2(duplicate_enemy_offset.x * sign, duplicate_enemy_offset.y + row * 34.0)


func _update_dialogue(delta: float) -> void:
	if _dialogue_remaining <= 0.0:
		return
	_dialogue_remaining = maxf(0.0, _dialogue_remaining - delta)
	if _dialogue_remaining <= 0.0 and is_instance_valid(_dialogue_label):
		_dialogue_label.hide()


func _update_stun(delta: float) -> void:
	if _state != KairosState.STUNNED:
		return
	_stun_remaining = maxf(0.0, _stun_remaining - delta)
	if _stun_remaining <= 0.0:
		_set_state(KairosState.USED if used_this_life else KairosState.IDLE)


func _update_presentation(delta: float) -> void:
	var bob_offset: Vector2 = Vector2(
		sin(_elapsed * TAU * idle_drift_frequency) * idle_drift_amplitude,
		sin(_elapsed * TAU * idle_bob_frequency) * idle_bob_amplitude,
	)
	var shake_offset: Vector2 = Vector2.ZERO
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - delta)
		var shake_ratio: float = _shake_remaining / maxf(0.01, interaction_shake_seconds)
		shake_offset = Vector2(
			_rng.randf_range(-interaction_shake_pixels, interaction_shake_pixels),
			_rng.randf_range(-interaction_shake_pixels, interaction_shake_pixels),
		) * shake_ratio
	_sprite.position = _sprite_rest_position + bob_offset + shake_offset


func _start_shake(duration: float) -> void:
	_shake_remaining = maxf(_shake_remaining, duration)


func _start_flash(flash_color: Color) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, ^"modulate", Color.WHITE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_dialogue(text: String, duration: float = -1.0) -> void:
	if not is_instance_valid(_dialogue_label):
		return
	_dialogue_label.text = text
	_dialogue_label.show()
	_dialogue_remaining = dialogue_seconds if duration <= 0.0 else duration


func _apply_display_scale() -> void:
	if _sprite.sprite_frames == null:
		return
	var texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		return
	var texture_height: float = float(texture.get_height())
	if texture_height <= 0.0:
		return
	var scale_factor: float = display_height / texture_height
	_sprite_rest_scale = Vector2.ONE * scale_factor
	_sprite.scale = _sprite_rest_scale


func _random_int_range(minimum_value: int, maximum_value: int) -> int:
	var resolved_minimum: int = mini(minimum_value, maximum_value)
	var resolved_maximum: int = maxi(minimum_value, maximum_value)
	return _rng.randi_range(resolved_minimum, resolved_maximum)


func _resolve_game_state() -> void:
	if is_instance_valid(_game_state):
		return
	var root: Window = get_tree().root
	var front_end_game_state: Node = root.get_node_or_null("FrontEnd/GameState")
	_game_state = front_end_game_state as CotcGameState
	if is_instance_valid(_game_state):
		return
	_game_state = root.find_child("GameState", true, false) as CotcGameState


func _connect_game_state_signals() -> void:
	if not is_instance_valid(_game_state):
		return
	if reset_chance_on_game_state_replace and not _game_state.state_replaced.is_connected(_on_game_state_replaced):
		_game_state.state_replaced.connect(_on_game_state_replaced)
	if reset_chance_on_respawn and not _game_state.player_respawned.is_connected(_on_player_respawned):
		_game_state.player_respawned.connect(_on_player_respawned)


func _disconnect_game_state_signals() -> void:
	if not is_instance_valid(_game_state):
		return
	if _game_state.state_replaced.is_connected(_on_game_state_replaced):
		_game_state.state_replaced.disconnect(_on_game_state_replaced)
	if _game_state.player_respawned.is_connected(_on_player_respawned):
		_game_state.player_respawned.disconnect(_on_player_respawned)


func _on_game_state_replaced(_reason: StringName) -> void:
	reset_chance_for_life()


func _on_player_respawned(_level_id: StringName, _spawn_id: StringName) -> void:
	reset_chance_for_life()
