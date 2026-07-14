# Unused-file audit

This reorganisation archives only files whose active replacement was established before removal.

## Removed from active paths

- Sea of Pillars item-effect wrapper scene and script
  - replaced by the prototype/main level scenes and `sea_of_pillars_runtime.gd`
- old Conus tether script path
  - replaced by `game/shared/items/conus_textile`
- old Argonauta projectile and cloud script paths
  - replaced by `game/shared/items/argonauta`
- stray Crown Sea Grapes pickup instance attached directly to `front_end.tscn`
  - the actual pickup scene remains available in `game/shared/objects`

## Compatibility aliases retained

The three old item `.tscn` paths remain as tiny aliases to their new canonical scenes. They contain no duplicate behaviour and protect any editor scene that still references the previous path.

## Not automatically archived

Unknown images, audio, videos, imports and old scenes were not mass-moved merely because a text search did not find them. Godot resources can be loaded dynamically, assigned through the Inspector or referenced by imported UIDs. They should move to the archive only after the editor dependency scan and a clean runtime pass prove they are unused.

Rollback branch:

`backup/working-2026-07-14-before-game-library-reorg`
