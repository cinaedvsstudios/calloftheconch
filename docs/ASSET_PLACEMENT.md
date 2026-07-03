# Prototype 0.1.4 asset placement

Keep original art, video, audio, source exports and backups outside the Godot project. Copy only runtime-ready files into these exact folders.

```text
assets/
  backgrounds/
    bg_pillars_city.jpg
    waterbg.jpg
  characters/
    hylas-swim_01.webp ... hylas-swim_07.webp
    hylas-speed_01.webp ... hylas-speed_06.webp
    hylas-conch1_01.webp ... hylas-conch1_06.webp
  effects/
    bubble_riser_field.ogv
    bubble-explosion.ogv
  ui/
    title.png
  audio/
    [main Call of the Conch menu track]
    Sea of Pillars Calm.mp3
    underwater_ambience.mp3
    swim_noise.mp3
    Super Conch_noise.mp3
    speed_noise.mp3
```

The active prototype loads only Ogg Theora `.ogv` files for video. `bubble_riser_field.ogv` is a looping, full-screen, black-background additive overlay. `bubble-explosion.ogv` is a one-shot black-background additive tail burst.

Static and frame-by-frame transparent assets can remain PNG or WebP. `PrototypeAssets.load_hylas_frames()` discovers all numbered Hylas frames automatically, so adding `_08`, `_09`, and later frames does not require a code edit.

No separate sprite-sheet crop or atlas setup is used. Keep transparent padding around all frames and retain a consistent waist/tail-root anchor when exporting new Hylas artwork.

Do not add `waterbgparalax.webp`, `mountainoverlay01.webp`, `mountainoverlay02.webp`, `mountainoverlay03.webp`, or `sandoverlay.webp` to the active scene yet. The planned layered-world pass will use those assets once their file dimensions and placement rules are finalised. `mountainoverlay02.webp` is specifically deferred until its vertical-flip conditions are defined.
