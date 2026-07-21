# Placeable World-Object Scale Audit

Date: 2026-07-21

Audit baseline: `main` at `a817140a9b0038fea73e8e5106475551c1319be0`

## Agreed scale contract

This audit uses the following rule for reusable objects placed into gameplay scenes:

`final gameplay size = visual scale authored inside the reusable .tscn × Transform scale on the placed scene instance`

The reusable scene owns the normal/base visual size. The Transform scale on an instance inside a level is the only intentional size-variation multiplier. Runtime scripts must not calculate or apply a third permanent visual scale.

For reliable multiplication, a reusable scene should normally have a neutral root transform (`Vector2(1, 1)`) and keep its authored base size on a visual child. An instance-scale override on the root can then multiply the visual child scale without replacing the reusable scene's base scale.

Temporary object animation is allowed when it is visibly intentional, works relative to the authored base scale, and returns to that exact base. Examples include breathing, pulsing, squash-and-stretch and collection pulses. VFX, particles, shaders, UI, overlays, backgrounds and camera zoom are outside this migration.

## Executive result

The current project does not yet follow the contract consistently.

Confirmed findings:

- 11 placeable-object controller families permanently calculate or rewrite visual scale at runtime.
- The shared editor preview helper also rewrites visual scale and exists only to mirror that runtime calculation.
- 5 confirmed reusable scene files place their base scale directly on the scene root, so a level-instance root-scale override replaces rather than multiplies the authored base scale.
- Several scenes are already structurally suitable and only need verification or no change.
- Existing level-instance scale variation is valid and must be preserved.
- No VFX migration is required.

## A. Confirmed permanent runtime scale writers — migration required

### A1. Food and general object pickups

Controller:

`scenes/objects/Pickups/food_pickup.gd`

Current behaviour:

- Exposes `display_height`.
- Calls `_apply_display_scale()` from `_ready()`.
- Calculates `display_height / texture height`.
- Replaces `PickupSprite.scale` with that calculated value.
- Stores the calculated result as `_resting_sprite_scale` and uses it as the base for the collection pulse.

Impact:

The scale authored on `PickupSprite` in each `.tscn` is not authoritative. A placed instance can look correct in the editor and then use a different child-sprite scale once gameplay starts.

Confirmed affected examples include:

- `food_scavenged_fish_pickup.tscn`
- `food_scavenged_fish2_pickup.tscn`
- Sea Grapes pickup
- Samphire pickup
- `abyssium_star_greek_key_joint_pickup.tscn`
- `antikythera_mechanism_pickup.tscn`
- `bell_shaped_block_of_lead_pickup.tscn`
- `box_pickup.tscn`
- `conusdart_pickup.tscn`
- `floor_mosaic_tiles_pickup.tscn`
- `grapes_box_pickup.tscn`
- `item_echo_amphora_pickup.tscn`
- `obsidian_arrowhead_pickup.tscn`
- `oil_lamp_pickup.tscn`
- `perfume_bottle_pickup.tscn`
- `soldier_helmet_pickup.tscn`
- `terracotta_figurine_animal_pickup.tscn`
- `terracotta_figurine_deity_idol_pickup.tscn`
- `terracotta_figurine_human_pickup.tscn`

Required migration:

Bake the currently intended normal scale into each pickup scene's visual child. Remove the permanent `display_height` scale assignment. Keep the dissolve pulse relative to the authored child scale and return to it exactly.

### A2. Catalogue-driven treasure pickups

Controller:

`scenes/objects/Pickups/treasure_pickup.gd`

Current behaviour:

- Runs as an editor tool.
- Both `treasure_id` and `display_height` setters can trigger `_apply_display_scale()`.
- `_ready()` also triggers it.
- The method replaces `PickupSprite.scale` using `display_height / texture height`.

Impact:

The treasure catalogue artwork and runtime size are controlled by script rather than solely by the authored scene transform. Every inherited treasure scene using this controller is affected.

Required migration:

Load the catalogue texture without rewriting scale. Bake each treasure's intended normal child scale into its scene or inherited override.

### A3. Shark enemy

Controller:

`scenes/enemies/Shark/shark_item_effects.gd`

Scene:

`scenes/enemies/Shark/shark_enemy.tscn`

Current behaviour:

- Exposes `display_height = 300`.
- Calls `_apply_display_scale()` during `_ready()`.
- Replaces `AnimatedSprite.scale` from the first animation texture height.

Structure:

The root is already neutral and the animated visual is a child, which is the correct scene structure. Only the runtime scale authority must be removed and its intended result baked into the child.

### A4. Standard jellyfish enemy

Controller:

`scenes/enemies/Jellyfish/jellyfish_enemy.gd`

Scene:

`scenes/enemies/Jellyfish/jellyfish_enemy.tscn`

Current behaviour:

- Exposes `display_height = 250`.
- Calls `_apply_display_scale()` during `_ready()`.
- Replaces `AnimatedSprite.scale`.
- Includes the shared `DisplayHeightPreview` helper to mirror the runtime calculation in the editor.

Required migration:

Bake the normal animated-sprite scale into the scene. Remove both runtime display-height scaling and the preview helper. Preserve the separately positioned floor probe and verify it against the baked visual.

### A5. Original flat-image fish school

Controller:

`scenes/objects/FishSchool/fish_school.gd`

Scene:

`scenes/objects/FishSchool/fish_school.tscn`

Editor helper:

`rebuild_v3/editor/fish_school_editor_preview.gd`

Current behaviour:

- Exposes both `display_height` and `display_scale_multiplier`.
- Runtime calculates and replaces `AnimatedSprite.scale`.
- The custom editor helper performs the same replacement continuously in the editor.

Impact:

This has two extra scale controls before the valid level-instance multiplier. The current editor display may match runtime, but the authored child transform is not the authority.

Required migration:

Bake the current calculated result into `AnimatedSprite.scale`. Keep the patrol-area drawing portion of the editor helper if useful, but remove its sprite-scale rewriting.

### A6. Ambient fish family and seahorse

Controller:

`scenes/objects/AmbientFish/ambient_fish.gd`

Confirmed scenes:

- `scenes/objects/AmbientFish/ambient_fish_01.tscn`
- `scenes/objects/AmbientFish/ambient_fish_02.tscn`
- `scenes/objects/AmbientFish/ambient_fish_03.tscn`
- `scenes/objects/Seahorse/seahorse.tscn`

Current behaviour:

- Exposes `display_height` and `display_scale_multiplier`.
- `_ready()` calls `_apply_display_scale_and_collision()`.
- Runtime replaces the animated sprite scale.
- Runtime also rebuilds body and current-receiver collision rectangles from the calculated visual size.

Impact:

The authored child scale is overwritten. Collision geometry is coupled to the unwanted runtime scale calculation, so this family needs a combined visual-and-collision migration rather than deleting one line.

Required migration:

Bake each fish/seahorse visual scale into its scene. Bake or explicitly author matching collision shapes. Preserve level-instance root scaling as the only variation multiplier.

### A7. Puffer fish

Controller:

`scenes/objects/PufferFish/puffer_fish.gd`

Scene:

`scenes/objects/PufferFish/puffer_fish.tscn`

Current behaviour:

- Scene root has `scale = Vector2(0.4, 0.4)`.
- Runtime also calculates a child-sprite scale from `display_height = 95`.
- Collision has a separate large, non-uniform child scale.

Impact:

This is the highest-risk current object. It combines an authored root scale, a runtime child scale and a separately scaled collision. A level-instance root-scale override does not cleanly represent the intended second multiplier because it replaces the root's authored `0.4` value.

Required migration:

Move the base visual size from the root into the visual child, return the root to `Vector2(1, 1)`, remove runtime display-height scaling, and refit the collision without changing the puff animation frames.

### A8. Depth jellyfish

Controller:

`rebuild_v3/features/depth_life/depth_jellyfish.gd`

Scene:

`rebuild_v3/game/shared/enemies/depth_jellyfish.tscn`

Current behaviour:

- Exposes `display_height = 150`.
- Runtime replaces animated-sprite scale.
- Uses the shared editor display-height preview.

Required migration:

Bake the runtime result into the animated child, remove the permanent runtime assignment and preview helper, and preserve bubble/light placement.

### A9. Depth flare plant

Controller:

`rebuild_v3/features/depth_life/depth_flare_plant.gd`

Scene:

`rebuild_v3/game/shared/enemies/depth_flare_plant.tscn`

Current behaviour:

- Exposes `display_height = 210`.
- Runtime replaces animated-sprite scale.
- Uses the shared editor display-height preview.
- Spark, glow and light offsets are also derived from `display_height`.

Required migration:

Bake the plant visual scale into the animated child. Replace `display_height`-derived attachment positions with authored scene positions so the editor shows the complete final composition.

### A10. Depth glow plant

Controller:

`rebuild_v3/features/depth_life/depth_glowplant.gd`

Scene:

`rebuild_v3/game/shared/objects/depth_glowplant.tscn`

Current behaviour:

- Scene stores `AnimatedSprite.scale = Vector2(0.515, 0.515)`.
- Runtime calculates another base scale from `display_height = 220` and replaces the authored value.
- The shared preview helper performs the same rewrite in the editor.
- A small breathing pulse then animates relative to the runtime-generated base.

Required migration:

Choose and preserve the current intended base appearance, bake it into the animated child, remove display-height replacement and keep the breathing pulse relative to that authored base.

### A11. Leaf Sheep companion

Controller:

`rebuild_v3/game/shared/characters/leaf_sheep/leaf_sheep.gd`

Scene:

`rebuild_v3/game/shared/characters/leaf_sheep/leaf_sheep.tscn`

Current behaviour:

- Exposes `display_height = 54`.
- Each phase change calls `_apply_sprite_scale()`.
- Both cross-fade sprites have their scale replaced from the selected texture height.

Impact:

The companion's scene does not directly show its final carried size. Its permanent scale is state-driven by script.

Required migration:

Author the base scale on both sprite children in the scene. Keep phase texture changes and cross-fading, but do not recalculate scale when the phase changes. All Leaf Sheep phase textures must share a consistent canvas/pivot.

## B. Shared editor scale writer — remove after baking

File:

`rebuild_v3/shared/editor_display_height_preview.gd`

This helper reads a `display_height` property and writes a target Sprite2D or AnimatedSprite2D scale. It was created to make the editor imitate the runtime display-height system.

Under the agreed contract this helper is no longer needed for object size. Once each affected object's intended size is baked into its `.tscn`, every `DisplayHeightPreview` node and dependency should be removed from placeable world objects.

It should not be deleted until every dependent scene has been migrated, because deleting it first would make current editor previews regress before their authored scales are baked.

## C. Root-scale structural conflicts — migration required

The following confirmed scenes place their normal/base size directly on the scene root:

- `scenes/objects/PufferFish/puffer_fish.tscn` — root scale `0.4`
- `scenes/objects/seaweed_12.tscn` — AnimatedSprite2D root scale `0.5`
- `scenes/objects/seaweed_34.tscn` — AnimatedSprite2D root scale `0.5`
- `scenes/objects/seaweed_56.tscn` — AnimatedSprite2D root scale `0.5`
- `rebuild_v3/features/vent1/vent1.tscn` — root scale `0.405`

A level-instance root Transform override on these scenes replaces the base root property instead of serving as a clean second multiplier.

Required migration:

Give each scene a neutral Node2D/Area2D/CharacterBody2D root as appropriate, move the authored base scale onto its visual child or visual container, and preserve all collision/interaction geometry.

## D. Existing level-instance scale overrides — valid and preserved

The populated Sea of Pillars level intentionally gives different instances of the same scene different root scales. Confirmed examples include:

- Fish schools at `0.5`, `0.6`, `0.7`, `0.8` and `0.85`.
- Sharks at `0.7`, `0.8`, `1.0` and `1.2`.

These are the legitimate second scale and are not to be flattened or removed. After migration, the level editor should continue to show those variations, and gameplay should use exactly the same final sizes.

## E. Compatible or conditionally compatible objects

### E1. Procedural fish schools — compatible internal composition

Controller:

`scenes/objects/FishSchool/procedural_fish_school.gd`

Scenes:

- `fish_school_procedural_10.tscn`
- `fish_school_procedural_15.tscn`
- `fish_school_procedural_20.tscn`

The school roots are neutral. The script generates child fish and assigns each child an intentional internal scale based on minimum/maximum fish height and random variation. It does not use that calculation to rewrite the school root.

Classification:

Allowed. The internal fish scales are part of the authored procedural composition. The whole school still receives only the level-instance root multiplier. A regression check should confirm no future code writes the school root scale.

### E2. Whale travel scene — compatible

Scene:

`rebuild_v3/features/whale_travel/whale_travel.tscn`

The root is neutral and the normal base scale is on `WhaleSprite`. Its controller moves, bobs and flips the whale but does not rewrite scale.

Classification:

Compliant. Preserve as-is, subject to runtime visual confirmation.

### E3. Spike Rock — compatible

Scene:

`scenes/objects/SpikeRock/spike_rock.tscn`

The root is neutral and the base visual scale is on `SpikeRockSprite`.

Classification:

Compliant. Preserve as-is. Verify that its authored collision remains aligned at several instance scales.

### E4. Black Bloom — compatible

Scene:

`rebuild_v3/features/black_bloom/black_bloom_hazard.tscn`

The root is neutral. The controller changes animation and tint but does not rewrite object scale.

Classification:

Compliant. The scaled wake-bubble node is VFX and outside the migration.

### E5. Passive Tide Anemone — allowed temporary animation

Scene:

`rebuild_v3/features/passive_tide_anemone/passive_tide_anemone.tscn`

The root is neutral and the base sprite scale is authored on the child Sprite2D. The controller animates a `VisualRoot` between pulse limits.

Classification:

Conditionally compliant. The pulse is intentional temporary object animation rather than permanent normalization. During migration it should be adjusted to pulse relative to the authored `VisualRoot` base rather than assuming `Vector2.ONE`, so future changes to its base transform cannot be lost.

### E6. Boulder — mathematically preserves placed size but uses transform transfer

Scene:

`rebuild_v3/features/boulder/boulder.tscn`

The boulder controller records the placed root scale, multiplies that scale into its sprite and collision children, then resets the root to `Vector2.ONE` at runtime.

Classification:

Conditional. This does not introduce an independent size factor and should preserve the editor's final visible size, but it mutates transform ownership at runtime. It must be tested at multiple instance scales before deciding whether to retain the transfer for physics reasons or replace it with a cleaner neutral-root setup.

## F. Excluded from this audit

The following are deliberately excluded unless they are embedded in a placeable object's authored composition:

- particles and one-shot effects;
- bubble videos and overlays;
- sonar and Conch effects;
- shaders and material-only animation;
- UI and HUD elements;
- tutorial text and screen-space presentation;
- backgrounds and landscape art;
- camera zoom;
- Hylas form/animation presentation;
- temporary impact flashes.

## G. Migration order recommended for Phase 2

1. Puffer fish and the three seaweed scenes, because their base scale is currently on the scene root.
2. Food/general pickups and treasure pickups, preserving the current collection pulse.
3. Shark and standard jellyfish.
4. Ambient fish, seahorse and original flat fish school.
5. Depth jellyfish, depth flare plant and depth glow plant.
6. Leaf Sheep.
7. Vent root restructuring.
8. Conditional validation of Tide Anemone and Boulder.
9. Remove the shared editor display-height helper only after all dependencies have been migrated.
10. Validate every changed object at level-instance scales `0.5`, `1.0` and `1.5`, checking editor size, runtime size and collision alignment.

## H. Phase 2 acceptance conditions

For every migrated placeable object:

- The reusable `.tscn` visibly shows its normal/base size.
- The reusable scene root is neutral unless there is a documented technical reason otherwise.
- Starting gameplay causes no size jump.
- A level instance at scale `0.5` is exactly half of the authored scene size.
- A level instance at scale `1.0` matches the reusable scene.
- A level instance at scale `1.5` is exactly one-and-a-half times the reusable scene.
- No runtime method permanently recalculates sprite scale from texture dimensions.
- Temporary scale animation returns to the authored base without drift.
- Collision and interaction geometry remain aligned.
- Existing intentional instance variation in levels is preserved.

## Audit limitation

This is a source-level audit of the active reusable object families and concrete scene paths identified on the current `main` branch. Godot was not launched during this phase. Phase 2 must include editor/runtime checks because inherited-scene overrides and imported asset pivots can only be fully confirmed in the engine.
