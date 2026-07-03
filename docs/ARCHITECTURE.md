# Architecture guide

## The point of this template

This is not a demand that every Godot game becomes an enterprise application. The goal is to make the dependency direction obvious while still letting a game ship. Use more structure as a game grows; do not spend weeks “improving architecture” before a core mechanic is fun.

## Contexts

A context is a major part of the game with different rules, UI, inputs or required services. Typical examples are a main menu, a platforming game, a turn-based battle, or a base-management screen. `RootContext` owns switching among those contexts.

A new map, level, ocean zone or dungeon is usually **not** a new context if the player plays it under the same rules. Let `GameplayContext` own a level container and replace that child scene instead.

## RootContext: the composition root

`RootContext` is allowed to know about everything it has to assemble. It creates the persistent service graph and binds each context to only the services it needs. This is the intentional “high coupling” layer; it is small and easy to inspect.

Do not place normal gameplay mechanics here. “Player collected a shell” belongs in that feature. “The current game context requested a save” can reach RootContext through a local signal, because RootContext owns the save service.

## Service rules

A service is a persistent, functional object with a narrow job. In this template:

- `StateStore` owns the currently active `GameState` and informs direct consumers when it changes.
- `SaveService` reads/writes JSON files. It does not know what a player, coin or quest is.
- `SettingsService` stores player-facing configuration and applies audio/window settings.
- `AudioService` plays sound effects and owns sound-specific limits.
- `PauseService` changes the tree pause state. It does not decide which input should trigger pause.

Use direct references that RootContext injects rather than `get_node("/root/...")`. Do not replace one global service locator with a dictionary called `Services`; that has the same hidden-dependency problem under a friendlier name.

## Signal rules

Use a signal when a child reports something to its parent or when observers should react without owning each other. Put the signal on the smallest object that genuinely owns the event.

Good:

```gdscript
# A child declares its own event.
signal save_requested(slot_name: StringName)

# Its parent chooses the response.
_gameplay_context.save_requested.connect(_on_gameplay_save_requested)
```

Bad default:

```gdscript
# Any script can emit this; finding ownership becomes difficult.
GlobalSignalBus.player_collected_anything.emit(...)
```

Signals do not guarantee listener order. Where order matters, use one normal method that calls A, then B, then C.

## Feature folders

Once a game has real content, prefer this shape:

```text
features/
  treasure_chest/
    treasure_chest.tscn
    treasure_chest.gd
    treasure_chest_state.gd
    chest_open.ogg
    chest_closed.png
  whale_travel/
    whale_travel_context.tscn
    whale_travel_controller.gd
    travel_transition.webm
```

A feature can have internal dependencies. Dependencies across feature folders should be narrow and intentional. The more a feature can run or be tested without the rest of the game, the easier it is to change.

## State versus behaviour

`GameState` should be plain data plus serialisation helpers. It should not play audio, open menus or manipulate nodes. A controller/service performs behaviour and changes state through a focused API.

For larger games, split state by domain: `PlayerState`, `InventoryState`, `QuestState`, `WorldState`. `StateStore` can contain them or coordinate a save format. Do not put every transient animation timer into save data.

## When an autoload is still reasonable

Godot autoloads are not forbidden. Use one when it must exist before every scene, must persist across all scene changes, and its global access is an intentional advantage. Editor plugins may need them too.

For ordinary game code, start with a node owned by `RootContext` or the narrowest context. This makes launch order and dependencies explicit.
