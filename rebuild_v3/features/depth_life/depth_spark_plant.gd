class_name CotcDepthSparkPlant
extends CotcDepthStunnableEnemy

## Stationary dark-depth plant. Frames 01-03 form the normal loop. Every
## discharge interval it holds frame 04 while emitting real Area2D sparks from
## the upper third of the plant. Only the sparks deal contact damage.

const SPARK_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/depth_life/depth_spark_projectile.tscn"
)
const SPARK_COLOURS: Array[Color] = [
	Color(1.0, 0.16, 0.48, 1.0),
	Color(1.0, 0.38, 0.08, 1.0),
	Color(0.96, 0.06, 0.08, 1.0),
]

@export_category("Display")
@export_range(80.0, 700.0, 1.0) var display_height: float = 280.0

@export_category("Spark Discharge")
@export_range(2.0, 60.0, 0.5) var discharge_interval: float = 18.0
@export_range(0.2, 4.0, 0.05) var discharge_frame_duration: float = 1.0
@export_range(0.1, 3.0, 0.05) var spark_emission_duration: float = 0.8
@export_range(1, 80, 1) var spark_count: int = 22
@export_range(0.0, 300.0, 1.0) var spark_emitter_width: float = 110.0
@export_range(1.0, 15.0, 0.1) var spark_lifetime: float = 6.5
@export_range(10.0, 500.0, 1.0) var spark_horizontal_speed_min: float = 85.0
@export_range(10.0, 500.0, 1.0) var spark_horizontal_speed_max: float = 190.0
@export_range(0.0, 400.0, 1.0) var spark_upward_speed_min: float = 65.0
@export_range(0.0, 400.0, 1.0) var spark_upward_speed_max: float = 145.0
@export_range(0.2, 3.0, 0.05) var spark_scale_min: float = 0.75
@export_range(0.2, 3.0, 0.05) var spark_scale_max: float = 1.35

@export_category("Deep Blue Glow")
@export_range(0.0, 8.0, 0.05) var blue_light_energy: float = 1.25
@export_range(0.01, 2.0, 0.01) var blue_pulse_cycles_per_second: float = 0.16
@export_range(0.0, 0.5, 0.01) var blue_pulse_amount: float = 0.14

@export_category("Pink Crown Glow")
@export_range(0.0, 8.0, 0.05) var pink_light_energy: float = 0.9
@export_range(0.01, 2.0, 0.01) var pink_pulse_cycles_per_second: float = 0.23
@export_range(0.0, 0.5, 0.01) var pink_pulse_amount: float = 0.18

@onready var _spark_emitter: Marker2D = %SparkEmitter
@onready var _spark_container: Node2D = %SparkContainer
@onready var _blue_halo: Sprite2D = %DeepBlueHalo
@onready var _pink_halo: Sprite2D = %PinkHalo
@onready var _blue_light: PointLight2D = %DeepBlueLight
@onready var _pink_light: PointLight2D = %PinkLight

var _rng := RandomNumberGenerator.new()
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_blue_halo_scale: Vector2 = Vector2.ONE
var _base_pink_halo_scale: Vector2 = Vector2.ONE
var _elapsed: float = 0.0
var _discharge_wait: float = 18.0
var _discharge_elapsed: float = 0.0
var _emitted_sparks: int = 0
var _discharging: bool = false


func _ready() -> void:
	super._ready()
	_rng.seed = hash(str(get_path()))
	_apply_display_scale()
	_base_blue_halo_scale = _blue_halo.scale
	_base_pink_halo_scale = _pink_halo.scale
	_blue_light.energy = blue_light_energy
	_pink_light.energy = pink_light_energy
	_discharge_wait = discharge_interval
	_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_update_glows()
	if _consume_stun_frame(delta):
		return

	if _discharging:
		_update_discharge(delta)
		return

	_discharge_wait -= delta
	if _discharge_wait <= 0.0:
		_start_discharge()


func _start_discharge() -> void:
	_discharging = true
	_discharge_elapsed = 0.0
	_emitted_sparks = 0
	_sprite.animation = &"discharge"
	_sprite.frame = 0
	_sprite.pause()


func _update_discharge(delta: float) -> void:
	_discharge_elapsed += maxf(0.0, delta)
	var emission_progress: float = clampf(
		_discharge_elapsed / maxf(0.01, spark_emission_duration),
		0.0,
		1.0,
	)
	var target_emitted: int = mini(spark_count, floori(emission_progress * float(spark_count)))
	while _emitted_sparks < target_emitted:
		_spawn_spark()
		_emitted_sparks += 1

	if _discharge_elapsed < discharge_frame_duration:
		return
	while _emitted_sparks < spark_count:
		_spawn_spark()
		_emitted_sparks += 1
	_finish_discharge()


func _finish_discharge() -> void:
	_discharging = false
	_discharge_elapsed = 0.0
	_emitted_sparks = 0
	_discharge_wait = maxf(0.1, discharge_interval - discharge_frame_duration)
	_sprite.play(&"idle")


func _spawn_spark() -> void:
	var spark: CotcDepthSparkProjectile = SPARK_SCENE.instantiate() as CotcDepthSparkProjectile
	if spark == null:
		return
	_spark_container.add_child(spark)
	var local_offset := Vector2(
		_rng.randf_range(-spark_emitter_width * 0.5, spark_emitter_width * 0.5),
		_rng.randf_range(-12.0, 12.0),
	)
	spark.global_position = _spark_emitter.global_position + local_offset

	var outward_sign: float = -1.0 if local_offset.x < 0.0 else 1.0
	if absf(local_offset.x) < 8.0:
		outward_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	var horizontal_speed: float = _rng.randf_range(
		minf(spark_horizontal_speed_min, spark_horizontal_speed_max),
		maxf(spark_horizontal_speed_min, spark_horizontal_speed_max),
	)
	var upward_speed: float = _rng.randf_range(
		minf(spark_upward_speed_min, spark_upward_speed_max),
		maxf(spark_upward_speed_min, spark_upward_speed_max),
	)
	var colour: Color = SPARK_COLOURS[_rng.randi_range(0, SPARK_COLOURS.size() - 1)]
	var visual_scale: float = _rng.randf_range(
		minf(spark_scale_min, spark_scale_max),
		maxf(spark_scale_min, spark_scale_max),
	)
	spark.configure(
		Vector2(outward_sign * horizontal_speed, -upward_speed),
		spark_lifetime,
		colour,
		_rng.randf(),
		visual_scale,
	)
	spark.hylas_touched.connect(_on_spark_hylas_touched)


func _on_spark_hylas_touched(hylas: Node2D) -> void:
	if not is_instance_valid(hylas):
		return
	damage_requested.emit(hylas, damage_amount)


func _update_glows() -> void:
	var blue_wave: float = sin(_elapsed * TAU * blue_pulse_cycles_per_second)
	var pink_wave: float = sin(
		_elapsed * TAU * pink_pulse_cycles_per_second + PI * 0.35
	)
	var blue_factor: float = 1.0 + blue_wave * blue_pulse_amount
	var pink_factor: float = 1.0 + pink_wave * pink_pulse_amount

	_blue_halo.scale = _base_blue_halo_scale * blue_factor
	_blue_halo.modulate.a = 0.38 + blue_wave * 0.09
	_blue_light.energy = blue_light_energy * (1.0 + blue_wave * 0.16)

	_pink_halo.scale = _base_pink_halo_scale * pink_factor
	_pink_halo.modulate.a = 0.46 + pink_wave * 0.12
	_pink_light.energy = pink_light_energy * (1.0 + pink_wave * 0.2)


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_base_sprite_scale = Vector2.ONE * scale_factor
	_sprite.scale = _base_sprite_scale


func _on_stun_finished() -> void:
	if _discharging:
		_sprite.animation = &"discharge"
		_sprite.frame = 0
		_sprite.pause()
	else:
		_sprite.play(&"idle")


func _on_distance_sleep() -> void:
	_sprite.pause()


func _on_distance_wake() -> void:
	if is_frozen():
		return
	if _discharging:
		_sprite.animation = &"discharge"
		_sprite.frame = 0
		_sprite.pause()
	else:
		_sprite.play(&"idle")
