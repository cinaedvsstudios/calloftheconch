# Cuttlefish tutorial hints

This feature owns the level-one cuttlefish helper, central hint text, invisible level triggers, ink presentation and one-shot save state.

## Add or edit hint text

Edit `tutorial_hint_library.tres`. Each definition has:

- `hint_id`
- live text
- display duration
- dismissal rule
- optional required action
- one-shot state
- ink scale

One-shot completion is stored in `CotcGameState.story_flags` as `tutorial_hint_<hint_id>` and is therefore included in normal saves.

## Place a hint marker

Instance `tutorial_hint_trigger.tscn` into the relevant level scene, position its `Area2D`, and set its `hint_id` to an ID from the central library. Entry side can be Auto, Left or Right.

The controller discovers only triggers owned by the currently bound level. It does not require an autoload.

## Ink video

Godot's built-in video player expects Ogg Theora. Place the converted loop at:

`res://assets/effects/inkloop.ogv`

The controller also accepts:

`res://assets/effects/black smoke rise.ogv`

Without either file, the cuttlefish and dissolving text still run, but the ink video is hidden and a warning is printed.

## Current action IDs

- `tail_flip`
- `speed_run`
- `conch`

These are completed from Hylas's existing action-started signals rather than by polling input.
