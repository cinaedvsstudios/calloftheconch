# Call of the Conch — Prototype 0.1.4

A deliberately small Godot 4.7 movement/feel prototype using the v1.2 RootContext structure.

It includes:
- RootContext title → gameplay → title flow;
- Sea of Pillars city title background and title logo;
- one `waterbg.jpg` scaled to the fixed 1280 px game width and tiled three times left-to-right for horizontal plus vertical exploration;
- direct Hylas frame discovery with no atlas cropping;
- automatic support for `hylas-swim_07.webp` and `hylas-speed_01.webp` through `hylas-speed_06.webp` when those files are present;
- Shift + Up / Down burst angles at 75° toward Hylas’s current facing side; horizontal forward burst and backward/no-direction braking remain intact;
- a subtle tuneable runtime drop shadow that follows every Hylas frame;
- current-aware swim, retained idle momentum, gentle sink, burst, brake, Normal Conch feedback;
- full-strength additive OGV bubble overlay plus larger random additive tail bursts while swimming;
- Pause → Debug / Tune Prototype screen with live controls and JSON export;
- Escape pause / Return to Title;
- F9 Developer/Admin Panel with a copyable report.

Use a new empty project folder for this ZIP. It intentionally does not contain the old broken `title_screen.tscn` scene that referenced `res://scripts/ui/title_screen.gd`.

Before opening, ensure the runtime files listed in `docs/ASSET_PLACEMENT.md` are in this project. The media files below are not included because they were not present in the supplied prototype archive:

```text
assets/characters/hylas-swim_07.webp
assets/characters/hylas-speed_01.webp ... hylas-speed_06.webp
assets/effects/bubble_riser_field.ogv
assets/effects/bubble-explosion.ogv
```

Open `project.godot` from the separate `Call_of_the_Conch_Prototype` folder. Do not point Godot at the broader asset-library folder.
