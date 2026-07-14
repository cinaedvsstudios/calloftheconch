extends "res://rebuild_v3/app/contexts/gameplay/inventory_overlay.gd"

const SOFT_TEXT_SHADOW: Color = Color(0.03, 0.07, 0.11, 0.50)

func _apply_label_readability(label: Label, outline_size: int, shadow_spread: int) -> void:
	label.add_theme_color_override(&"font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override(&"outline_size", outline_size)
	label.add_theme_color_override(&"font_shadow_color", SOFT_TEXT_SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 2)
	label.add_theme_constant_override(&"shadow_offset_y", 3)
	label.add_theme_constant_override(&"shadow_outline_size", shadow_spread + 5)
