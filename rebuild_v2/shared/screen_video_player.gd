class_name ScreenVideoPlayer
extends VideoStreamPlayer

const SCREEN_BLEND_SHADER: Shader = preload("res://rebuild_v2/features/sea_of_pillars_v2/bubble_screen_blend.gdshader")

@export var effect_loops: bool = false
@export var start_on_ready: bool = false


func _ready() -> void:
	configure_effect(self, effect_loops)
	if start_on_ready and stream != null:
		play()


static func configure_effect(player: VideoStreamPlayer, should_loop: bool = false) -> void:
	if player == null:
		return
	var screen_material: ShaderMaterial = ShaderMaterial.new()
	screen_material.shader = SCREEN_BLEND_SHADER
	player.material = screen_material
	player.loop = should_loop
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
