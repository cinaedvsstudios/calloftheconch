# Call of the Conch Prototype — Changelog

## 0.1.4 — angled speed burst and Hylas shadow

- Added Shift + Up and Shift + Down burst inputs. These accelerate Hylas at a tuneable 75° angle toward his current facing side rather than rotating him to a straight 90° vertical pose.
- Kept Shift + forward horizontal burst and Shift + backward/no-direction brake behaviour unchanged.
- Made Shift-plus-direction input order tolerant: pressing Shift first and then a movement direction within the same hold can begin the intended burst.
- Added a subtle runtime drop shadow behind Hylas. It follows every swim, conch and speed frame without modifying source art.
- Added live debug controls for vertical burst tilt and Hylas shadow opacity/offset. These values are included in exported tuning JSON files.
- Adjusted tail-burst positioning during angled speed bursts so its centre tracks the rotated tail direction.
- Integrated the 0.1.3 Godot 4.7 tuning-panel startup repair into this standalone archive.
- Deferred the layered water/parallax/mountain/sand background system until the relevant source assets are supplied. `mountainoverlay02.webp` remains unused.

## 0.1.3 — tuning panel startup repair

- Fixed the Debug / Tuning panel failing as it built section headings in Godot 4.7.
- Replaced invalid runtime theme-property access with Godot’s `add_theme_color_override()` and `add_theme_font_size_override()` calls.

## 0.1.2 — tune and travel pass

- Enlarged the additive tail-bubble burst default from 170 px to 310 px and made the trigger spacing more visibly random.
- Added live `Debug / Tune Prototype…` controls under Pause. They adjust movement, current, burst, conch, animation, Hylas scale, camera, tail-bubble layout, timing and horizontal water-tile count.
- Added `Export Tuning JSON…`, which writes a portable settings file that can be reviewed and used to update project defaults later.
- Tiled width-scaled `waterbg.jpg` three times horizontally. Hylas starts in the centre tile and the camera can now travel through a wider open-water space.
- Added automatic discovery of `hylas-speed_XX.webp` / PNG frames. The future speed animation plays during burst and falls back safely to swim frames until present.
- Removed the empty legacy `scenes/` folder from the clean project package and documented why stale scene errors can remain when files are merged over an old project folder.

## Prototype 0.1.1 — movement and media pass

- Replaced height-scaled repeated water strips with width-scaled `waterbg.jpg` and vertical camera travel.
- Corrected the title background to use `bg_pillars_city.jpg`.
- Added current-aware idle drift, retained momentum, burst, brake, Normal Conch feedback, OGV bubble effects, and the F9 Developer/Admin Panel.
