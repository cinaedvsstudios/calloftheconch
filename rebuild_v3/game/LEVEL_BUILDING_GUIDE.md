# Level-building quick guide

## Choose the first level

The title screen contains a `LEVEL VERSION` selector:

- `Sea of Pillars — Prototype`
- `Sea of Pillars — Main`

Prototype is the default. Main is the production work scene.

## Open a level

Current playable area scenes are under:

`res://rebuild_v3/game/sea_of_pillars/levels/`

- `sea_of_pillars_prototype.tscn`
- `sea_of_pillars_main.tscn`
- `neresithoppos_city.tscn`
- `pirate_ship_interior.tscn` — prepared placeholder
- `scylla_boss_arena.tscn` — prepared placeholder

## Drag content into a level

Browse under `res://rebuild_v3/game/shared/`:

- `objects`
- `enemies`
- `effects`
- `characters`
- `items`
- `ui`
- `whale_travel`
- `background_scenery`
- `world_map`

Drag the ready `.tscn` file from the relevant folder into the open level scene.

## Ownership rule

A wrapper scene in the library points to one canonical feature scene. Do not duplicate the underlying script or artwork merely to make another sea use it. Sea-specific content belongs under that sea; content carried by Hylas or reused across seas belongs under `game/shared`.

## Current limitations

- The prototype's embedded rocks, sand, ruins and collisions have not yet all been extracted into reusable scenery scenes.
- Leaf Sheep has no finished runtime scene yet.
- Tyche Margarites behaviour is documented but not implemented.
- Pirate Ship Interior and Scylla Boss Arena are empty prepared scenes, not completed levels.
