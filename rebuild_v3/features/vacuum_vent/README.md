# Vacuum Vent Pair

A locally owned paired traversal feature for underwater levels.

## Drag-ready scene

Use:

`res://rebuild_v3/features/vacuum_vent/vacuum_vent_pair.tscn`

After placing the pair, move its `Intake` and `Output` child roots independently. Rotate either child to rotate its local field. Rotating `Output` changes the ejection direction.

The standalone scenes remain reusable building blocks:

- `vacuum_vent_intake.tscn`
- `vacuum_vent_output.tscn`

The intake alone only emits a local `capture_requested` signal. The pair owns transport and links that intake to its sibling output.

## Behaviour

- The intake uses `res://assets/backgrounds/vent2.webp`.
- `vent2.ogv` is sampled with vertically reversed UVs so bubbles travel down toward the mouth.
- A separate procedural additive whirlpool overlays the reversed bubbles.
- The suction field widens away from the mouth, pulls toward the centre, and adds a mild spiral.
- Ordinary swimming and ordinary Speed Run can resist the outer field.
- Active Tridacna Surge reduces suction to 35 percent.
- Active Conus wall-climbing ignores suction and capture.
- Entering the inner capture area temporarily removes control, collision, shadow and item visuals.
- Hylas spirals inward, shrinks and darkens, then is moved to the linked output.
- Camera smoothing is temporarily disabled and reset so the camera does not travel across the whole map.
- Hylas emerges along the output's local upward direction.
- The output remains a functional strong Vent 2 after transport.
- A one-second Hylas-local timestamp lock prevents immediate capture by this or another vacuum intake.

## Ownership and dependencies

- No autoload or global signal bus is used.
- `VacuumVentPair` owns the route and transition lifecycle.
- `VacuumVentIntake` owns only suction, local capture detection and its visual playback.
- `VacuumVentOutput` extends the existing reusable vent controller and exposes typed ejection queries.
- Hylas is accessed only through existing focused methods and named presentation nodes.
- The temporary recapture lock is runtime metadata on the live Hylas node; it is not persistent state.

## Save impact

None. Pair position and rotation are level content. No route state is saved.

## Diagnostics

The pair, intake and output expose `get_debug_lines()` with transport state, active receivers, pending capture count, suction values and output direction.

## Manual smoke test

1. Place `vacuum_vent_pair.tscn` in a gameplay level.
2. Move Intake and Output far apart and rotate Output diagonally.
3. Verify intake bubbles visually move toward the vent mouth.
4. Verify the blue whirlpool narrows into the mouth and remains transparent over the level.
5. Approach the outer suction field with ordinary swimming and ordinary Speed Run.
6. Confirm pull increases near the mouth and Hylas centres/spirals inward.
7. Enter the capture circle and confirm control and collision are temporarily disabled.
8. Confirm the camera snaps to Output rather than scrolling across the level.
9. Confirm Hylas emerges along Output's rotation and the normal output stream continues pushing him.
10. Confirm another nearby intake cannot immediately recapture Hylas for one second.
11. Repeat while Tridacna Surge is active and confirm the outer pull is substantially weaker.
12. Repeat while actively Conus-climbing and confirm suction/capture is ignored.
13. Pause during suction and during the transition to confirm normal scene-tree pause behaviour.
14. Check the Godot debugger for parser, missing-resource, physics-signal or invalid-node errors.
