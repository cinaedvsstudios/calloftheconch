from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMEPLAY_SCRIPT = ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_inventory_audio.gd"
GAMEPLAY_SCENE = ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_context.tscn"
ARCHIVE_DIR = ROOT / "rebuild_v3/archive/obsolete_gameplay_wrappers"


def replace_exact(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count == 1:
        return text.replace(old, new, 1)
    if count == 0 and new in text:
        return text
    raise RuntimeError(f"{label}: expected exactly one old block, found {count}")


def fix_gameplay_script() -> None:
    text = GAMEPLAY_SCRIPT.read_text(encoding="utf-8")

    text = replace_exact(
        text,
        'event.is_action_released(&"inventory", false, true)',
        'event.is_action_released(&"inventory")',
        "InputEvent release signature",
    )

    text = replace_exact(
        text,
        'const ITEM_CLICK_STREAM: AudioStream = preload("res://assets/audio/pickup6.mp3")\n'
        'const ITEM_EQUIP_STREAM: AudioStream = preload("res://assets/audio/pickup1.mp3")\n'
        'const INVENTORY_OPEN_STREAM: AudioStream = preload("res://assets/audio/pickup4.mp3")\n\n',
        "",
        "runtime audio preload constants",
    )

    text = replace_exact(
        text,
        'var _item_click_audio: AudioStreamPlayer\n'
        'var _item_equip_audio: AudioStreamPlayer\n'
        'var _inventory_open_audio: AudioStreamPlayer\n',
        '@onready var _item_click_audio: AudioStreamPlayer = %InventoryItemClickAudio\n'
        '@onready var _item_equip_audio: AudioStreamPlayer = %InventoryItemEquipAudio\n'
        '@onready var _inventory_open_audio: AudioStreamPlayer = %InventoryOpenAudio\n',
        "saved audio node bindings",
    )

    text = replace_exact(
        text,
        '\t_item_click_audio = _create_ui_audio_player(&"InventoryItemClickAudio", ITEM_CLICK_STREAM, -5.0)\n'
        '\t_item_equip_audio = _create_ui_audio_player(&"InventoryItemEquipAudio", ITEM_EQUIP_STREAM, -4.0)\n'
        '\t_inventory_open_audio = _create_ui_audio_player(&"InventoryOpenAudio", INVENTORY_OPEN_STREAM, -5.0)\n',
        "",
        "runtime audio node creation",
    )

    creator_pattern = re.compile(
        r"\nfunc _create_ui_audio_player\(.*?\n\treturn player\n\n",
        re.DOTALL,
    )
    text, substitutions = creator_pattern.subn("\n", text, count=1)
    if substitutions == 0 and "func _create_ui_audio_player" in text:
        raise RuntimeError("Could not remove runtime audio-player factory")

    if not text.startswith('extends "res://rebuild_v3/app/contexts/gameplay/gameplay_context.gd"'):
        raise RuntimeError("Gameplay controller no longer extends gameplay_context.gd directly")

    GAMEPLAY_SCRIPT.write_text(text, encoding="utf-8", newline="\n")


def fix_gameplay_scene() -> None:
    text = GAMEPLAY_SCENE.read_text(encoding="utf-8")
    text = replace_exact(
        text,
        "[gd_scene load_steps=12 format=3]",
        "[gd_scene load_steps=15 format=3]",
        "gameplay scene load step count",
    )

    resource_anchor = (
        '[ext_resource type="PackedScene" path="res://rebuild_v3/app/contexts/gameplay/item_effect_controller.tscn" id="11_item_effects"]\n'
    )
    resource_block = resource_anchor + (
        '[ext_resource type="AudioStream" path="res://assets/audio/pickup6.mp3" id="12_item_click_audio"]\n'
        '[ext_resource type="AudioStream" path="res://assets/audio/pickup1.mp3" id="13_item_equip_audio"]\n'
        '[ext_resource type="AudioStream" path="res://assets/audio/pickup4.mp3" id="14_inventory_open_audio"]\n'
    )
    text = replace_exact(text, resource_anchor, resource_block, "inventory audio resources")

    music_block = (
        '[node name="GameplayMusic" type="AudioStreamPlayer" parent="."]\n'
        'unique_name_in_owner = true\n'
        'stream = ExtResource("3_music")\n'
        'volume_db = -8.0\n'
        'script = ExtResource("5_looping_audio")\n'
    )
    audio_nodes = music_block + (
        '\n[node name="InventoryItemClickAudio" type="AudioStreamPlayer" parent="."]\n'
        'unique_name_in_owner = true\n'
        'process_mode = 3\n'
        'stream = ExtResource("12_item_click_audio")\n'
        'volume_db = -5.0\n'
        '\n[node name="InventoryItemEquipAudio" type="AudioStreamPlayer" parent="."]\n'
        'unique_name_in_owner = true\n'
        'process_mode = 3\n'
        'stream = ExtResource("13_item_equip_audio")\n'
        'volume_db = -4.0\n'
        '\n[node name="InventoryOpenAudio" type="AudioStreamPlayer" parent="."]\n'
        'unique_name_in_owner = true\n'
        'process_mode = 3\n'
        'stream = ExtResource("14_inventory_open_audio")\n'
        'volume_db = -5.0\n'
    )
    text = replace_exact(text, music_block, audio_nodes, "saved inventory audio nodes")
    GAMEPLAY_SCENE.write_text(text, encoding="utf-8", newline="\n")


def archive_unused_wrappers() -> None:
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    wrapper_paths = [
        ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_double_tap_inventory.gd",
        ROOT / "rebuild_v3/app/contexts/gameplay/gameplay_equipment_input.gd",
    ]
    for source in wrapper_paths:
        if not source.exists():
            continue
        archive = ARCHIVE_DIR / f"{source.name}.txt"
        archive.write_text(
            f"# Archived from res://{source.relative_to(ROOT).as_posix()}\n"
            "# The active gameplay controller now owns this behaviour directly.\n\n"
            + source.read_text(encoding="utf-8"),
            encoding="utf-8",
            newline="\n",
        )
        source.unlink()
        uid_path = Path(str(source) + ".uid")
        if uid_path.exists():
            uid_path.unlink()


def audit_active_sources() -> None:
    invalid_releases: list[str] = []
    old_path_references: list[str] = []
    old_paths = (
        "gameplay_double_tap_inventory.gd",
        "gameplay_equipment_input.gd",
        "gameplay_level_variants.gd",
    )

    for path in ROOT.rglob("*"):
        if not path.is_file() or ".godot" in path.parts or "archive" in path.parts:
            continue
        if path.suffix not in {".gd", ".tscn", ".tres", ".cfg", ".godot"}:
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        if path.suffix == ".gd":
            for line_number, line in enumerate(content.splitlines(), start=1):
                for match in re.finditer(r"is_action_released\(([^()]*)\)", line):
                    if match.group(1).count(",") > 1:
                        invalid_releases.append(f"{path.relative_to(ROOT)}:{line_number}: {line.strip()}")
        for old_path in old_paths:
            if old_path in content:
                old_path_references.append(f"{path.relative_to(ROOT)} -> {old_path}")

    if invalid_releases:
        raise RuntimeError("Invalid is_action_released signatures:\n" + "\n".join(invalid_releases))
    if old_path_references:
        raise RuntimeError("Active references to archived wrappers:\n" + "\n".join(old_path_references))


if __name__ == "__main__":
    fix_gameplay_script()
    fix_gameplay_scene()
    archive_unused_wrappers()
    audit_active_sources()
    print("Godot 4.7 gameplay repair and source audit completed.")
