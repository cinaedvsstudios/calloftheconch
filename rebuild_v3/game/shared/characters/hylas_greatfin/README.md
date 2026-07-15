# Hylas — Greatfin

Greatfin is not a second playable character scene. The canonical Hylas scene remains:

`res://scenes/characters/Hylas/hylas.tscn`

When Greatfin is active, Hylas swaps to:

`res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres`

This avoids two Hylas controllers drifting apart. Build and test Greatfin poses in the SpriteFrames resource, then use the normal Hylas scene in levels.
