# Landscape scenes

This folder contains 23 drag-ready standalone landscape scenes. Each `.tscn` owns its own `StaticBody2D`, `Sprite2D`, texture reference and ordinary editable `CollisionPolygon2D`.

## Transform and collision behaviour

- Every landscape `Sprite2D` explicitly uses `Vector2(0.5, 0.5)` inside its own scene file.
- Every `CollisionPolygon2D` explicitly uses the matching `Vector2(0.5, 0.5)` scale so sprite and collision remain aligned.
- Collision is stored directly in each scene and is never generated from texture alpha.
- Select `CollisionPolygon2D` in an individual scene to edit its points manually.
- Placing, rotating, scaling or duplicating the scene root keeps its sprite and collision together.

## Included scenes

- `rock02.tscn` through `rock15.tscn`
- `rock_corner.tscn`
- `island00.tscn` through `island03.tscn`
- `spike_rock.tscn`
- `sand01.tscn` and `sand02.tscn`
- `beach.tscn`

`island02.tscn` points to the existing source file `assets/backgrounds/lsland02.webp`; the source filename contains an old lowercase-L typo and was not renamed to avoid breaking existing references.
