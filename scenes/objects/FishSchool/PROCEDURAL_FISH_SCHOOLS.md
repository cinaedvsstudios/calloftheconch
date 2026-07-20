# Procedural Fish Schools

Drag-ready scenes:

- `fish_school_procedural_10.tscn` — loose ribbon formation, 10 fish
- `fish_school_procedural_15.tscn` — directional wedge formation, 15 fish
- `fish_school_procedural_20.tscn` — dense elliptical shoal, 20 fish

All three use `procedural_fish_school.gd` and the individual textures:

- `res://assets/objects/1fish.png`
- `res://assets/objects/2fish.png`
- `res://assets/objects/3fish.png`
- `res://assets/objects/4fish.png`
- `res://assets/objects/5fish.png`

The school root travels as one terrain-safe object. Fish inside it maintain formation targets, avoid overlapping, sway independently, make occasional individual darts and periodically compress into a synchronized group dart. Conch hits push the whole school and briefly scatter the internal fish. Existing current-receiver and camera-distance activation hooks are retained.

These schools deliberately use a small CPU-driven set of `Sprite2D` children instead of the thousands-of-identical-meshes particle approach. That keeps the five different source textures, formation control and individual dart timing easy to tune. A GPU particle or MultiMesh renderer would become worthwhile only if levels eventually contain hundreds or thousands of simultaneously visible fish.

The five PNG files must exist in the repository before another machine can open these scenes without missing-resource errors.
