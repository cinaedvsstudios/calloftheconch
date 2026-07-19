# Sea of Pillars Background Scenery

Collision-ready rocks, ruins, sand sections, cliffs and city-edge pieces specific to this sea belong here.

The current prototype still owns its original embedded scenery. Extract each piece only after its visual scale and collision shape are verified, so the production level can be assembled from reliable drag-and-drop scenes.

## Pirate ship

`pirate_ship.tscn` is the drag-ready exterior built from `res://assets/backgrounds/ship1.webp`.

- `ShipEntryActionPoint` is a visible draggable editor marker in the centre-lower part of the ship.
- Its child `ShipEntryArea` enables Hylas's existing single-Space interaction while he is nearby.
- Entry plays `hylas-flip_01.webp`, `hylas-flip_02.webp`, then `hylas-flip_04.webp`.
- The final pose rocks five degrees left and right while shrinking to 75% and darkening to 40% brightness.
- The destination is the blank `res://rebuild_v3/game/sea_of_pillars/levels/pirate_ship_interior.tscn` scene.
