# Landscape scenes

This folder contains 23 original drag-ready standalone landscape scenes plus one clearly tagged breakable Rock 02 variant. Each `.tscn` owns its own body, sprite textures and ordinary editable collision polygons.

## Transform and collision behaviour

- Every original landscape `Sprite2D` explicitly uses `Vector2(0.5, 0.5)` inside its own scene file.
- Every original `CollisionPolygon2D` explicitly uses the matching `Vector2(0.5, 0.5)` scale so sprite and collision remain aligned.
- Collision is stored directly in each scene and is never generated from texture alpha.
- Select a `CollisionPolygon2D` in an individual scene to edit its points manually.
- Placing, rotating, scaling or duplicating the scene root keeps its sprite and collision together.

## Original standalone scenes

- `rock02.tscn` through `rock15.tscn`
- `rock_corner.tscn`
- `island00.tscn` through `island03.tscn`
- `spike_rock.tscn`
- `sand01.tscn` and `sand02.tscn`
- `beach.tscn`

## Breakable variant

- `rock02_breakable.tscn` is a separate small-break scene using `rock2.webp` as intact art and `rock2a.webp` as broken/open art.
- The original `rock02.tscn` remains unchanged.
- Its intact collision matches the original Rock 02 polygon.
- Its broken state uses separate left and right polygons, leaving the centre physically passable.

`island02.tscn` points to the existing source file `assets/backgrounds/lsland02.webp`; the source filename contains an old lowercase-L typo and was not renamed to avoid breaking existing references.
