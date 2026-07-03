# Testing guide

Godot does not bundle a unit-test framework. Install either **GDUnit4** or **GUT** from Godot's AssetLib when the project has enough non-trivial logic to protect. This starter does not ship a frozen third-party plug-in copy.

Start by testing code that has no node tree dependency:

- save-data conversion in `GameState`
- inventory maths
- quest requirements
- hex-grid calculations
- cooldown logic
- procedural map generation

Then test controllers by injecting small fake dependencies. Do not try to automatically test “game feel”; playtesting remains the test for timing, controls, animation and fun.

The example in `gdunit_examples/test_game_state.gd.example` is deliberately an `.example` file, so the project opens cleanly before a test add-on is installed.
