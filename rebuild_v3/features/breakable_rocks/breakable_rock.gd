class_name CotcBreakableRock
extends StaticBody2D

## Owns rock integrity, sprite state and collision state. Hylas and conch systems
## only deliver focused hit data; this scene decides whether it chips or breaks.

signal rock_state_changed(persistent_id: StringName, state_id: StringName, integrity: int)
signal rock_broken(persistent_id: StringName)

const CATEGORY_SMALL_BREAK: StringName = &"small_break"
const CATEGORY_BIG_BREAK: StringName = &"big_break"
const STATE_INTACT: StringName = &"intact"
const STATE_CRACKED: StringName = &"cracked"
const STATE_BROKEN: StringName = &"broken"

const ROCK_DEBRIS_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/rock_debris_burst/rock_debris_burst.tscn"
)

@export_category("Rock Identity")
@export var persistent_id: StringName = &""
@export_enum("small_break", "big_break") var break_category: String = "small_break"

@export_category("Integrity")
@export_range(1, 20, 1) var maximum_integrity: int = 1
@export_range(0, 10, 1) var tail_flip_damage: int = 1
@export_range(0, 10, 1) var drill_pulse_damage: int = 1
@export_range(0.0, 5.0, 0.05) var repeated_drill_hit_cooldown: float = 0.12

@export_category("Debris")
@export var rock_tint: Color = Color.WHITE
@export_range(0.10, 3.0, 0.05) var debris_intensity: float = 1.0

@export_category("Audio")
@export var break_audio_stream: AudioStream
@export_range(-30.0, 6.0, 1.0) var break_audio_volume_db: float = -5.0

@onready var _intact_sprite: Sprite2D = %IntactSprite
@onready var _cracked_sprite: Sprite2D = %CrackedSprite
@onready var _broken_sprite: Sprite2D = %BrokenSprite
@onready var _intact_collision: CollisionPolygon2D = %IntactCollision
@onready var _broken_collision_left: CollisionPolygon2D = %BrokenCollisionLeft
@onready var _broken_collision_right: CollisionPolygon2D = %BrokenCollisionRight
@onready var _debris_origin: Marker2D = %DebrisOrigin
@onready var _break_audio: AudioStreamPlayer2D = %BreakAudio

var _integrity: int = 1
var _state_id: StringName = STATE_INTACT
var _last_drill_hit_msec: int = -1000000
var _last_hit_kind: StringName = &""


func _ready() -> void:
	maximum_integrity = maxi(1, maximum_integrity)
	_integrity = maximum_integrity
	if break_audio_stream != null:
		_break_audio.stream = break_audio_stream
	_break_audio.volume_db = break_audio_volume_db
	_apply_state_without_effects(STATE_INTACT, _integrity)


func assign_persistent_id(level_id: StringName) -> StringName:
	if not String(persistent_id).is_empty():
		return persistent_id
	var level_key: String = String(level_id)
	if level_key.is_empty():
		level_key = "unknown_level"
	persistent_id = StringName("%s:%s" % [level_key, String(name)])
	return persistent_id


func receive_tail_flip_bash(
		contact_position: Vector2,
		normal: Vector2,
		source: Node,
	) -> bool:
	if is_broken():
		return false
	_last_hit_kind = &"tail_flip"
	var incoming_direction: Vector2 = _resolve_incoming_direction(source, normal)
	if _resolved_category() == CATEGORY_BIG_BREAK or tail_flip_damage <= 0:
		_spawn_debris(
			contact_position,
			normal,
			incoming_direction,
			CotcRockDebrisBurst.MODE_RICOCHET_SCRAPE,
			0.85,
		)
		return false
	return _apply_damage(
		tail_flip_damage,
		contact_position,
		normal,
		incoming_direction,
		CotcRockDebrisBurst.MODE_SMALL_BREAK,
	)


func receive_drill_pulse(
		contact_position: Vector2,
		normal: Vector2,
		pulse_index: int,
		source: Node,
	) -> bool:
	if is_broken() or drill_pulse_damage <= 0:
		return false
	var now_msec: int = Time.get_ticks_msec()
	var cooldown_msec: int = roundi(maxf(0.0, repeated_drill_hit_cooldown) * 1000.0)
	if now_msec - _last_drill_hit_msec < cooldown_msec:
		return false
	_last_drill_hit_msec = now_msec
	_last_hit_kind = StringName("drill_%d" % pulse_index)
	var incoming_direction: Vector2 = _resolve_incoming_direction(source, normal)
	_spawn_debris(
		contact_position,
		normal,
		incoming_direction,
		CotcRockDebrisBurst.MODE_DRILL_TICK,
		0.90,
	)
	var final_mode: StringName = (
		CotcRockDebrisBurst.MODE_BIG_BREAK
		if _resolved_category() == CATEGORY_BIG_BREAK
		else CotcRockDebrisBurst.MODE_SMALL_BREAK
	)
	return _apply_damage(
		drill_pulse_damage,
		contact_position,
		normal,
		incoming_direction,
		final_mode,
	)


func receive_ricochet_scrape(
		contact_position: Vector2,
		normal: Vector2,
		incoming_direction: Vector2,
		_source: Node = null,
	) -> void:
	if is_broken():
		return
	_last_hit_kind = &"ricochet"
	_spawn_debris(
		contact_position,
		normal,
		incoming_direction,
		CotcRockDebrisBurst.MODE_RICOCHET_SCRAPE,
		0.80,
	)


func receive_rock_surface_hit(
		contact_position: Vector2,
		normal: Vector2,
		source_kind: StringName,
		incoming_direction: Vector2 = Vector2.ZERO,
	) -> void:
	if is_broken():
		return
	_last_hit_kind = source_kind
	_spawn_debris(
		contact_position,
		normal,
		incoming_direction,
		CotcRockDebrisBurst.MODE_RICOCHET_SCRAPE,
		0.70,
	)


func receive_conch_hit(
		_origin: Vector2,
		_direction: Vector2,
		_distance: float,
		_strength: float,
	) -> void:
	# Normal and Super Conch can target this rock for ordinary contact feedback,
	# but only the focused Terebridae receive_drill_pulse() route damages it.
	pass


func get_conch_hit_position() -> Vector2:
	return _debris_origin.global_position if is_instance_valid(_debris_origin) else global_position


func is_broken() -> bool:
	return _state_id == STATE_BROKEN


func get_integrity() -> int:
	return _integrity


func get_state_id() -> StringName:
	return _state_id


func get_persistent_state() -> Dictionary:
	return {
		"state": String(_state_id),
		"integrity": _integrity,
	}


func set_persistent_state(state_id: StringName, saved_integrity: int = -1) -> void:
	var resolved_state: StringName = state_id
	if resolved_state not in [STATE_INTACT, STATE_CRACKED, STATE_BROKEN]:
		resolved_state = STATE_INTACT
	var resolved_integrity: int = saved_integrity
	if resolved_integrity < 0:
		resolved_integrity = 0 if resolved_state == STATE_BROKEN else maximum_integrity
	_apply_state_without_effects(
		resolved_state,
		clampi(resolved_integrity, 0, maximum_integrity),
	)


func _apply_damage(
		amount: int,
		contact_position: Vector2,
		normal: Vector2,
		incoming_direction: Vector2,
		final_debris_mode: StringName,
	) -> bool:
	if amount <= 0 or is_broken():
		return false
	_integrity = maxi(0, _integrity - amount)
	if _integrity <= 0:
		return _break_rock(
			contact_position,
			normal,
			incoming_direction,
			final_debris_mode,
		)
	_update_cracked_state()
	rock_state_changed.emit(persistent_id, _state_id, _integrity)
	return false


func _break_rock(
		contact_position: Vector2,
		normal: Vector2,
		incoming_direction: Vector2,
		final_debris_mode: StringName,
	) -> bool:
	if is_broken() or not _can_show_broken_state():
		return false
	_integrity = 0
	_state_id = STATE_BROKEN
	_spawn_debris(
		contact_position,
		normal,
		incoming_direction,
		final_debris_mode,
		debris_intensity,
	)
	_apply_visual_and_collision_state()
	_play_break_audio()
	rock_state_changed.emit(persistent_id, _state_id, _integrity)
	rock_broken.emit(persistent_id)
	return true


func _update_cracked_state() -> void:
	if _cracked_sprite.texture != null and _integrity * 2 <= maximum_integrity:
		_state_id = STATE_CRACKED
	else:
		_state_id = STATE_INTACT
	_apply_visual_and_collision_state()


func _apply_state_without_effects(state_id: StringName, integrity_value: int) -> void:
	_state_id = state_id
	_integrity = clampi(integrity_value, 0, maximum_integrity)
	if _state_id == STATE_BROKEN and not _can_show_broken_state():
		_state_id = STATE_INTACT
		_integrity = maximum_integrity
	_apply_visual_and_collision_state()


func _apply_visual_and_collision_state() -> void:
	var broken: bool = _state_id == STATE_BROKEN
	var cracked: bool = _state_id == STATE_CRACKED and _cracked_sprite.texture != null
	_intact_sprite.visible = not broken and not cracked
	_cracked_sprite.visible = cracked
	_broken_sprite.visible = broken

	_intact_collision.set_deferred(&"disabled", broken)
	_broken_collision_left.set_deferred(&"disabled", not broken)
	_broken_collision_right.set_deferred(&"disabled", not broken)


func _can_show_broken_state() -> bool:
	if _broken_sprite.texture == null:
		push_warning("Breakable rock '%s' has no broken sprite; leaving it intact." % name)
		return false
	if (
			_broken_collision_left.polygon.size() < 3
			or _broken_collision_right.polygon.size() < 3
		):
		push_warning(
			"Breakable rock '%s' has incomplete open-state collision; leaving it intact." % name
		)
		return false
	return true


func _spawn_debris(
		contact_position: Vector2,
		normal: Vector2,
		incoming_direction: Vector2,
		mode: StringName,
		intensity_multiplier: float,
	) -> void:
	var debris: CotcRockDebrisBurst = ROCK_DEBRIS_SCENE.instantiate() as CotcRockDebrisBurst
	if debris == null:
		return
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(debris)
	debris.play_burst(
		contact_position,
		normal,
		incoming_direction,
		mode,
		rock_tint,
		debris_intensity * intensity_multiplier,
	)


func _resolve_incoming_direction(source: Node, normal: Vector2) -> Vector2:
	if is_instance_valid(source) and source is CharacterBody2D:
		var body: CharacterBody2D = source as CharacterBody2D
		if body.velocity.length_squared() > 0.0001:
			return body.velocity.normalized()
	return -normal.normalized()


func _resolved_category() -> StringName:
	return StringName(break_category)


func _play_break_audio() -> void:
	if _break_audio.stream == null:
		return
	_break_audio.stop()
	_break_audio.play()


func get_debug_lines() -> Array[String]:
	return [
		"[BreakableRock]",
		"persistent_id=%s" % String(persistent_id),
		"category=%s" % String(_resolved_category()),
		"state=%s" % String(_state_id),
		"integrity=%d/%d" % [_integrity, maximum_integrity],
		"intact_collision_disabled=%s" % str(_intact_collision.disabled),
		"broken_left_disabled=%s" % str(_broken_collision_left.disabled),
		"broken_right_disabled=%s" % str(_broken_collision_right.disabled),
		"last_hit_kind=%s" % String(_last_hit_kind),
	]
