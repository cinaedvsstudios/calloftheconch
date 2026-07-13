class_name CotcGameplayHud
extends Control

const FIN_STATE_PATHS: Array[String] = [
	"res://assets/ui/UI1.webp",
	"res://assets/ui/UI2.webp",
	"res://assets/ui/UI3.webp",
	"res://assets/ui/UI4.webp",
	"res://assets/ui/UI5.webp",
	"res://assets/ui/UI6.webp",
]
const NORMAL_CONCH_PATH: String = "res://assets/ui/shell_normal_conch.png"
const HUD_DROP_SHADOW_SHADER: Shader = preload(
	"res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader"
)
const HUD_SOURCE_SIZE: Vector2 = Vector2(1624.0, 670.0)
const HUD_LAYOUT_WIDTH: float = 510.0
const HUD_DISPLAY_SCALE: float = 0.78
const HUD_TOP_OFFSET: float = 4.0

@onready var _fallback_panel: ColorRect = %FallbackPanel
@onready var _panel_texture: TextureRect = %PanelTexture
@onready var _onos_value: Label = %OnosValue
@onready var _fin_value: Label = %FinValue
@onready var _location_value: Label = %LocationValue
@onready var _conch_glow: TextureRect = %ConchGlow
@onready var _conch_icon: TextureRect = %ConchIcon

var _game_state: CotcGameState
var _fin_state_textures: Array[Texture2D] = []
var _conch_tween: Tween
var _location_name: String = "The Sea of Pillars"
var _panel_shadow: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_source_layout()
	_create_panel_shadow()
	_load_textures()
	_set_conch_rest_state()
	_sync_from_state()


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_game_state()
	_game_state = game_state
	if _game_state != null:
		_game_state.state_replaced.connect(_on_state_replaced)
		_game_state.fins_changed.connect(_on_fins_changed)
		_game_state.greatfin_changed.connect(_on_greatfin_changed)
		_game_state.onos_changed.connect(_on_onos_changed)
	_sync_from_state()


func set_location(location_name: String) -> void:
	var resolved_name: String = location_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "The Sea of Pillars"
	_location_name = resolved_name
	_location_value.text = _location_name.to_upper()


func pulse_conch() -> void:
	if _conch_tween != null and _conch_tween.is_valid():
		_conch_tween.kill()
	_set_conch_rest_state()
	_conch_glow.show()
	_conch_tween = create_tween()
	_conch_tween.set_parallel(true)
	_conch_tween.tween_property(_conch_icon, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_conch_tween.tween_property(_conch_glow, "modulate:a", 0.90, 0.10)
	var icon_return: PropertyTweener = _conch_tween.tween_property(_conch_icon, "scale", Vector2.ONE, 0.30)
	icon_return.set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var glow_return: PropertyTweener = _conch_tween.tween_property(_conch_glow, "modulate:a", 0.0, 0.42)
	glow_return.set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_source_layout() -> void:
	var layout_height: float = HUD_LAYOUT_WIDTH * HUD_SOURCE_SIZE.y / HUD_SOURCE_SIZE.x
	offset_left = -HUD_LAYOUT_WIDTH * 0.5
	offset_top = HUD_TOP_OFFSET
	offset_right = HUD_LAYOUT_WIDTH * 0.5
	offset_bottom = HUD_TOP_OFFSET + layout_height
	scale = Vector2.ONE * HUD_DISPLAY_SCALE
	pivot_offset = Vector2(HUD_LAYOUT_WIDTH * 0.5, 0.0)
	_panel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _create_panel_shadow() -> void:
	_panel_shadow = TextureRect.new()
	_panel_shadow.name = "PanelShadow"
	_panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_shadow.offset_left = 7.0
	_panel_shadow.offset_top = 10.0
	_panel_shadow.offset_right = 7.0
	_panel_shadow.offset_bottom = 10.0
	_panel_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel_shadow.z_index = -4
	var shadow_material: ShaderMaterial = ShaderMaterial.new()
	shadow_material.shader = HUD_DROP_SHADOW_SHADER
	_panel_shadow.material = shadow_material
	add_child(_panel_shadow)
	_panel_shadow.hide()


func _load_textures() -> void:
	_fin_state_textures.clear()
	for path: String in FIN_STATE_PATHS:
		var texture: Texture2D = null
		if ResourceLoader.exists(path, "Texture2D"):
			texture = ResourceLoader.load(path, "Texture2D") as Texture2D
		_fin_state_textures.append(texture)
	var loaded_panel_count: int = _get_loaded_panel_count()
	_fallback_panel.visible = loaded_panel_count == 0
	_panel_texture.visible = loaded_panel_count > 0
	if loaded_panel_count == 0:
		_panel_shadow.hide()
	if loaded_panel_count != FIN_STATE_PATHS.size():
		push_warning(
			"Gameplay HUD found %d of %d fin-state panel images. Add UI1.webp through UI6.webp to assets/ui."
			% [loaded_panel_count, FIN_STATE_PATHS.size()]
		)
	if ResourceLoader.exists(NORMAL_CONCH_PATH, "Texture2D"):
		_conch_icon.texture = ResourceLoader.load(NORMAL_CONCH_PATH, "Texture2D") as Texture2D
		_conch_glow.texture = _conch_icon.texture


func _get_loaded_panel_count() -> int:
	var loaded_count: int = 0
	for texture: Texture2D in _fin_state_textures:
		if texture != null:
			loaded_count += 1
	return loaded_count


func _sync_from_state() -> void:
	_location_value.text = _location_name.to_upper()
	if _game_state == null:
		_onos_value.text = "0"
		_fin_value.text = "4"
		_set_fin_panel(0)
		return
	_onos_value.text = str(_game_state.onos)
	_fin_value.text = str(_game_state.current_fins)
	_set_fin_panel(_resolve_fin_panel_index())


func _resolve_fin_panel_index() -> int:
	if _game_state == null:
		return 0
	if _game_state.greatfin_active:
		return 5
	match _game_state.current_fins:
		0:
			return 4
		1:
			return 3
		2:
			return 2
		3:
			return 1
		_:
			return 0


func _set_fin_panel(panel_index: int) -> void:
	if panel_index < 0 or panel_index >= _fin_state_textures.size():
		return
	var texture: Texture2D = _fin_state_textures[panel_index]
	if texture == null:
		return
	_panel_texture.texture = texture
	_panel_shadow.texture = texture
	_panel_texture.show()
	_panel_shadow.show()
	_fallback_panel.hide()


func _set_conch_rest_state() -> void:
	_conch_icon.scale = Vector2.ONE
	_conch_icon.pivot_offset = _conch_icon.size * 0.5
	_conch_glow.scale = Vector2.ONE * 1.10
	_conch_glow.pivot_offset = _conch_glow.size * 0.5
	_conch_glow.modulate = Color(0.15, 1.0, 1.0, 0.0)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.state_replaced.is_connected(_on_state_replaced):
		_game_state.state_replaced.disconnect(_on_state_replaced)
	if _game_state.fins_changed.is_connected(_on_fins_changed):
		_game_state.fins_changed.disconnect(_on_fins_changed)
	if _game_state.greatfin_changed.is_connected(_on_greatfin_changed):
		_game_state.greatfin_changed.disconnect(_on_greatfin_changed)
	if _game_state.onos_changed.is_connected(_on_onos_changed):
		_game_state.onos_changed.disconnect(_on_onos_changed)


func _on_state_replaced(_reason: StringName) -> void:
	_sync_from_state()


func _on_fins_changed(_current_value: int, _maximum_value: int, _delta: int) -> void:
	_sync_from_state()


func _on_greatfin_changed(_is_active: bool) -> void:
	_sync_from_state()


func _on_onos_changed(_current_value: int, _delta: int) -> void:
	_sync_from_state()


func get_debug_lines() -> Array[String]:
	return [
		"[GameplayHud]",
		"location=%s" % _location_name,
		"loaded_fin_panels=%d/%d" % [_get_loaded_panel_count(), FIN_STATE_PATHS.size()],
		"conch_icon_loaded=%s" % str(_conch_icon.texture != null),
		"source_aspect=%.5f" % (HUD_SOURCE_SIZE.x / HUD_SOURCE_SIZE.y),
		"drop_shadow_loaded=%s" % str(_panel_shadow != null),
	]
