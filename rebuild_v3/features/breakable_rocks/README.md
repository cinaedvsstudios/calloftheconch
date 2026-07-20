# Breakable rocks

This feature keeps hit routing, presentation and rock state ownership separate.

## Phase 1: reusable debris

Scene:

`res://rebuild_v3/features/effects/rock_debris_burst/rock_debris_burst.tscn`

`RockDebrisBurst` is presentation-only. It accepts:

- impact position
- surface normal
- incoming direction
- mode
- rock tint
- intensity

Supported modes:

- `small_break`
- `drill_tick`
- `big_break`
- `ricochet_scrape`
- `final_collapse`

It randomly selects `debris00.webp` through `debris05.webp`, manually animates a bounded pool of large Sprite2D chunks, draws the small dots and dust procedurally, and queues itself when finished. Most particles use the cold dark/mid-blue palette. Only `drill_tick` mixes in a limited number of magenta, pink and orange drill sparks.

## Phase 2: first breakable rock

Scene:

`res://rebuild_v3/game/shared/background_scenery/landscape/rock02_breakable.tscn`

The original static scene remains unchanged:

`res://rebuild_v3/game/shared/background_scenery/landscape/rock02.tscn`

`rock02_breakable.tscn` is explicitly tagged as a `small_break_rock` and uses:

- intact sprite: `res://assets/backgrounds/rock2.webp`
- broken/open sprite: `res://assets/backgrounds/rock2a.webp`
- intact integrity: 1
- Tail Flip damage: 1
- Sonic Drill pulse damage: 1

The intact collision polygon is copied exactly from the original Rock 02 scene. On break it is disabled and replaced by two separate remnant polygons. There is no polygon across the centre, leaving an approximately 330-pixel-wide passable opening.

## Routing

- Hylas continues to detect Tail Flip collisions and emit `tail_flip_impact`.
- `RockHitRouter`, a focused Hylas child, forwards only targets implementing `receive_tail_flip_bash()`.
- The Sonic Drill profile selectively permits repeated hits only for nodes in `drill_target` that implement `receive_drill_pulse()`.
- Normal and Super Conch keep their existing one-hit response rules.
- The rock owns integrity, debris choice, sprite visibility and collision swapping.

## Persistence boundary

The reusable rock exposes:

- `assign_persistent_id()`
- `get_persistent_state()`
- `set_persistent_state()`

No save write is performed from the rock itself. The first scene is drag-ready but not placed into a progression route yet, so its optional final broken state has not been connected to GameState in this phase.

## Failsafes

A rock will not enter its broken state when:

- the broken sprite texture is missing
- either open-state collision polygon is missing or invalid

It logs a warning and remains visibly and physically intact, avoiding an invisible blocker or an unsafe invisible opening.

## Manual smoke test

1. Place `rock02_breakable.tscn` beside the original `rock02.tscn` and confirm they are independent scenes.
2. Tail Flip the breakable version and confirm one cold-blue `small_break` burst plays.
3. Confirm `rock2.webp` hides and `rock2a.webp` appears.
4. Swim through the centre and confirm no collision covers the opening.
5. Confirm the left and right rock remnants remain solid.
6. Reload the scene and confirm the unplaced generic scene resets intact.
7. Equip Terebridae, drill the intact rock, and confirm `drill_tick` debris appears at the contact point before the final break burst.
8. Confirm normal and Super Conch do not damage the rock.
9. Place two rocks and confirm breaking one does not change the other.
10. Pause during debris and confirm normal scene-tree pause behaviour.
11. Check the debugger for parser, missing-resource, physics-state or invalid-node errors.
