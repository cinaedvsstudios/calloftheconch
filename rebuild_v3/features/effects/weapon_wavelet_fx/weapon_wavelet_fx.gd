class_name CotcWeaponWaveletFX
extends CanvasLayer

@onready var _back_buffer_copy: BackBufferCopy = %BackBufferCopy
@onready var _wavelet_rect: ColorRect = %WaveletRect

var _wavelet_material: ShaderMaterial
var _wavelet_tween: Tween
var _world_position: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	var source_material: ShaderMaterial = _wavelet_rect.material as ShaderMaterial
	if source_material == null:
		push_error("WeaponWaveletFX requires a ShaderMaterial on WaveletRect.")
		set_process(false)
		return
	_wavelet_material = source_material.duplicate(true) as ShaderMaterial
	_wavelet_rect.material = _wavelet_material
	stop_wavelet()


func _process(_delta: float) -> void:
	if _active:
		_sync_screen_rect()


func play_wavelet(
		world_position: Vector2,
		diameter: float,
		deformation_length: float,
		thickness: float,
		wavelet_factor: float,
		duration: float,
	) -> void:
	if _wavelet_material == null:
		return
	stop_wavelet()
	_world_position = world_position
	_wavelet_rect.size = Vector2.ONE * maxf(32.0, diameter * 2.25)
	_wavelet_material.set_shader_parameter(&"progression", 0.0)
	_wavelet_material.set_shader_parameter(&"fade", 0.84)
	_wavelet_material.set_shader_parameter(&"opacity", 0.4)
	_wavelet_material.set_shader_parameter(
		&"deformation_length",
		maxf(16.0, deformation_length),
	)
	_wavelet_material.set_shader_parameter(&"thickness", clampf(thickness, 0.01, 1.0))
	_wavelet_material.set_shader_parameter(&"wavelet_factor", clampf(wavelet_factor, 0.1, 4.0))
	_active = true
	_back_buffer_copy.show()
	_wavelet_rect.show()
	set_process(true)
	_sync_screen_rect()

	_wavelet_tween = create_tween()
	_wavelet_tween.tween_method(
		_set_progression,
		0.0,
		1.0,
		maxf(0.05, duration * 2.0),
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_wavelet_tween.finished.connect(stop_wavelet)


func stop_wavelet() -> void:
	if _wavelet_tween != null and _wavelet_tween.is_valid():
		_wavelet_tween.kill()
	_wavelet_tween = null
	_active = false
	if is_instance_valid(_back_buffer_copy):
		_back_buffer_copy.hide()
	if is_instance_valid(_wavelet_rect):
		_wavelet_rect.hide()
	set_process(false)


func _set_progression(value: float) -> void:
	if _wavelet_material != null:
		_wavelet_material.set_shader_parameter(&"progression", value)


func _sync_screen_rect() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null or _wavelet_material == null:
		return
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_center: Vector2 = viewport.get_canvas_transform() * _world_position
	_wavelet_rect.position = screen_center - (_wavelet_rect.size * 0.5)
	var target_rect: Rect2 = _wavelet_rect.get_global_rect()
	_wavelet_material.set_shader_parameter(
		&"screen_pos",
		target_rect.position / viewport_size,
	)
	_wavelet_material.set_shader_parameter(
		&"screen_size",
		target_rect.size / viewport_size,
	)
