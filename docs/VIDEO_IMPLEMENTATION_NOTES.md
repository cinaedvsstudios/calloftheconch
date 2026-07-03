# Architecture-video implementation map

This starter deliberately takes the useful ideas from the architecture review and turns them into project files rather than leaving them as abstract advice.

| Practice | Implemented here | Practical rule |
|---|---|---|
| Static typing + warnings | `project.godot`; typed fields/parameters/returns throughout `app` and `core` | Treat warnings as things to understand, not decoration to hide. |
| Segregated game state | `core/state/game_state.gd`, `state_store.gd` | State is serialisable data; services/controllers change it. |
| Context-based hierarchy | `app/RootContext.tscn`, `app/contexts/` | Major rule-sets get contexts; ordinary levels stay beneath gameplay. |
| Dependency injection | `RootContext.bind_dependencies(...)` calls | Parents create and pass exact dependencies; children do not search `/root`. |
| Replace global event hub | Signals in `MenuContext`, `GameplayContext`, `StateStore`, services | Put each event on its narrowest sensible owner. |
| Feature encapsulation | `app`, `core`, `shared`, plus feature-folder rules in `ARCHITECTURE.md` | Keep a feature's scene, code, data and runtime assets together. |
| Automated-test readiness | `tests/README.md`, `tests/gdunit_examples/` | Test pure logic first; add GDUnit4/GUT only when complexity justifies it. |

## Intentionally not copied blindly

- No huge framework, base class pyramid, or generic “everything manager.”
- No default global service-locator dictionary.
- No global SignalBus containing every event in the game.
- No mandatory test add-on bundled at an arbitrary old version.
- No rule that every map needs a new context.

The result is a stronger starting point, but still small enough to replace or simplify for a short game.
