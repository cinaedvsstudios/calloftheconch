class_name CotcGameplayHud
extends Control

const FIN_STATE_PATHS: Array[String] = [
	"res://assets/ui/hud_fin_state_1.webp",
	"res://assets/ui/hud_fin_state_2.webp",
	"res://assets/ui/hud_fin_state_3.webp",
	"res://assets/ui/hud_fin_state_4.webp",
	"res://assets/ui/hud_fin_state_5.webp",
	"res://assets/ui/hud_fin_state_6.webp",
]
const NORMAL_CONCH_PATH: String = "res://assets/ui/shell_normal_conch.png"

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _load_textures() -> void:
	_fin_state_textures.clear()
	for path: String in FIN_STATE_PATHS:
		var texture: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			texture = ResourceLoader.load(path, "Texture2D") as Texture2D
		_fin_state_textures.append(texture)
	var loaded_panel_count: int = 0
	for texture: Texture2D in _fin_state_textures:
		if texture != null:
			loaded_panel_count += 1
	_fallback_panel.visible = loaded_panel_count == 0
	_panel_texture.visible = loaded_panel_count > 0
	if loaded_panel_count != FIN_STATE_PATHS.size():
		push_warning(
			"Gameplay HUD found %d of %d fin-state panel images. Add hud_fin_state_1.webp through hud_fin_state_6.webp to assets/ui."
			% [loaded_panel_count, FIN_STATE_PATHS.size()]
		)
	if ResourceLoader.exists(NORMAL_CONCH_PATH, "Texture2D"):
		_conch_icon.texture = ResourceLoader.load(NORMAL_CONCH_PATH, "Texture2D") as Texture2D
		_conch_glow.texture = _conch_icon.texture


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
	_panel_texture.show()
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
		"loaded_fin_panels=%d/%d" % [_fin_state_textures.filter(func(texture: Texture2D) -> bool: return texture != null).size(), FIN_STATE_PATHS.size()],
		"conch_icon_loaded=%s" % str(_conch_icon.texture != null),
	]