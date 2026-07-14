# Landscape scenes

This folder contains drag-ready landscape scenes with collision polygons baked into each saved `.tscn`.

The polygons were traced from the visible texture alpha at a threshold of `0.12`, simplified, centred to match the Sprite2D, and saved as ordinary CollisionPolygon2D children. Transparent regions do not receive generated collision.

There is no editor-running or runtime collision generator attached to these scenes. They can be opened, inspected, moved, rotated and scaled directly in Godot.

Included: rock02–rock15, rock_corner, island00–island03, spike_rock, sand01–sand02 and beach. `island02.tscn` deliberately references the existing misspelled source asset `lsland02.webp`.
