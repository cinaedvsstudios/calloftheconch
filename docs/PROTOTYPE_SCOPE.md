# Call of the Conch — Swim Prototype 0.1.4

This is intentionally a movement-feel test, derived from the v33 movement brief. It is not the full Neresithoppos vertical slice.

Implemented:
- F5 launches the Sea of Pillars title screen using `bg_pillars_city.jpg` and `title.png`.
- Start enters a water world where `waterbg.jpg` is width-scaled to 1280 px, then tiled three times left-to-right. Hylas starts in the centre tile and can travel vertically through the complete image as well as left/right across the tiled water.
- Hylas loads every numbered `hylas-swim_XX.png` or `.webp` frame automatically, including `hylas-swim_07.webp` when present.
- Hylas loads `hylas-speed_XX.png` or `.webp` automatically when present. Those frames play during every burst; ordinary swim frames remain the fallback until the speed files are added.
- Normal swim, retained momentum, current-aware idle drift and gentle sinking remain separate behaviours.
- Temporary keyboard Action A: Shift + forward horizontal movement bursts; Shift + backward/no movement brakes but leaves current drift intact. Shift + Up or Shift + Down bursts at a tuneable 75° angle toward Hylas’s current facing side.
- Temporary keyboard Action B: Space/J plays the Normal Conch with a visual forward range and cooldown.
- A subtle runtime shadow follows every Hylas frame; it is tuneable under Pause → `Debug / Tune Prototype…`.
- Full-strength additive `bubble_riser_field.ogv` bubble overlay.
- Larger full-strength additive `bubble-explosion.ogv` bursts over Hylas's tail while actively swimming.
- Escape pause and Return to Title.
- Pause → `Debug / Tune Prototype…` provides live movement, current, burst, conch, animation, Hylas shadow, camera, tail-effect and world-tile controls. `Export Tuning JSON…` writes the current values to a file you can send back for approval as the new defaults.
- F9 Developer/Admin diagnostics panel with copyable report.

Deferred:
- The new layered background system (`waterbgparalax.webp`, mountain overlays, sand overlay and collision silhouettes) will be added after the assets are supplied.
- City layout, current zones, enemies, food/Onos, collision routes, reflection, Whale Ground, pickups, shops, dialogue, health, campaign systems, and save-driven progression.

Temporary keyboard controls:
- WASD or arrow keys: swim
- Shift + current forward horizontal direction: fast horizontal burst
- Shift + Up / Down: 75° angled fast burst toward the current facing side
- Shift + backward horizontal direction, or Shift alone: brake
- Space or J: Action B placeholder — Normal Conch
- Escape: pause
- F9: Developer/Admin Panel

The intended final contract remains Action A = contextual interaction and Action B = Normal Conch. Shift/Space are prototype-only placeholders.
