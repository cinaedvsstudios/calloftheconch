# Dark-depth life scenes

Drag-ready scenes:

- `rebuild_v3/game/shared/enemies/depth_jellyfish.tscn`
- `rebuild_v3/game/shared/enemies/depth_flare_plant.tscn`
- `rebuild_v3/game/shared/objects/depth_glowplant.tscn`

The jellyfish loops `jfish01` and `jfish02`, then randomly plays `jfish03, 04, 05, 04, 03` while boosting upward and firing a one-shot procedural bubble burst. It then drifts down to the height where the boost began. Its sprite breathes through a slow ten-percent total scale range.

The flare plant remains stationary and loops `plant01` and `plant02`. At random intervals it plays `plant03` and `plant04`, emits a one-shot warm spark spray, and returns to idle. The sparks shoot upward, lose momentum, drift downward under gravity, and fade.

The glow plant loops its two frames and has no damage or stun behaviour.

Both enemies expose the same `receive_conch_hit`, `receive_conus_dart`, `apply_item_paralysis`, `is_frozen`, and `get_frozen_time_remaining` contract used by the shared profile-aware enemy stun system. While stunned they disable contact damage and suspend their special action.

Every scene has both a `PointLight2D` for the darkness system and an additive halo so its glow remains visually legible. The camera-distance activator sleeps effects that are far away.
