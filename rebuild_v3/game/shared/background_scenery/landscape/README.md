# Landscape scenes

This folder contains drag-ready reusable landscape scenes. Every listed image already has its own `.tscn` wrapper with a `Sprite2D` and an ordinary editable `CollisionPolygon2D`.

## Collision behaviour

- Collision is stored directly in the scene structure; it is not generated from image alpha.
- The starting collision is a simple generic four-point box.
- Open an individual landscape `.tscn`, select `CollisionPolygon2D`, and drag its points to fit that image.
- The shared script only assigns the chosen source texture to the Sprite2D. It never creates, removes, traces, or rebuilds collision nodes.
- Placing, rotating, scaling, or duplicating the landscape scene keeps its sprite and collision together.

## Included scenes

- `rock02.tscn` through `rock15.tscn`
- `rock_corner.tscn`
- `island00.tscn` through `island03.tscn`
- `spike_rock.tscn`
- `sand01.tscn` and `sand02.tscn`
- `beach.tscn`

`island02.tscn` points to the existing source file `assets/backgrounds/lsland02.webp`; the source filename contains an old lowercase-L typo and was not renamed to avoid breaking existing references.

The old Sea of Pillars layout does not need to be preserved. These individual scenes are intended to be dragged into the rebuilt L1 and adjusted visually in the Godot editor.
