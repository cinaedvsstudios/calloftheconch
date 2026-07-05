# Call of the Conch — Rebuild V2

This folder is the parallel replacement for the old prototype. The old prototype files have not been changed by this rebuild.

## Rebuild rules

- Every authored object is a saved Godot scene node.
- Level art, collision, audio players, cameras, spawn markers, effects anchors, UI and triggers are visible in the Scene tree and editable in the Inspector.
- Scripts control behaviour of existing nodes only.
- No runtime-created level layout, terrain collision, scene structure, custom shaders, screen sampling or hidden visual helpers.

## Run this first

Open and run:

`rebuild_v2/app/front_end_v2.tscn`

This opens the V2 title screen, then starts the V2 Sea of Pillars level.

For direct level inspection without the menu, run:

`rebuild_v2/app/rebuild_preview_v2.tscn`

## Main V2 scenes

- `app/front_end_v2.tscn` — V2 title and gameplay flow.
- `app/contexts/menu_v2/menu_context_v2.tscn` — editable title screen.
- `app/contexts/gameplay_v2/gameplay_context_v2.tscn` — editable gameplay wrapper and pause UI.
- `features/sea_of_pillars_v2/sea_of_pillars_v2.tscn` — editable water, terrain art, collision, audio, markers and effects.
- `features/hylas_v2/hylas_v2.tscn` — editable Hylas sprite, collision, camera, audio and effect anchors.


## Single-control rule (V2 cleanup)

Each value has one authoring home. Scene nodes own their authored placement and structure; root feature nodes own their behaviour settings; materials on the visual node own shader appearance. Scripts may derive runtime state from those controls, but do not provide competing Inspector values.

Examples:

- `ShadowSprite` owns its shader appearance and native offset. Hylas only mirrors live texture, direction, rotation and body scale.
- `CollisionShape` owns the Hylas hitbox size.
- `HylasStart`, `WaterlineMarker`, `WorldTopLeft` and `WorldBottomRight` own level spawn/bounds.
- `ConchPulseV2` owns pulse timing, size and width transition; `Ring` owns its line geometry and colour.
- Each bubble `VideoStreamPlayer` owns its own assigned material.
- `UnderwaterAmbience` owns its loop setting; `SeaOfPillarsV2` owns only whether it starts for this level.
