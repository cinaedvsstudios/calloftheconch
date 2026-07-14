@tool
extends Node

const PANEL_TEXTURE: Texture2D = preload("res://assets/ui/UI1.webp")
const CONCH_TEXTURE: Texture2D = preload("res://assets/ui/shell_normal_conch.png")
const SHADOW_SHADER: Shader = preload(
	"res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader"
)

@export_category("Editor Preview")
@export var preview_onos: int = 12
@export var preview_fins: int = 4
@export var preview_location: String = "THE SEA OF PILLARS"
@export_range(0.0, 1.0, 0.01) var preview_conch_glow_alpha: float = 0.32

var _panel_shadow: TextureRect


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_refresh_preview()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_preview()


func _refresh_preview() -> void:
	var hud: Control = get_parent() as Control
	if hud == null:
		return
	var panel: TextureRect = hud.get_node_or_null("PanelTexture") as TextureRect
	var fallback: ColorRect = hud.get_node_or_null("FallbackPanel") as ColorRect
	var onos: Label = hud.get_node_or_null("OnosValue") as Label
	var fins: Label = hud.get_node_or_null("FinValue") as Label
	var location: Label = hud.get_node_or_null("LocationValue") as Label
	var conch_icon: TextureRect = hud.get_node_or_null("ConchIcon") as TextureRect
	var conch_glow: TextureRect = hud.get_node_or_null("ConchGlow") as TextureRect
	if panel == null or onos == null or fins == null or location == null or conch_icon == null or conch_glow == null:
		return

	var source_size: Vector2 = PANEL_TEXTURE.get_size()
	var layout_width: float = float(hud.get("hud_layout_width"))
	var layout_height: float = layout_width * source_size.y / maxf(1.0, source_size.x)
	var horizontal_anchor: float = float(hud.get("hud_horizontal_anchor"))
	var top_offset: float = float(hud.get("hud_top_offset"))
	var uniform_scale: float = float(hud.get("hud_uniform_scale"))
	hud.anchor_left = horizontal_anchor
	hud.anchor_right = horizontal_anchor
	hud.anchor_top = 0.0
	hud.anchor_bottom = 0.0
	hud.offset_left = -layout_width * 0.5
	hud.offset_top = top_offset
	hud.offset_right = layout_width * 0.5
	hud.offset_bottom = top_offset + layout_height
	hud.scale = Vector2.ONE * uniform_scale
	hud.pivot_offset = Vector2(layout_width * 0.5, 0.0)

	panel.texture = PANEL_TEXTURE
	panel.visible = true
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if fallback != null:
		fallback.visible = false

	_apply_rect(onos, hud.get("onos_value_rect") as Rect2)
	_apply_rect(fins, hud.get("fin_value_rect") as Rect2)
	_apply_rect(conch_glow, hud.get("conch_icon_rect") as Rect2)
	_apply_rect(conch_icon, hud.get("conch_icon_rect") as Rect2)
	_apply_rect(location, hud.get("location_value_rect") as Rect2)

	onos.text = str(preview_onos)
	fins.text = str(preview_fins)
	location.text = preview_location
	onos.add_theme_font_size_override(&"font_size", int(hud.get("onos_font_size")))
	fins.add_theme_font_size_override(&"font_size", int(hud.get("fin_font_size")))
	location.add_theme_font_size_override(&"font_size", int(hud.get("location_font_size")))
	onos.add_theme_color_override(&"font_color", hud.get("onos_font_color") as Color)
	fins.add_theme_color_override(&"font_color", hud.get("fin_font_color") as Color)
	location.add_theme_color_override(&"font_color", hud.get("location_font_color") as Color)
	onos.add_theme_color_override(&"font_outline_color", hud.get("onos_outline_color") as Color)
	fins.add_theme_color_override(&"font_outline_color", hud.get("fin_outline_color") as Color)
	location.add_theme_color_override(&"font_outline_color", hud.get("location_outline_color") as Color)
	onos.add_theme_constant_override(&"outline_size", int(hud.get("number_outline_size")))
	fins.add_theme_constant_override(&"outline_size", int(hud.get("number_outline_size")))
	location.add_theme_constant_override(&"outline_size", int(hud.get("location_outline_size")))

	conch_icon.texture = CONCH_TEXTURE
	conch_glow.texture = CONCH_TEXTURE
	conch_icon.pivot_offset = conch_icon.size * 0.5
	conch_glow.pivot_offset = conch_glow.size * 0.5
	conch_glow.scale = Vector2.ONE * float(hud.get("conch_glow_rest_scale"))
	var glow_color: Color = hud.get("conch_glow_color") as Color
	conch_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, preview_conch_glow_alpha)
	conch_glow.visible = true

	_ensure_shadow(hud, panel)
	_update_shadow(hud)


func _apply_rect(control: Control, target_rect: Rect2) -> void:
	control.position = target_rect.position
	control.size = target_rect.size


func _ensure_shadow(hud: Control, panel: TextureRect) -> void:
	if is_instance_valid(_panel_shadow):
		return
	_panel_shadow = TextureRect.new()
	_panel_shadow.name = "__EditorPanelShadow"
	_panel_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_panel_shadow.texture = PANEL_TEXTURE
	_panel_shadow.z_index = -4
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADOW_SHADER
	_panel_shadow.material = material
	hud.add_child(_panel_shadow)
	var panel_index: int = panel.get_index()
	hud.move_child(_panel_shadow, maxi(0, panel_index))


func _update_shadow(hud: Control) -> void:
	if not is_instance_valid(_panel_shadow):
		return
	var shadow_offset: Vector2 = hud.get("hud_shadow_offset") as Vector2
	_panel_shadow.offset_left = shadow_offset.x
	_panel_shadow.offset_top = shadow_offset.y
	_panel_shadow.offset_right = shadow_offset.x
	_panel_shadow.offset_bottom = shadow_offset.y
	_panel_shadow.visible = bool(hud.get("hud_shadow_enabled"))
	var material: ShaderMaterial = _panel_shadow.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"shadow_color", hud.get("hud_shadow_color") as Color)
		material.set_shader_parameter(&"blur_radius", float(hud.get("hud_shadow_blur_radius")))
