# Spec 003 — Interaction System & World Objects

**Status:** ready to implement
**Depends on:** 001 (stats), 002 (items & inventory)
**Consumed by:** 004 (combat targets), 005 (dialogue entry point), 006 (quest objects), 010 (village content)

## Scope

**In:** look-at targeting with a HUD prompt, a reusable Interactable component, world item pickups, lootable containers with a minimal transfer panel, hinged doors, load-doors between scenes (Morrowind-style interior cells), a Talk stub for NPCs, the `Game` autoload that owns persistent player identity, debug scene, tests. If 002 deferred the encumbered-speed-multiplier hookup, finish it here in the player controller.
**Out (later specs / backlog):** locks, lockpicking, and Security checks · item ownership and theft (crime spec, Phase 2) · depositing items into containers (comes with the real inventory UI) · telekinesis-style extended reach · seamless interiors · loot tables (containers are hand-authored for now) · real dialogue (005).

## Design

### Targeting & input

- A `RayCast3D` from the player camera, length `interact_range` from `BalanceConfig` (new constant, default **2.5**), reports the current `Interactable` under the crosshair. Nearest hit only; occluders block.
- New input action `interact` (default **E** / gamepad **X**). Input actions are added in project settings.
- HUD prompt (ugly-but-functional): `"<verb> <display_name>"` — e.g. "Take Flawed Gem", "Open Worn Chest", "Talk Hunald". Hidden when no target.

### Interactable component

`Interactable extends Node3D`, added as a child of any `CollisionObject3D`-based scene: `display_name: String`, `verb: StringName` ("take", "open", "use", "talk"), signal `interacted(by: Node)`, overridable `_interact(by: Node)`. Concrete objects subclass or connect. Every Interactable must have a non-empty `display_name` (runtime assert in debug builds).

### Persistent player identity — the architectural decision

The player *node* is instanced fresh in every scene; the player's *identity* is the pure-data resources from 001/002. A new autoload `Game` (**explicitly sanctioned — first and only autoload so far**) owns:

- `character_sheet: CharacterSheet` and `inventory: Inventory` — created once, handed to the freshly instanced player's `StatsComponent` / `InventoryComponent` on every scene load.
- `change_scene(scene_path: String, spawn_point: StringName)` — loads the scene, finds the `Marker3D` in group `spawn_points` whose name matches, instances the player there, injects the resources.
- **Boot/F6 fallback (amendment):** scenes never embed a player. On startup, if the current scene has no player but has a spawn marker named `default`, `Game` instances the player there through the same injection path as a real transition. Convention: every playable scene has a `default` spawn marker; scenes without one (2D debug scenes, the test runner) leave `Game` inert.

This means scene transitions are trivially safe (nothing to carry but two resource references), and save/load (007) becomes "serialize what Game holds." No other global state goes into `Game` without a spec saying so.

### World objects (v1 set)

| object | behavior |
|---|---|
| `WorldItem` (`scenes/world/world_item.tscn`) | exported `item: ItemDef`, `count: int`; verb "take"; on interact: add to player inventory, `queue_free()`. Placeholder mesh; per-item meshes later. |
| `WorldContainer` (`scenes/world/world_container.tscn`) | owns its own `Inventory` resource (002 reuse), contents authored in-editor; verb "open"; opens `container_panel.tscn`: item list, Take, Take All, Close. Take-only in v1. Contents persist while the scene is loaded. *(Amendment: named `WorldContainer`, not `Container` — Godot reserves `Container` for its built-in GUI class.)* |
| `HingedDoor` | verb "use"; toggles open/closed (simple rotation tween); blocks/unblocks nav later. |
| `TransitionDoor` | exported `target_scene: String`, `spawn_point: StringName`; verb "use"; calls `Game.change_scene(...)`. This is the Morrowind load-door: interiors are separate scenes. |
| `TalkStub` | verb "talk"; emits `talk_requested(npc_name)` and shows a placeholder line. Spec 005 replaces the guts, not the wiring. *(Amendment, spec 005: superseded by the def-driven `Npc` — the Interactable/talk-verb wiring is unchanged, but the consumer-less `talk_requested` signal and the `npc_name` export are gone; like `WorldContainer`, the NPC owns and opens its own panel.)* |

## Architecture

| file | role |
|---|---|
| `scripts/interaction/interactable.gd` | the component |
| `scripts/interaction/interaction_detector.gd` | camera raycast, `current_target`, `target_changed(target_or_null)`, `try_interact()` |
| `scripts/systems/game.gd` (autoload `Game`) | persistent identity + scene changes, as above |
| `scripts/world/world_item.gd`, `world_container.gd`, `hinged_door.gd`, `transition_door.gd`, `talk_stub.gd` | concrete objects |
| `scenes/ui/hud_prompt.tscn`, `scenes/ui/container_panel.tscn` | minimal UI |
| `scenes/debug/interaction_debug.tscn` (+ `interaction_debug_interior.tscn`) | a room with several pickups (include `sack_of_ore` to prove encumbrance), a stocked container, a hinged door, a transition-door pair into a second scene and back, a TalkStub NPC |

`BalanceConfig` addition: `interact_range: float = 2.5`.

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Targeting:** detector reports the interactable under the ray within range; `target_changed` fires exactly on change; beyond `interact_range` or behind an occluder, no target. Range sourced from `balance_config.tres`.
2. **Pickup:** interacting adds the exact item and count to the player inventory, frees the node, and updates encumbrance state (grabbing `sack_of_ore` flips the flag — full 001→002→003 integration).
3. **Container:** Take moves a single stack correctly; Take All empties it; remaining contents persist across close/reopen within the loaded scene; gold in containers is out of scope until barter (note in code).
4. **Doors:** hinged door toggles state; transition door round-trip (A→B→A) lands the player at the named spawn points.
5. **Persistence:** after a transition, the player's `CharacterSheet` and `Inventory` are the *same resource instances* — skill xp granted in scene A and items looted in scene A are intact in scene B.
6. **Talk stub:** emits with the NPC's display name.
7. If done here: encumbered movement uses `encumbered_speed_multiplier` (002).

## How to implement

One commit each: input action + Interactable + detector + HUD prompt → `Game` autoload + player injection refactor → WorldItem + tests → Container + panel + tests → doors + tests (incl. persistence test) → TalkStub → debug scenes. Full suite green before every commit. The `Game` refactor touches the existing debug scenes from 001/002 — update them to run through `Game` rather than breaking them.
