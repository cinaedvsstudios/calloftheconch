# Call of the Conch — Game Content Library

This folder is the level-building library shown in the Godot FileSystem dock.

Use the `.tscn` files inside these folders as the ready-to-drop scenes when building levels. The underlying runtime implementation remains feature-owned where that prevents duplicated logic or broken resource UIDs.

## Shared

- `shared/objects`: reusable interactive objects
- `shared/enemies`: reusable enemies and hazards
- `shared/effects`: reusable visual and gameplay effects
- `shared/background_scenery`: reusable scenery pieces and collision-ready blocks
- `shared/characters`: Hylas, Greatfin resources, companions, fish schools and whales
- `shared/items`: shells, projectiles and carried items
- `shared/ui`: reusable gameplay UI
- `shared/whale_travel`: whale travel sequences
- `shared/world_map`: world-map scenes and data

## Seas

Each sea owns its local levels, objects, enemies, bosses, effects and scenery:

- `sea_of_pillars`
- `atlas_sea`
- `erythraean_sea`
- `euxine_sea`
- `caspian_sea`
- `boreas_sea`
- `sunder_strait`

The active first-level choice is controlled from the title screen. Prototype remains the default until the production level is deliberately selected.
