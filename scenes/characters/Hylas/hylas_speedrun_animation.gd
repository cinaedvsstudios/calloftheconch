extends "res://scenes/characters/Hylas/hylas_ricochet.gd"

## Uses the expanded normal-Hylas Speed Run and swim cycles without changing
## Greatfin. Speed Run is distributed across its gameplay duration; the normal
## swim animation loops once every four seconds.

const NORMAL_SPEEDRUN_FRAME_COUNT: int = 25
const NORMAL_SPEEDRUN_FPS: float = 6.25
const NORMAL_SWIM_FRAME_COUNT: int = 29
const NORMAL_SWIM_FPS: float = 7.25
const NORMAL_SPEEDRUN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/Hylas/speedrun/frame_01.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_02.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_03.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_04.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_05.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_06.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_07.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_08.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_09.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_10.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_11.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_12.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_13.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_14.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_15.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_16.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_17.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_18.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_19.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_20.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_21.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_22.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_23.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_24.webp"),
	preload("res://assets/characters/Hylas/speedrun/frame_25.webp"),
]
const NORMAL_SWIM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/characters/Hylas/swim/frame_01.webp"),
	preload("res://assets/characters/Hylas/swim/frame_02.webp"),
	preload("res://assets/characters/Hylas/swim/frame_03.webp"),
	preload("res://assets/characters/Hylas/swim/frame_04.webp"),
	preload("res://assets/characters/Hylas/swim/frame_05.webp"),
	preload("res://assets/characters/Hylas/swim/frame_06.webp"),
	preload("res://assets/characters/Hylas/swim/frame_07.webp"),
	preload("res://assets/characters/Hylas/swim/frame_08.webp"),
	preload("res://assets/characters/Hylas/swim/frame_09.webp"),
	preload("res://assets/characters/Hylas/swim/frame_10.webp"),
	preload("res://assets/characters/Hylas/swim/frame_11.webp"),
	preload("res://assets/characters/Hylas/swim/frame_12.webp"),
	preload("res://assets/characters/Hylas/swim/frame_13.webp"),
	preload("res://assets/characters/Hylas/swim/frame_14.webp"),
	preload("res://assets/characters/Hylas/swim/frame_15.webp"),
	preload("res://assets/characters/Hylas/swim/frame_16.webp"),
	preload("res://assets/characters/Hylas/swim/frame_17.webp"),
	preload("res://assets/characters/Hylas/swim/frame_18.webp"),
	preload("res://assets/characters/Hylas/swim/frame_19.webp"),
	preload("res://assets/characters/Hylas/swim/frame_20.webp"),
	preload("res://assets/characters/Hylas/swim/frame_21.webp"),
	preload("res://assets/characters/Hylas/swim/frame_22.webp"),
	preload("res://assets/characters/Hylas/swim/frame_23.webp"),
	preload("res://assets/characters/Hylas/swim/frame_24.webp"),
	preload("res://assets/characters/Hylas/swim/frame_25.webp"),
	preload("res://assets/characters/Hylas/swim/frame_26.webp"),
	preload("res://assets/characters/Hylas/swim/frame_27.webp"),
	preload("res://assets/characters/Hylas/swim/frame_28.webp"),
	preload("res://assets/characters/Hylas/swim/frame_29.webp"),
]


func _ready() -> void:
	super._ready()
	_install_normal_speedrun_animation_if_needed()
	_install_normal_swim_animation_if_needed()


func _start_burst(input_direction: Vector2) -> void:
	_install_normal_speedrun_animation_if_needed()
	super._start_burst(input_direction)


func _update_swim(input_direction: Vector2, delta: float) -> void:
	_install_normal_swim_animation_if_needed()
	super._update_swim(input_direction, delta)


func _update_burst_presentation() -> void:
	if not _burst_active or _animated_sprite.animation != &"burst":
		return
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames
	if sprite_frames == null:
		return
	var frame_count: int = sprite_frames.get_frame_count(&"burst")
	if frame_count != NORMAL_SPEEDRUN_FRAME_COUNT:
		super._update_burst_presentation()
		return

	var duration: float = maxf(0.01, speed_run_gameplay_duration)
	var progress: float = clampf(_burst_elapsed / duration, 0.0, 0.999999)
	_animated_sprite.frame = mini(frame_count - 1, floori(progress * float(frame_count)))
	_animated_sprite.pause()


func _install_normal_speedrun_animation_if_needed() -> void:
	if not _uses_normal_hylas_visuals():
		return
	var current_frames: SpriteFrames = _animated_sprite.sprite_frames
	if current_frames == null:
		return
	if current_frames.get_frame_count(&"burst") == NORMAL_SPEEDRUN_FRAME_COUNT:
		current_frames.set_animation_speed(&"burst", NORMAL_SPEEDRUN_FPS)
		current_frames.set_animation_loop(&"burst", false)
		return

	var local_frames: SpriteFrames = current_frames.duplicate(true) as SpriteFrames
	local_frames.resource_local_to_scene = true
	_animated_sprite.sprite_frames = local_frames
	if local_frames.has_animation(&"burst"):
		local_frames.clear(&"burst")
	else:
		local_frames.add_animation(&"burst")
	for texture: Texture2D in NORMAL_SPEEDRUN_TEXTURES:
		local_frames.add_frame(&"burst", texture, 1.0)
	local_frames.set_animation_speed(&"burst", NORMAL_SPEEDRUN_FPS)
	local_frames.set_animation_loop(&"burst", false)


func _install_normal_swim_animation_if_needed() -> void:
	if not _uses_normal_hylas_visuals():
		return
	var current_frames: SpriteFrames = _animated_sprite.sprite_frames
	if current_frames == null:
		return
	if current_frames.get_frame_count(&"swim") == NORMAL_SWIM_FRAME_COUNT:
		current_frames.set_animation_speed(&"swim", NORMAL_SWIM_FPS)
		current_frames.set_animation_loop(&"swim", true)
		return

	var local_frames: SpriteFrames = current_frames.duplicate(true) as SpriteFrames
	local_frames.resource_local_to_scene = true
	_animated_sprite.sprite_frames = local_frames
	if local_frames.has_animation(&"swim"):
		local_frames.clear(&"swim")
	else:
		local_frames.add_animation(&"swim")
	for texture: Texture2D in NORMAL_SWIM_TEXTURES:
		local_frames.add_frame(&"swim", texture, 1.0)
	local_frames.set_animation_speed(&"swim", NORMAL_SWIM_FPS)
	local_frames.set_animation_loop(&"swim", true)


func _uses_normal_hylas_visuals() -> bool:
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(&"idle"):
		return false
	var idle_texture: Texture2D = sprite_frames.get_frame_texture(&"idle", 0)
	if idle_texture == null:
		return false
	return idle_texture.resource_path.contains("/Hylas/idle/")