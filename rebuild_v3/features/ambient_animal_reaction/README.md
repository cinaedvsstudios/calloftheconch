# Ambient animal reaction

`ambient_animal_reaction.tscn` is an optional child component for individual decorative `CharacterBody2D` animals.

It does not replace the host's normal movement controller. During a playful reaction it temporarily pauses the host physics callback, owns the short knock/pop motion, and then restores the original controller.

## Inspector controls

- `Reaction Enabled`: master on/off toggle.
- `Reaction Mode`:
  - `none`: no playful action; the component can still enforce the configured hard waterline when enabled.
  - `push_only`: no Tail Flip kick, but ordinary forced movement cannot leave the animal stranded above water.
  - `knockable`: Tail Flip kick plus water-surface pop.
  - `special`: same shared launch path, but first calls `receive_playful_tail_flip_special(direction, source)` on the host when that method exists. A future pufferfish can inflate there and return `false` if its own script wants to fully own the launch.
- Tail Flip reach, width, speed, lift, duration, drag and spin are per-instance.
- Surface margin, arc height, return side distance and recovery depth are per-instance.

## Waterline behavior

The component first searches for a node in the `waterline_marker` group, then falls back to a recursive node named `WaterlineMarker` under the current scene. An explicit Y override is available for unusual levels.

Normal patrol movement is kept below the configured margin. When a real upward push or playful kick crosses the surface:

1. The existing `surface_splash.tscn` plays at the waterline.
2. The animal follows a brief visible arc above the water.
3. It moves to the left or right of the nearest Hylas, based on the launch direction.
4. A smaller entry splash plays.
5. It re-enters below the waterline and its normal controller resumes.

## Currently enabled scenes

- `res://scenes/objects/AmbientFish/ambient_fish_01.tscn` (`fish01.webp`, `fish02.webp`)
- `res://scenes/objects/AmbientFish/ambient_fish_02.tscn` (`fish03.webp`, `fish04.webp`)
- `res://scenes/objects/AmbientFish/ambient_fish_03.tscn` (`fish05.webp`, `fish06.webp`)
- `res://scenes/objects/Seahorse/seahorse.tscn`

The seahorse uses a slightly gentler kick speed and shorter side return distance.

## Exclusions

No enemy scene was changed. No fish-school scene or school controller was changed. A school only receives this behavior if somebody deliberately instances the component under the school root later.

## Adding another decorative animal

Instance `ambient_animal_reaction.tscn` as a direct child of the animal's `CharacterBody2D`. The component automatically finds the first `AnimatedSprite2D` and direct body collision shape, or explicit paths can be assigned in the Inspector.

For an ordinary turtle, use `knockable` and lower the kick speed. For a future pufferfish, use `special` and implement `receive_playful_tail_flip_special()` on the pufferfish controller.

## Manual smoke test

1. Place one of each individual ambient fish and the seahorse underwater near the surface.
2. Confirm normal patrol, wall avoidance, currents and Conch pushing still work.
3. Tail Flip toward each animal and confirm only animals inside the forward corridor are kicked.
4. Confirm the animal spins/wobbles, slows underwater and returns to its patrol controller.
5. Push or kick it upward through the waterline and confirm exit splash, short airborne arc, side relocation and entry splash.
6. Confirm it cannot remain stranded above the waterline.
7. Set `Reaction Enabled` off and confirm the component stops affecting that instance.
8. Set `Reaction Mode` to `push_only` and confirm Tail Flip no longer kicks it.
9. Confirm enemies and all fish-school scenes remain unchanged.
10. Check the debugger for parser, missing-resource, invalid-node or physics-state errors.
