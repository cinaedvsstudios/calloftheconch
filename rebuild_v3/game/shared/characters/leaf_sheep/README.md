# Leaf Sheep Companion

Canonical runtime scene:

`rebuild_v3/game/shared/characters/leaf_sheep/leaf_sheep.tscn`

The scene owns the temporary READY, BRIGHT, MID, LOW and COOLDOWN states. Bright lasts 60 seconds, Mid lasts 30 seconds, Low remains active until deactivation, and cooldown lasts 30 seconds. Temporary phase and cooldown state are deliberately not saved.

Sprite mapping:

- `companion_leaf_sheep2.png` — Bright
- `companion_leaf_sheep1.png` — Mid
- `companion_leaf_sheep0.png` — Low

The scene follows Hylas's hand, crossfades between brightness sprites, drives the local `PointLight2D`, and exposes a camera-fixed procedural darkness overlay.

A level may provide metadata named `leaf_sheep_darkness_profile`. For a depth gradient, use a Dictionary containing `id`, `start_y`, `full_y`, `maximum_darkness` and `tint`. Darkness smoothly increases as Hylas moves from `start_y` to `full_y`. A static profile may instead contain `id`, `darkness_strength` and `tint`. Without metadata, the overlay remains disabled so illuminated levels are unaffected.

The Item B catalogue entry is permanent and quantity-free. The shared item-effect controller instances this scene and toggles it when `leaf_sheep` is used. Hylas uses the four normal or Greatfin carry frames while active, blocks Speed Run, Surge, Tail Flip and Conus climbing, and requests forced deactivation on death or land entry.

The gameplay wrapper forces deactivation for city entry, whale travel and context exit. Pause and inventory stop the timers through normal pausable processing. Ordinary underwater level replacement rebinds the same controller without resetting its active phase. Loading or replacing game state resets temporary Leaf Sheep state to inactive and READY.
