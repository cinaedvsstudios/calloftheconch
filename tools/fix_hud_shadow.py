from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HUD_SCRIPT = ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_hud.gd"
HUD_SCENE = ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_hud.tscn"
PREVIEW_SCRIPT = ROOT / "rebuild_v3/editor/gameplay_hud_editor_preview.gd"


def replace_once_or_keep(text: str, old: str, new: str, label: str) -> str:
    if new and new in text:
        return text
    count = text.count(old)
    if count == 1:
        return text.replace(old, new, 1)
    if count == 0 and not new:
        return text
    raise RuntimeError(f"{label}: expected one source block, found {count}")


def fix_hud_script() -> None:
    text = HUD_SCRIPT.read_text(encoding="utf-8")
    text = replace_once_or_keep(
        text,
        'const HUD_DROP_SHADOW_SHADER: Shader = preload(\n'
        '\t"res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader"\n'
        ')\n\n',
        "",
        "HUD shadow shader preload",
    )
    text = replace_once_or_keep(
        text,
        '@onready var _panel_texture: TextureRect = %PanelTexture\n',
        '@onready var _panel_texture: TextureRect = %PanelTexture\n'
        '@onready var _panel_shadow: TextureRect = %PanelShadow\n',
        "HUD shadow node binding",
    )
    text = replace_once_or_keep(
        text,
        'var _panel_shadow: TextureRect\n',
        "",
        "HUD dynamic shadow variable",
    )
    text = replace_once_or_keep(
        text,
        '\t_create_panel_shadow()\n',
        '\t_configure_panel_shadow()\n',
        "HUD ready shadow call",
    )

    old_function = re.compile(
        r"\nfunc _create_panel_shadow\(\) -> void:\n.*?\n\nfunc _get_loaded_panel_count",
        re.DOTALL,
    )
    new_function = '''
func _configure_panel_shadow() -> void:
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
	var shadow_material: ShaderMaterial = _panel_shadow.material as ShaderMaterial
	if shadow_material != null:
		shadow_material.set_shader_parameter(&"shadow_color", hud_shadow_color)
		shadow_material.set_shader_parameter(&"blur_radius", hud_shadow_blur_radius)
	_panel_shadow.visible = hud_shadow_enabled and _get_loaded_panel_count() > 0


func _get_loaded_panel_count'''
    if "func _configure_panel_shadow()" not in text:
        text, count = old_function.subn("\n" + new_function, text, count=1)
        if count != 1:
            raise RuntimeError("Could not replace dynamic HUD shadow function")

    if "TextureRect.new()" in text or "add_child(_panel_shadow)" in text:
        raise RuntimeError("HUD script still creates its shadow node dynamically")
    HUD_SCRIPT.write_text(text, encoding="utf-8", newline="\n")


def fix_preview_script() -> None:
    text = PREVIEW_SCRIPT.read_text(encoding="utf-8")
    text = replace_once_or_keep(
        text,
        'const SHADOW_SHADER: Shader = preload(\n'
        '\t"res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader"\n'
        ')\n\n',
        "",
        "editor preview shadow shader preload",
    )
    text = replace_once_or_keep(
        text,
        '\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n'
        '\tset_process(true)\n'
        '\t_refresh_preview()\n',
        '\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n'
        '\tset_process(true)\n'
        '\tvar hud: Control = get_parent() as Control\n'
        '\tif hud != null:\n'
        '\t\t_panel_shadow = hud.get_node_or_null("PanelShadow") as TextureRect\n'
        '\t_refresh_preview()\n',
        "editor preview saved shadow lookup",
    )
    text = replace_once_or_keep(
        text,
        '\t_ensure_shadow(hud, panel)\n'
        '\t_update_shadow(hud)\n',
        '\t_panel_shadow = hud.get_node_or_null("PanelShadow") as TextureRect\n'
        '\tif is_instance_valid(_panel_shadow):\n'
        '\t\t_panel_shadow.texture = PANEL_TEXTURE\n'
        '\t_update_shadow(hud)\n',
        "editor preview shadow refresh",
    )

    ensure_pattern = re.compile(
        r"\nfunc _ensure_shadow\(hud: Control, panel: TextureRect\) -> void:\n.*?\n\nfunc _update_shadow",
        re.DOTALL,
    )
    if "func _ensure_shadow" in text:
        text, count = ensure_pattern.subn("\n\nfunc _update_shadow", text, count=1)
        if count != 1:
            raise RuntimeError("Could not remove editor preview dynamic shadow function")

    if "TextureRect.new()" in text or "hud.add_child(_panel_shadow)" in text:
        raise RuntimeError("Editor preview still creates its shadow node dynamically")
    PREVIEW_SCRIPT.write_text(text, encoding="utf-8", newline="\n")


def fix_hud_scene() -> None:
    text = HUD_SCENE.read_text(encoding="utf-8")
    text = replace_once_or_keep(
        text,
        '[ext_resource type="Texture2D" uid="uid://cryc77jmj45iu" path="res://assets/ui/shell_normal_conch.png" id="3_2vbiw"]\n',
        '[ext_resource type="Texture2D" uid="uid://cryc77jmj45iu" path="res://assets/ui/shell_normal_conch.png" id="3_2vbiw"]\n'
        '[ext_resource type="Shader" path="res://rebuild_v3/shared/shaders/hud_drop_shadow.gdshader" id="4_shadow_shader"]\n',
        "HUD shadow shader resource",
    )
    text = replace_once_or_keep(
        text,
        '[sub_resource type="SystemFont" id="LocationFont"]\n'
        'font_names = PackedStringArray("Cinzel", "Trajan Pro", "Times New Roman", "Georgia", "Noto Serif")\n'
        'font_weight = 600\n',
        '[sub_resource type="SystemFont" id="LocationFont"]\n'
        'font_names = PackedStringArray("Cinzel", "Trajan Pro", "Times New Roman", "Georgia", "Noto Serif")\n'
        'font_weight = 600\n'
        '\n[sub_resource type="ShaderMaterial" id="PanelShadowMaterial"]\n'
        'shader = ExtResource("4_shadow_shader")\n'
        'shader_parameter/shadow_color = Color(0, 0, 0, 0.62)\n'
        'shader_parameter/blur_radius = 5.0\n',
        "HUD shadow material",
    )

    panel_anchor = '[node name="PanelTexture" type="TextureRect" parent="." unique_id=1278936827]\n'
    shadow_node = (
        '[node name="PanelShadow" type="TextureRect" parent="."]\n'
        'unique_name_in_owner = true\n'
        'z_index = -4\n'
        'layout_mode = 1\n'
        'anchors_preset = 15\n'
        'anchor_right = 1.0\n'
        'anchor_bottom = 1.0\n'
        'offset_left = 7.0\n'
        'offset_top = 10.0\n'
        'offset_right = 7.0\n'
        'offset_bottom = 10.0\n'
        'grow_horizontal = 2\n'
        'grow_vertical = 2\n'
        'mouse_filter = 2\n'
        'texture = ExtResource("2_lc38v")\n'
        'expand_mode = 1\n'
        'stretch_mode = 5\n'
        'material = SubResource("PanelShadowMaterial")\n'
        '\n' + panel_anchor
    )
    text = replace_once_or_keep(text, panel_anchor, shadow_node, "saved HUD shadow node")
    HUD_SCENE.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    fix_hud_scene()
    fix_hud_script()
    fix_preview_script()
    print("Saved HUD shadow node repair completed.")
