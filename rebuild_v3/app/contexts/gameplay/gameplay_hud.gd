class_name CotcGameplayHud
extends Control

const ITEM_CATALOG = preload("res://rebuild_v3/app/inventory/item_catalog.gd")

const SLOT_A: StringName = &"item_a"
const SLOT_B: StringName = &"item_b"
const NORMAL_CONCH_ID: StringName = &"normal_conch"
const NORMAL_CONCH_PATH: String = "res://assets/ui/shell_normal_conch.png"
const FIN_STATE_PATHS: Array[String] = [
	"res://assets/ui/UI1.webp",
	"res://assets/ui/UI2.webp",
	"res://assets/ui/UI3.webp",
	"res://assets/ui/UI4.webp",
	"res://assets/ui/UI5.webp",
	"res://assets/ui/UI6.webp",
]
const HUD_DROP_SHADOW_SHADER: Shader = preload(
	"res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader"
)

@export_category("HUD Panel Layout")
@export var hud_source_size_fallback: Vector2 = Vector2(1624.0, 670.0)
@export_range(160.0, 1200.0, 1.0) var hud_layout_width: float = 510.0
@export_range(0.10, 2.0, 0.01) var hud_uniform_scale: float = 0.78
@export_range(0.0, 1.0, 0.01) var hud_horizontal_anchor: float = 0.50
@export_range(-240.0, 600.0, 1.0) var hud_top_offset: float = 4.0

@export_category("HUD Drop Shadow")
@export var hud_shadow_enabled: bool = false
@export var hud_shadow_offset: Vector2 = Vector2(7.0, 10.0)
@export var hud_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export_range(0.0, 10.0, 0.5) var hud_shadow_blur_radius: float = 5.0

@export_category("HUD Element Positions")
@export var onos_value_rect: Rect2 = Rect2(94.0, 120.0, 64.0, 37.0)
@export var fin_value_rect: Rect2 = Rect2(160.0, 120.0, 65.0, 37.0)
# The existing right-hand conch recess is Item A. Keep this property name so
# older scene overrides remain valid.
@export var conch_icon_rect: Rect2 = Rect2(366.0, 65.0, 73.0, 73.0)
@export var item_b_icon_rect: Rect2 = Rect2(255.0, 75.0, 73.0, 80.0)
@export var item_b_quantity_rect: Rect2 = Rect2(298.0, 126.0, 34.0, 27.0)
@export var item_b_empty_rect: Rect2 = Rect2(255.0, 75.0, 73.0, 80.0)
@export var location_value_rect: Rect2 = Rect2(76.0, 167.0, 361.0, 37.0)

@export_category("HUD Text Style")
@export_range(8, 72, 1) var onos_font_size: int = 23
@export_range(8, 72, 1) var fin_font_size: int = 23
@export_range(8, 72, 1) var location_font_size: int = 21
@export_range(8, 48, 1) var item_b_quantity_font_size: int = 18
@export_range(8, 48, 1) var item_b_empty_font_size: int = 27
@export var onos_font_color: Color = Color(1.0, 0.84, 0.35, 1.0)
@export var fin_font_color: Color = Color(0.52, 0.98, 1.0, 1.0)
@export var location_font_color: Color = Color(0.13, 0.12, 0.11, 1.0)
@export var item_b_quantity_font_color: Color = Color(1.0, 0.90, 0.42, 1.0)
@export var item_b_empty_font_color: Color = Color(0.12, 0.24, 0.28, 0.58)
@export var onos_outline_color: Color = Color(0.08, 0.03, 0.0, 1.0)
@export var fin_outline_color: Color = Color(0.0, 0.05, 0.12, 1.0)
@export var location_outline_color: Color = Color(0.84, 0.78, 0.66, 0.85)
@export var item_quantity_outline_color: Color = Color(0.03, 0.02, 0.01, 0.95)
@export_range(0, 16, 1) var number_outline_size: int = 4
@export_range(0, 16, 1) var location_outline_size: int = 2
@export_range(0, 12, 1) var item_quantity_outline_size: int = 3

@export_category("Equipment HUD Pulse")
@export_range(1.0, 2.5, 0.01) var conch_pulse_scale: float = 1.18
@export_range(1.0, 2.5, 0.01) var conch_glow_rest_scale: float = 1.10
@export_range(0.0, 1.0, 0.01) var conch_glow_peak_alpha: float = 0.90
@export_range(0.01, 2.0, 0.01) var conch_pulse_expand_seconds: float = 0.12
@export_range(0.01, 2.0, 0.01) var conch_glow_in_seconds: float = 0.10
@export_range(0.0, 2.0, 0.01) var conch_pulse_return_delay: float = 0.14
@export_range(0.01, 2.0, 0.01) var conch_pulse_return_seconds: float = 0.30
@export_range(0.01, 2.0, 0.01) var conch_glow_out_seconds: float = 0.42
@export var conch_glow_color: Color = Color(0.15, 1.0, 1.0, 1.0)

@onready var _fallback_panel: ColorRect = %FallbackPanel
@onready var _panel_texture: TextureRect = %PanelTexture
@onready var _onos_value: Label = %OnosValue
@onready var _fin_value: Label = %FinValue
@onready var _location_value: Label = %LocationValue
# These two existing nodes are now the live Item A slot.
@onready var _item_a_glow: TextureRect = %ConchGlow
@onready var _item_a_icon: TextureRect = %ConchIcon
@onready var _item_b_glow: TextureRect = %ItemBGlow
@onready var _item_b_icon: TextureRect = %ItemBIcon
@onready var _item_b_quantity: Label = %ItemBQuantity
@onready var _item_b_empty: Label = %ItemBEmpty
@onready var _item_status_countdown: Control = %ItemStatusCountdown

var _tyche_icon: TextureRect
var _tyche_value: Label

var _game_state: CotcGameState
var _fin_state_textures: Array[Texture2D] = []
var _item_a_tween: Tween
var _item_b_tween: Tween
var _location_name: String = "The Sea of Pillars"
var _panel_shadow: TextureRect
var _resolved_source_size: Vector2 = Vector2(1624.0, 670.0)
var _missing_icon_warnings: Dictionary = {}
var _item_b_timed_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_textures()
	_apply_source_layout()
	_apply_element_layout()
	_apply_text_style()
	_create_tyche_display()
	_set_slot_rest_state(_item_a_icon, _item_a_glow)
	_set_slot_rest_state(_item_b_icon, _item_b_glow)
	_sync_from_state()


func bind_game_state(game_state: CotcGameState) -> void:
	_disconnect_game_state()
	_game_state = game_state
	if _game_state != null:
		_game_state.state_replaced.connect(_on_state_replaced)
		_game_state.fins_changed.connect(_on_fins_changed)
		_game_state.greatfin_changed.connect(_on_greatfin_changed)
		_game_state.onos_changed.connect(_on_onos_changed)
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
		_game_state.inventory_changed.connect(_on_inventory_changed)
		_game_state.tyche_changed.connect(_on_tyche_changed)
	_sync_from_state()


func set_location(location_name: String) -> void:
	var resolved_name: String = location_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "The Sea of Pillars"
	_location_name = resolved_name
	_location_value.text = _location_name.to_upper()


func pulse_conch() -> void:
	# Compatibility route for the existing Normal Conch callback.
	pulse_equipment_slot(SLOT_A)


func pulse_equipment_slot(slot_id: StringName) -> void:
	if slot_id == SLOT_A:
		if _item_a_icon.texture == null or not _item_a_icon.visible:
			return
		_item_a_tween = _start_slot_pulse(_item_a_icon, _item_a_glow, _item_a_tween)
		return
	if slot_id == SLOT_B:
		if _item_b_icon.texture == null or not _item_b_icon.visible:
			return
		_item_b_tween = _start_slot_pulse(_item_b_icon, _item_b_glow, _item_b_tween)


func _start_slot_pulse(icon: TextureRect, glow: TextureRect, previous_tween: Tween) -> Tween:
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	_set_slot_rest_state(icon, glow)
	glow.show()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		icon,
		^"scale",
		Vector2.ONE * conch_pulse_scale,
		conch_pulse_expand_seconds,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		glow,
		^"modulate:a",
		conch_glow_peak_alpha,
		conch_glow_in_seconds,
	)
	var icon_return: PropertyTweener = tween.tween_property(
		icon,
		^"scale",
		Vector2.ONE,
		conch_pulse_return_seconds,
	)
	icon_return.set_delay(conch_pulse_return_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var glow_return: PropertyTweener = tween.tween_property(
		glow,
		^"modulate:a",
		0.0,
		conch_glow_out_seconds,
	)
	glow_return.set_delay(conch_pulse_return_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


func _load_textures() -> void:
	_fin_state_textures.clear()
	for path: String in FIN_STATE_PATHS:
		var texture: Texture2D = null
		if ResourceLoader.exists(path, "Texture2D"):
			texture = ResourceLoader.load(path, "Texture2D") as Texture2D
		_fin_state_textures.append(texture)
	_resolved_source_size = _resolve_source_size()
	var loaded_panel_count: int = _get_loaded_panel_count()
	_fallback_panel.visible = loaded_panel_count == 0
	_panel_texture.visible = loaded_panel_count > 0
	if loaded_panel_count != FIN_STATE_PATHS.size():
		push_warning(
			"Gameplay HUD found %d of %d fin-state panel images. Add UI1.webp through UI6.webp to assets/ui."
			% [loaded_panel_count, FIN_STATE_PATHS.size()]
		)
	var default_conch: Texture2D = _load_texture_path(NORMAL_CONCH_PATH, NORMAL_CONCH_ID)
	_item_a_icon.texture = default_conch
	_item_a_glow.texture = default_conch


func _resolve_source_size() -> Vector2:
	for texture: Texture2D in _fin_state_textures:
		if texture == null:
			continue
		var texture_size: Vector2 = texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			return texture_size
	return Vector2(
		maxf(1.0, hud_source_size_fallback.x),
		maxf(1.0, hud_source_size_fallback.y),
	)


func _apply_source_layout() -> void:
	var layout_height: float = hud_layout_width * _resolved_source_size.y / _resolved_source_size.x
	anchor_left = hud_horizontal_anchor
	anchor_right = hud_horizontal_anchor
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -hud_layout_width * 0.5
	offset_top = hud_top_offset
	offset_right = hud_layout_width * 0.5
	offset_bottom = hud_top_offset + layout_height
	scale = Vector2.ONE * hud_uniform_scale
	pivot_offset = Vector2(hud_layout_width * 0.5, 0.0)
	_panel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _apply_element_layout() -> void:
	_apply_control_rect(_onos_value, onos_value_rect)
	_apply_control_rect(_fin_value, fin_value_rect)
	_apply_control_rect(_item_a_glow, conch_icon_rect)
	_apply_control_rect(_item_a_icon, conch_icon_rect)
	_apply_control_rect(_item_b_glow, item_b_icon_rect)
	_apply_control_rect(_item_b_icon, item_b_icon_rect)
	_apply_control_rect(
		_item_status_countdown,
		Rect2(item_b_icon_rect.position + item_b_icon_rect.size * 0.43, item_b_icon_rect.size * 0.57),
	)
	_apply_control_rect(_item_b_quantity, item_b_quantity_rect)
	_apply_control_rect(_item_b_empty, item_b_empty_rect)
	_apply_control_rect(_location_value, location_value_rect)


func set_item_b_timed_active(is_active: bool) -> void:
	if _item_b_timed_active == is_active:
		return
	_item_b_timed_active = is_active
	var target_rect: Rect2 = item_b_icon_rect
	if is_active:
		target_rect = Rect2(item_b_icon_rect.position, item_b_icon_rect.size * 0.52)
	_apply_control_rect(_item_b_glow, target_rect)
	_apply_control_rect(_item_b_icon, target_rect)
	_set_slot_rest_state(_item_b_icon, _item_b_glow)


func _apply_control_rect(control: Control, target_rect: Rect2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = target_rect.position
	control.size = target_rect.size


func _apply_text_style() -> void:
	_onos_value.add_theme_font_size_override(&"font_size", onos_font_size)
	_fin_value.add_theme_font_size_override(&"font_size", fin_font_size)
	_location_value.add_theme_font_size_override(&"font_size", location_font_size)
	_item_b_quantity.add_theme_font_size_override(&"font_size", item_b_quantity_font_size)
	_item_b_empty.add_theme_font_size_override(&"font_size", item_b_empty_font_size)
	_onos_value.add_theme_color_override(&"font_color", onos_font_color)
	_fin_value.add_theme_color_override(&"font_color", fin_font_color)
	_location_value.add_theme_color_override(&"font_color", location_font_color)
	_item_b_quantity.add_theme_color_override(&"font_color", item_b_quantity_font_color)
	_item_b_empty.add_theme_color_override(&"font_color", item_b_empty_font_color)
	_onos_value.add_theme_color_override(&"font_outline_color", onos_outline_color)
	_fin_value.add_theme_color_override(&"font_outline_color", fin_outline_color)
	_location_value.add_theme_color_override(&"font_outline_color", location_outline_color)
	_item_b_quantity.add_theme_color_override(&"font_outline_color", item_quantity_outline_color)
	_onos_value.add_theme_constant_override(&"outline_size", number_outline_size)
	_fin_value.add_theme_constant_override(&"outline_size", number_outline_size)
	_location_value.add_theme_constant_override(&"outline_size", location_outline_size)
	_item_b_quantity.add_theme_constant_override(&"outline_size", item_quantity_outline_size)


func _create_panel_shadow() -> void:
	_panel_shadow = TextureRect.new()
	_panel_shadow.name = "PanelShadow"
	_panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_shadow.offset_left = hud_shadow_offset.x
	_panel_shadow.offset_top = hud_shadow_offset.y
	_panel_shadow.offset_right = hud_shadow_offset.x
	_panel_shadow.offset_bottom = hud_shadow_offset.y
	_panel_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel_shadow.z_index = -4
	var shadow_material: ShaderMaterial = ShaderMaterial.new()
	shadow_material.shader = HUD_DROP_SHADOW_SHADER
	shadow_material.set_shader_parameter(&"shadow_color", hud_shadow_color)
	shadow_material.set_shader_parameter(&"blur_radius", hud_shadow_blur_radius)
	_panel_shadow.material = shadow_material
	add_child(_panel_shadow)
	_panel_shadow.visible = hud_shadow_enabled and _get_loaded_panel_count() > 0


func _get_loaded_panel_count() -> int:
	var loaded_count: int = 0
	for texture: Texture2D in _fin_state_textures:
		if texture != null:
			loaded_count += 1
	return loaded_count


func _create_tyche_display() -> void:
	_tyche_icon = TextureRect.new()
	_tyche_icon.texture = load("res://assets/objects/item_tyche_margarites.png")
	_tyche_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tyche_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tyche_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tyche_icon)
	_apply_control_rect(_tyche_icon, Rect2(onos_value_rect.position + Vector2(-34.0, -10.0), Vector2(28.0, 28.0)))
	_tyche_value = Label.new()
	_tyche_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tyche_value.add_theme_font_size_override(&"font_size", 14)
	_tyche_value.add_theme_color_override(&"font_color", Color.WHITE)
	_tyche_value.add_theme_color_override(&"font_outline_color", onos_outline_color)
	_tyche_value.add_theme_constant_override(&"outline_size", 3)
	add_child(_tyche_value)
	_apply_control_rect(_tyche_value, Rect2(onos_value_rect.position + Vector2(-5.0, -8.0), Vector2(62.0, 25.0)))
	_sync_tyche_display()

func _sync_tyche_display() -> void:
	if not is_instance_valid(_tyche_icon) or not is_instance_valid(_tyche_value): return
	_tyche_icon.visible = _game_state != null and _game_state.tyche_active
	_tyche_value.visible = _tyche_icon.visible
	_tyche_value.text = "+%d" % _game_state.tyche_stored_onos if _tyche_icon.visible else ""

func _sync_from_state() -> void:
	_location_value.text = _location_name.to_upper()
	if _game_state == null:
		_onos_value.text = "0"
		_fin_value.text = "4"
		_set_fin_panel(0)
		_set_equipment_slot(SLOT_A, NORMAL_CONCH_ID)
		_set_equipment_slot(SLOT_B, &"")
		return
	_onos_value.text = str(_game_state.onos)
	_fin_value.text = str(_game_state.current_fins)
	_set_fin_panel(_resolve_fin_panel_index())
	_sync_equipment_from_state()
	_sync_tyche_display()


func _sync_equipment_from_state() -> void:
	var item_a: StringName = NORMAL_CONCH_ID
	var item_b: StringName = &""
	if _game_state != null:
		item_a = _game_state.get_equipped_item(SLOT_A)
		item_b = _game_state.get_equipped_item(SLOT_B)
	if String(item_a).is_empty():
		item_a = NORMAL_CONCH_ID
	_set_equipment_slot(SLOT_A, item_a)
	_set_equipment_slot(SLOT_B, item_b)


func _set_equipment_slot(slot_id: StringName, item_id: StringName) -> void:
	var icon: TextureRect = _item_a_icon if slot_id == SLOT_A else _item_b_icon
	var glow: TextureRect = _item_a_glow if slot_id == SLOT_A else _item_b_glow
	var is_empty: bool = String(item_id).is_empty()
	var texture: Texture2D = null
	if not is_empty:
		texture = _load_catalog_item_texture(item_id)
	if texture == null and slot_id == SLOT_A:
		item_id = NORMAL_CONCH_ID
		texture = _load_texture_path(NORMAL_CONCH_PATH, NORMAL_CONCH_ID)

	icon.texture = texture
	glow.texture = texture
	icon.visible = texture != null
	glow.visible = texture != null
	_set_slot_rest_state(icon, glow)

	if slot_id != SLOT_B:
		return

	_item_b_empty.visible = is_empty or texture == null
	_item_b_empty.text = "—" if is_empty else "?"
	_item_b_quantity.hide()
	_item_b_quantity.text = ""
	if (
			not is_empty
			and texture != null
			and _game_state != null
			and ITEM_CATALOG.item_has_quantity(item_id)
		):
		var quantity: int = _game_state.get_inventory_quantity(item_id)
		if quantity > 0:
			_item_b_quantity.text = str(quantity)
			_item_b_quantity.show()


func _load_catalog_item_texture(item_id: StringName) -> Texture2D:
	if not ITEM_CATALOG.has_item(item_id):
		_warn_missing_icon(item_id, "catalogue entry")
		return null
	var definition: Dictionary = ITEM_CATALOG.get_item(item_id)
	var icon_path: String = str(definition.get("icon_path", ""))
	if icon_path.is_empty():
		_warn_missing_icon(item_id, "icon path")
		return null
	return _load_texture_path(icon_path, item_id)


func _load_texture_path(path: String, item_id: StringName) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		_warn_missing_icon(item_id, path)
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D


func _warn_missing_icon(item_id: StringName, detail: String) -> void:
	var key: String = "%s|%s" % [String(item_id), detail]
	if _missing_icon_warnings.has(key):
		return
	_missing_icon_warnings[key] = true
	push_warning("Gameplay HUD could not load the icon for '%s' from '%s'." % [String(item_id), detail])


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


func _set_slot_rest_state(icon: TextureRect, glow: TextureRect) -> void:
	icon.scale = Vector2.ONE
	icon.pivot_offset = icon.size * 0.5
	glow.scale = Vector2.ONE * conch_glow_rest_scale
	glow.pivot_offset = glow.size * 0.5
	glow.modulate = Color(conch_glow_color.r, conch_glow_color.g, conch_glow_color.b, 0.0)


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
	if _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)
	if _game_state.inventory_changed.is_connected(_on_inventory_changed):
		_game_state.inventory_changed.disconnect(_on_inventory_changed)
	if _game_state.tyche_changed.is_connected(_on_tyche_changed):
		_game_state.tyche_changed.disconnect(_on_tyche_changed)


func _on_state_replaced(_reason: StringName) -> void:
	_sync_from_state()


func _on_fins_changed(_current_value: int, _maximum_value: int, _delta: int) -> void:
	_sync_from_state()


func _on_greatfin_changed(_is_active: bool) -> void:
	_sync_from_state()


func _on_onos_changed(_current_value: int, _delta: int) -> void:
	_sync_from_state()


func _on_equipped_item_changed(_slot_id: StringName, _item_id: StringName) -> void:
	_sync_equipment_from_state()


func _on_tyche_changed(_active: bool, _stored_value: int) -> void:
	_sync_tyche_display()

func _on_inventory_changed(
		_item_id: StringName,
		_quantity: int,
		_delta: int,
	) -> void:
	_sync_equipment_from_state()


func get_debug_lines() -> Array[String]:
	var equipped_a: StringName = NORMAL_CONCH_ID
	var equipped_b: StringName = &""
	if _game_state != null:
		equipped_a = _game_state.get_equipped_item(SLOT_A)
		equipped_b = _game_state.get_equipped_item(SLOT_B)
	return [
		"[GameplayHud]",
		"location=%s" % _location_name,
		"loaded_fin_panels=%d/%d" % [_get_loaded_panel_count(), FIN_STATE_PATHS.size()],
		"equipped_item_a=%s" % String(equipped_a),
		"equipped_item_b=%s" % String(equipped_b),
		"item_a_icon_loaded=%s" % str(_item_a_icon.texture != null),
		"item_b_icon_loaded=%s" % str(_item_b_icon.texture != null),
		"item_b_quantity=%s" % _item_b_quantity.text,
		"source_size=%s" % str(_resolved_source_size),
		"layout_width=%.1f" % hud_layout_width,
		"uniform_scale=%.2f" % hud_uniform_scale,
		"drop_shadow_enabled=%s" % str(hud_shadow_enabled),
	]
