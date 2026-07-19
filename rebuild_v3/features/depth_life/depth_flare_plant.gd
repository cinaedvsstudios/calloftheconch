class_name CotcDepthFlarePlant
extends CotcDepthStunnableEnemy

## Stationary dark-depth plant that periodically opens and releases warm sparks.

@export_category("Display")
@export_range(40.0, 600.0, 1.0) var display_height: float = 210.0

@export_category("Flare Cycle")
@export_range(0.2, 30.0, 0.1) var flare_interval_min: float = 3.8
@export_range(0.2, 30.0, 0.1) var flare_interval_max: float = 7.2
@export var random_seed: int = 0

@export_category("Bioluminescence")
@export_range(0.0, 8.0, 0.05) var idle_light_energy: float = 0.85
@export_range(0.0, 12.0, 0.05) var flare_light_energy: float = 2.25
@export_range(0.1, 5.0, 0.05) var flare_light_fade_seconds: float = 1.35

@onready var _spark_burst: GPUParticles2D = %SparkBurst
@onready var _glow_halo: Sprite2D = %GlowHalo
@onready var _light: PointLight2D = %Bioluminescence

var _flare_wait: float = 0.0
var _flare_light_elapsed: float = 0.0
var _flare_active: bool = false
var _elapsed: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_apply_display_scale()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"idle")
	_light.energy = idle_light_energy
	_schedule_next_flare()


func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_update_idle_glow()
	if _consume_stun_frame(delta):
		return

	_update_flare_light(delta)
	if not _flare_active:
		_flare_wait -= delta
		if _flare_wait <= 0.0:
			_start_flare()
	_damage_touching_hylas_if_needed()


func _start_flare() -> void:
	if _flare_active or is_frozen():
		return
	_flare_active = true
	_flare_light_elapsed = 0.0
	_sprite.play(&"flare")
	_spark_burst.emitting = true
	_spark_burst.restart()
	_light.energy = flare_light_energy


func _update_flare_light(delta: float) -> void:
	if _light.energy <= idle_light_energy:
		return
	_flare_light_elapsed += delta
	var progress: float = clampf(
		_flare_light_elapsed / maxf(0.01, flare_light_fade_seconds),
		0.0,
		1.0,
	)
	_light.energy = lerpf(flare_light_energy, idle_light_energy, progress)


func _update_idle_glow() -> void:
	var wave: float = sin(_elapsed * TAU * 0.22)
	_glow_halo.scale = Vector2.ONE * (1.0 + wave * 0.04)
	_glow_halo.modulate.a = 0.38 + wave * 0.06
	if not _flare_active and not is_frozen():
		_light.energy = idle_light_energy * (1.0 + wave * 0.06)


func _on_animation_finished() -> void:
	if _sprite.animation != &"flare":
		return
	_flare_active = false
	_sprite.play(&"idle")
	_schedule_next_flare()


func _schedule_next_flare() -> void:
	_flare_wait = _rng.randf_range(
		minf(flare_interval_min, flare_interval_max),
		maxf(flare_interval_min, flare_interval_max),
	)


func _on_stun_started() -> void:
	_flare_active = false
	_spark_burst.emitting = false
	_light.energy = idle_light_energy * 0.4


func _on_stunned_physics(_delta: float) -> void:
	_light.energy = idle_light_energy * 0.4


func _on_stun_finished() -> void:
	_sprite.play(&"idle")
	_light.energy = idle_light_energy
	_schedule_next_flare()


func _on_distance_sleep() -> void:
	_spark_burst.emitting = false


func _on_distance_wake() -> void:
	if not is_frozen():
		_sprite.play(&"idle")
		_schedule_next_flare()


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_base_sprite_scale = Vector2.ONE * scale_factor
	_sprite.scale = _base_sprite_scale
	_spark_burst.position.y = -display_height * 0.30
	_glow_halo.position.y = -display_height * 0.10
	_light.position.y = -display_height * 0.10
