# GDScript style and review checklist

## Project conventions

- `snake_case` for variables, functions, files and folders.
- `PascalCase` for `class_name` types and scene root names.
- `SCREAMING_SNAKE_CASE` for constants.
- Prefix private fields/methods with `_`.
- Type parameters, variables that cross function boundaries, collections, and function returns. Use inference only when the type remains obvious and local.
- Order a script as: class/extends, signals, enums/constants, exports, public fields, private fields, lifecycle callbacks, public methods, private methods.
- Name functions by intent: `save`, `load`, `set_paused`, `request_transition`; avoid vague catch-alls such as `do_stuff` or `manage_everything`.

## Before adding a new script

Ask:

1. What single job does it own?
2. Which specific objects does it need? Can a parent inject them?
3. Could it be a pure `RefCounted` or `Resource` instead of a `Node`?
4. Is a local signal enough, rather than a global event?
5. Does this belong beside an existing feature instead of in a generic `scripts/` folder?

## Before making it global

Ask whether it is actually needed by **every** context and must survive every context transition. If not, make it a child/service of the narrowest owning context.

## Code review red flags

- A feature calls several `get_node("/root/...")` paths.
- A script reaches up to its parent for normal work.
- A global signal contains an event only one local parent cares about.
- A state object plays audio, changes a scene or edits UI.
- One "manager" owns unrelated subjects such as save files, combat, inventory and menus.
- A controller needs five nested dependency bindings just to make one sound play. Consider a smaller feature boundary or a local upward signal.
