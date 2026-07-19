class_name CotcDepthGlowPlant
extends Node2D

## Passive two-frame depth plant with a slow, local bioluminescent breathing glow.

@export_category("Display")
@export_range(40.0, 600.0, 1.0) var display_height: float = 220.0
@export_range(0.0, 0.12, 0.005) var visual_pulse_amount: float = 0.025

@export_category("Bioluminescence")
@export_range(0.0, 8.0, 0.05) var base_light_energy: float = 1.25
@export_range(0.01, 2.0, 0.01) var pulse_cycles_per_second: float = 0.18

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _glow_halo: Sprite2D = %GlowHalo
@onready var _light: PointLight2D = %Bioluminescence

var _elapsed: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _distance_active: bool = true


func _ready() -> void:
	_apply_display_scale()
	_sprite.play(&"idle")
	_light.energy = base_light_energy


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	var wave: float = sin(_elapsed * TAU * pulse_cycles_per_second)
	_sprite.scale = _base_sprite_scale * (1.0 + wave * visual_pulse_amount)
	_glow_halo.scale = Vector2.ONE * (1.0 + wave * 0.08)
	_glow_halo.modulate.a = 0.44 + wave * 0.08
	_light.energy = base_light_energy * (1.0 + wave * 0.12)


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_process(_distance_active)
	if _distance_active:
		_sprite.play(&"idle")
	else:
		_sprite.pause()


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_base_sprite_scale = Vector2.ONE * scale_factor
	_sprite.scale = _base_sprite_scale
