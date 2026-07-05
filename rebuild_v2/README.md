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
