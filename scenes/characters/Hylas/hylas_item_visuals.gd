class_name CotcHylasItemVisuals
extends Node2D

const CAMOUFLAGE_SHADER: Shader = preload(
	"res://scenes/characters/Hylas/hylas_camouflage.gdshader"
)
const SURGE_GLOW_SHADER: Shader = preload(
	"res://scenes/characters/Hylas/hylas_item_glow.gdshader"
)
const SHELL_TEXTURES: Dictionary = {
	&"normal_conch": preload("res://assets/characters/shell_normal_conch.png"),
	&"charonia_tritonis": preload("res://assets/characters/shell_charonia_tritonis.png"),
	&"terebridae": preload("res://assets/characters/shell_terebridae.png"),
	&"conus_textile": preload("res://assets/characters/shell_conus_textile.png"),
}

@onready var _hylas: Node2D = get_parent() as Node2D
@onready var _animated_sprite: AnimatedSprite2D = get_parent().get_node_or_null("AnimatedSprite") as AnimatedSprite2D
@onready var _shell_overlay: Sprite2D = %EquippedShellOverlay

var _equipped_item_a: StringName = &"normal_conch"
var _camouflage_active: bool = false
var _surge_glow_active: bool = false
var _base_sprite_material: Material
var _camouflage_material: ShaderMaterial
var _surge_glow_material: ShaderMaterial


func _ready() -> void:
	if _animated_sprite == null:
		push_error("Hylas ItemVisuals requires the sibling AnimatedSprite node.")
		set_process(false)
		return
	_base_sprite_material = _animated_sprite.material
	_camouflage_material = ShaderMaterial.new()
	_camouflage_material.shader = CAMOUFLAGE_SHADER
	_camouflage_material.resource_local_to_scene = true
	_surge_glow_material = ShaderMaterial.new()
	_surge_glow_material.shader = SURGE_GLOW_SHADER
	_surge_glow_material.resource_local_to_scene = true
	_shell_overlay.texture_filter = _animated_sprite.texture_filter
	_shell_overlay.hide()
	set_process(true)
	_refresh_shell_texture()
	_refresh_sprite_material()


func _process(_delta: float) -> void:
	_sync_shell_overlay()


func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id
	_refresh_shell_texture()
	_sync_shell_overlay()


func set_camouflage_active(is_active: bool) -> void:
	if _camouflage_active == is_active:
		return
	_camouflage_active = is_active
	_refresh_sprite_material()


func is_camouflage_active() -> bool:
	return _camouflage_active


func set_surge_glow_active(is_active: bool) -> void:
	if _surge_glow_active == is_active:
		return
	_surge_glow_active = is_active
	_refresh_sprite_material()


func clear_item_visuals() -> void:
	_camouflage_active = false
	_surge_glow_active = false
	_refresh_sprite_material()
	_shell_overlay.hide()


func _refresh_shell_texture() -> void:
	var texture_value: Variant = SHELL_TEXTURES.get(_equipped_item_a, null)
	_shell_overlay.texture = texture_value as Texture2D


func _refresh_sprite_material() -> void:
	var resolved_material: Material = _base_sprite_material
	if _camouflage_active:
		resolved_material = _camouflage_material
	elif _surge_glow_active:
		resolved_material = _surge_glow_material
	_animated_sprite.material = resolved_material
	_shell_overlay.material = resolved_material


func _sync_shell_overlay() -> void:
	if _animated_sprite == null or _shell_overlay.texture == null:
		_shell_overlay.hide()
		return
	var should_show: bool = _animated_sprite.visible and _animated_sprite.animation == &"conch"
	_shell_overlay.visible = should_show
	if not should_show:
		return
	# The four shell overlays use the same 800x452 source canvas as the current
	# Hylas conch frames, so mirroring the sprite transform keeps them aligned.
	_shell_overlay.position = _animated_sprite.position
	_shell_overlay.rotation = _animated_sprite.rotation
	_shell_overlay.scale = _animated_sprite.scale
	_shell_overlay.flip_h = _animated_sprite.flip_h
	_shell_overlay.flip_v = _animated_sprite.flip_v
	_shell_overlay.modulate = _animated_sprite.modulate
	_shell_overlay.self_modulate = _animated_sprite.self_modulate
	_shell_overlay.z_index = _animated_sprite.z_index + 1


func get_debug_lines() -> Array[String]:
	return [
		"[HylasItemVisuals]",
		"equipped_item_a=%s" % String(_equipped_item_a),
		"shell_texture_loaded=%s" % str(_shell_overlay.texture != null),
		"shell_visible=%s" % str(_shell_overlay.visible),
		"camouflage_active=%s" % str(_camouflage_active),
		"surge_glow_active=%s" % str(_surge_glow_active),
	]
