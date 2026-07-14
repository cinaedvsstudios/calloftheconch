# Background Scenery

Reusable, drag-ready scenery scenes belong here.

The collision-ready rock, island, sand, beach and spike-rock collection is in:

`res://rebuild_v3/game/shared/background_scenery/landscape/`

Those scenes read the source texture alpha channel and generate collision only across visible image regions. Source artwork remains canonical under `res://assets/backgrounds/`; the library scenes do not duplicate the images.

Other scenery should follow the same rule: keep one canonical source asset and provide a ready `.tscn` wrapper when the piece needs collision, scripts or reusable configuration.
