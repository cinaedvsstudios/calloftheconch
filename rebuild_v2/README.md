# Call of the Conch — Rebuild V2

This folder is the replacement Godot project structure. It is being built alongside the existing prototype so the old files remain untouched until the rebuild is verified.

Rules for this rebuild:

- Authored game content lives in saved Godot scenes.
- Level art, collision, audio players, cameras, markers, effects anchors, UI and triggers must be visible and editable in the Godot editor.
- Scripts control behaviour of existing nodes only.
- No runtime-generated level layout, collision, scene structure, custom shaders, screen sampling or hidden visual helpers.
- Existing prototype files remain untouched during this rebuild.

Initial scene path:

`rebuild_v2/features/sea_of_pillars_v2/sea_of_pillars_v2.tscn`
