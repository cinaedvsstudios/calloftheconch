# Obsolete gameplay wrappers

The inventory/audio/level-variant controller was temporarily split across several inheritance-only scripts. Godot failed to resolve that chain after the repository reorganisation.

The active gameplay controller now extends `gameplay_context.gd` directly and owns the equipment input, double-tap inventory, inventory audio and level-version selection in one file. Historical wrappers are retained here only as `.txt` records or remain in the rollback branches.
