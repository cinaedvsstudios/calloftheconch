# rebuild_v3

Clean V3 content folder for **Call of the Conch Prototype**.

## Goals of this rebuild
- remove all old path dependencies;
- keep ownership local to the object or feature that owns each control;
- remove the unused runtime-created material helper;
- keep only `res://assets/...` references outside `rebuild_v3`;
- include a simple Developer/Admin Panel toggled with `toggle_developer_admin` (F9 in the supplied project file).

## Structure
- `app/` Root context and major contexts
- `features/` gameplay features grouped by ownership
- `shared/` shared reusable script/shader assets
- `docs/` local notes for this rebuild

## Important note
The root `project.godot` must point to `res://rebuild_v3/app/front_end.tscn`.
