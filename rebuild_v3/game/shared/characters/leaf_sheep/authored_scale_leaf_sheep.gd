extends "res://rebuild_v3/game/shared/characters/leaf_sheep/leaf_sheep.gd"

## Keeps carried scale authored on the two cross-fade sprites and synchronizes
## the Item B HUD artwork with Bright, Mid and Low companion phases.

const HUD_LOW_TEXTURE: Texture2D = preload(
	"res://assets/characters/companion_leaf_sheep0.png"
)
const HUD_MID_TEXTURE: Texture2D = preload(
	"res://assets/characters/companion_leaf_sheep1.png"
)
const HUD_BRIGHT_TEXTURE: Texture2D = preload(
	"res://assets/characters/companion_leaf_sheep2.png"
)
const HUD_ICON_SCALE: float = 1.25
const HUD_ICON_BRIGHTNESS: float = 1.25

var _hud_override_active: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	_sync_leaf_sheep_hud()


func _exit_tree() -> void:
	_clear_leaf_sheep_hud_override()
	super._exit_tree()


func _apply_sprite_scale(_texture: Texture2D) -> void:
	pass


func _sync_leaf_sheep_hud() -> void:
	var hud: CotcGameplayHud = _resolve_gameplay_hud()
	if not is_instance_valid(hud):
		return
	var equipped: bool = (
		_game_state != null
		and _game_state.get_equipped_item(ITEM_SLOT_B) == ITEM_ID
	)
	if not equipped:
		if _hud_override_active:
			_clear_leaf_sheep_hud_override()
		return

	# The hourglass overlays the full-size icon; Leaf Sheep never uses the generic
	# timed-item shrink intended for shells and consumables.
	hud.set_item_b_timed_active(false)
	var icon: TextureRect = hud.get_node_or_null(^"ItemBIcon") as TextureRect
	var glow: TextureRect = hud.get_node_or_null(^"ItemBGlow") as TextureRect
	if not is_instance_valid(icon) or not is_instance_valid(glow):
		return
	var phase_texture: Texture2D = _get_hud_phase_texture()
	icon.texture = phase_texture
	glow.texture = phase_texture
	var brightness: Color = Color(
		HUD_ICON_BRIGHTNESS,
		HUD_ICON_BRIGHTNESS,
		HUD_ICON_BRIGHTNESS,
		1.0,
	)
	icon.self_modulate = brightness
	glow.self_modulate = brightness
	icon.pivot_offset = icon.size * 0.5
	glow.pivot_offset = glow.size * 0.5
	icon.scale = Vector2.ONE * HUD_ICON_SCALE
	glow.scale = Vector2.ONE * HUD_ICON_SCALE
	_hud_override_active = true


func _get_hud_phase_texture() -> Texture2D:
	match get_phase_name():
		PHASE_MID:
			return HUD_MID_TEXTURE
		PHASE_LOW:
			return HUD_LOW_TEXTURE
		_:
			return HUD_BRIGHT_TEXTURE


func _resolve_gameplay_hud() -> CotcGameplayHud:
	if not is_instance_valid(_context):
		return null
	return _context.get_node_or_null(^"GameplayUI/GameplayHud") as CotcGameplayHud


func _clear_leaf_sheep_hud_override() -> void:
	var hud: CotcGameplayHud = _resolve_gameplay_hud()
	if is_instance_valid(hud):
		hud.set_item_b_timed_active(false)
		var icon: TextureRect = hud.get_node_or_null(^"ItemBIcon") as TextureRect
		var glow: TextureRect = hud.get_node_or_null(^"ItemBGlow") as TextureRect
		if is_instance_valid(icon):
			icon.self_modulate = Color.WHITE
			icon.scale = Vector2.ONE
		if is_instance_valid(glow):
			glow.self_modulate = Color.WHITE
			glow.scale = Vector2.ONE
		if hud.has_method(&"_sync_equipment_from_state"):
			hud.call(&"_sync_equipment_from_state")
	_hud_override_active = false
