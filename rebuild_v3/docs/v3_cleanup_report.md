# V3 cleanup summary

## Included cleanup
- Renamed runtime content into `rebuild_v3`.
- Updated the main-scene path in the supplied `project.godot`.
- Removed all old rebuild path references.
- Removed the old external bubble-overlay material dependency from Sea of Pillars.
- Removed the direct imported-ctex scene dependency from the parallax water tile.
- Canonicalised the left-water-fade shader to a single file.
- Removed the unused `screen_video_player.gd` helper from the delivered folder.
- Removed the preview/test launcher from the delivered folder.
- Added a simple Developer/Admin Panel with a copyable report.

## Known intentionally retained external dependencies
Only `res://assets/...` references remain external to `rebuild_v3`.
These are expected because the user explicitly chose to keep the root `assets/` folder.

## TailBubbleBurst note
The burst now uses a simple visibility timer controlled by `CotcHylas` rather than the `finished` signal.
This keeps the control local to Hylas and avoids depending on decoder finish timing.
