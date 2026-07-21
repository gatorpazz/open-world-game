# Spec 007 — Save/Load (Serialize What Game Holds)

**Status:** ready to implement
**Depends on:** 001 (`CharacterSheet` — the sheet's fields are the save's sheet section; "save/load to disk" was 001's explicit deferral), 002 (`Inventory`/`ItemStack`/`ItemDef` — identity-by-reference is the serialization problem this spec solves; the validator's id==stem convention is the solution), 003 (`Game` autoload + spawn-point scene flow; amendment target: none — `Game` was built for this), 004 (`reload_current_scene` death flow; **amendment target: the stated caveat** "spec 007 replaces this with load-last-save"), 005 (`Journal` as the one durable world record), 006 (journal-derived quests/gates — the ruling that makes this spec small; `HudNotice` earmarked for "Game saved.")
**Consumed by:** 008+ (any spec adding a `Game` field must add it to the payload and bump `SAVE_VERSION` — the payload is now part of the sanction), 010 (playable slice ships with working quicksave), Phase 2 (settings persistence, save menu UI, and slots build on the codec), Phase 3 (the DoD's "save/load robust across versions within a release" lands on the `save_version` hook)

## Scope

**In:** `SaveCodec` pure dict↔resource codecs with a versioned JSON payload · `ItemLibrary` cached id→ItemDef loader (the missing third library) · `Game.save_game()`/`load_game()`/`has_save()` over `user://save.json` · scene path + player transform + head pitch persisted · current health/mana/stamina persisted through the payload · F5 quicksave / F9 quickload input actions · `HudNotice.GAME_SAVED` ("Game saved.") · death overlay's Reload becomes load-last-save with graceful fallback (**004 amendment**) · save-file security (never load resources from `user://`, `scene_path` allow-listed to existing `res://` scenes) · debug scene · tests.

**Out (later specs / backlog):** save slots, a save/load menu UI, timestamps, thumbnails (Phase 2 — the codec and single-file plumbing are the foundation; UI mirrors `JournalPanel` when it comes) · autosave on transition or timer (backlog — quicksave first; autosave is one `save_game()` call from wherever a spec wants it) · settings/options persistence (different file, different concern — not identity) · migration code (**the `save_version` equality check is the hook** — migration functions arrive with version 2, not speculatively) · persisting NPC/creature/world-object state (**the fence holds** — world state derives from the journal per 006's cell-reload ruling; restoring the journal restores the world, and a world-state blob would be a second source of truth) · multiple characters (one `Game`, one identity, one file) · saving while dead (unreachable — the tree pauses; stated so the absence of a guard isn't a silent gap) · an in-game clock / played-time stat (005's day-stamp ruling stands).

## Design

### One pure codec — the architectural decision

**Serialization is one static class, not methods on the identity resources.** `SaveCodec` (`scripts/systems/save_codec.gd`, RefCounted, all-static — the `CombatMath`/`QuestEvaluator` testability pattern) owns every dict↔resource conversion, the payload schema, `SAVE_VERSION`, and all JSON type coercion. The three identity resources stay persistence-ignorant pure data, exactly as 001/002/005 built them.

Decoding needs *resolvers* — ItemDefs by id, the BalanceConfig — and no Resource in this codebase calls `load()`; `CharacterSheet.setup()` *receives* its balance. The codec keeps that purity by taking resolvers as parameters: `decode_save(data, balance, items)`. Unit tests inject fabricated in-memory ItemDefs and never touch the disk (the `journal_override` injectability philosophy).

*Rejected alternative — `to_dict()`/`from_dict()` on each Resource:* spreads JSON coercion rules across three files, couples pure Resources to disk loaders, and scatters the future migration surface across the codebase. One codec file means version 2's migration has exactly one home.

**The payload (v1):**

```json
{
  "save_version": 1,
  "scene_path": "res://scenes/main.tscn",
  "player": {
    "transform": [1,0,0, 0,1,0, 0,0,1, 3.0,0.5,-2.0],
    "head_pitch": -0.31,
    "current_health": 42.5, "current_mana": 10.0, "current_stamina": 55.0
  },
  "sheet": { "attributes": {}, "skills": {}, "skill_xp": {}, "major_skills": [],
             "level": 1, "unspent_attribute_points": 0, "major_level_ups": 0 },
  "inventory": { "gold": 0, "stacks": [{"item": "iron_sword", "count": 1}],
                 "equipment": {"main_hand": "iron_sword"} },
  "journal": { "entries": [], "known_topics": [] }
}
```

| section | contents | notes |
|---|---|---|
| `save_version` | int | must equal `SaveCodec.SAVE_VERSION`; mismatch refuses the load (the migration hook) |
| `scene_path` | String | must begin with `res://`, carry a scene extension (`.tscn`/`.scn`), **and** exist — a tampered save can never load from `user://`, nor smuggle a non-scene resource into the scene changer *(Amendment, implementation: the extension check was added after review — "exists" alone accepted any `res://` resource and crashed downstream; an extension allow-list beats a `ResourceLoader` type hint, which is ignored for cached files)* |
| `player` | transform (12 floats: basis xyz axes then origin), head pitch, three current pools | pools live *here*, not on the sheet — the sheet derives maxes, the payload carries currents |
| `sheet` / `inventory` / `journal` | the three identity resources | items and equipment as **ids only**; `config` never serialized (reassigned from `res://data/balance/` on decode) |

**JSON coarseness, handled in one place.** `JSON.parse_string` returns String keys and float numbers. Every decode rebuilds into declared typed locals — `Dictionary[StringName, int]` built by looping with `StringName(key)`/`int(value)` — so the restored resources are byte-for-byte type-identical to freshly built ones. Array order is preserved by construction: journal chronology (order IS chronology, per 005) and `known_topics` order survive.

**Items round-trip by id.** Stacks encode as `{"item": "iron_sword", "count": 1}`, equipment as `{"main_hand": "iron_sword"}`; decode resolves through the items resolver. Godot's resource cache makes the decoded ItemDef reference-equal the canonical `data/items/` load — 002's identity-by-reference contract holds across a save/load cycle. **Unknown item id or unknown equipment slot: skip that stack/slot with a warning** — a content rename must not brick a save; the flip side (silent item loss) is a decision-log row.

**Decode is atomic.** `decode_save` validates everything and returns a fully built `SaveState` or null — never a half-restored state. `inventory_from_dict` assigns fields directly rather than replaying `add_item`/`equip` (which would re-run slot rules against already-valid state); the save was produced by those rules, so decode trusts it. Stated here so the bypass isn't a silent choice.

**Stated caveat:** JSON doubles vs 32-bit floats put ~1e-6 drift on the transform; the decoded basis is `orthonormalized()` and position error is sub-millimeter — invisible.

### ItemLibrary — the missing third library

`scripts/items/item_library.gd`: `static func get_items() -> Dictionary[StringName, ItemDef]` over `data/items/` via `ResourceLoader.list_directory`, cached, with `reset()` — byte-for-byte the `QuestLibrary`/`DialogueLibrary` shape. `test_item_defs.gd` already enforces id == filename stem, which is what makes id-keyed resolution sound. New `scripts/items/` folder, mirroring `scripts/quests/` and `scripts/dialogue/`. No new data validator — this spec ships zero content.

### Game owns the flow — no SaveManager, no new autoload

`Game`'s docstring has promised since 003 that "save/load (spec 007) serializes what this node holds." It gains `save_path` (var, `user://save.json` default — tests repoint it at a scratch file), `has_save()`, `save_game() -> bool`, `load_game() -> bool`, and the private `_apply_load`.

**`save_game`** — synchronous: guard (no `current_world`, empty `scene_file_path`, or no `player` → warn + false, the `reload_current_scene` guard shape); snapshot `current_world.scene_file_path`, `player.global_transform`, `player.head.rotation.x`, the three pools off `player.stats`, and the three identity resources; `JSON.stringify` (tab-indented — a save you can read is a save you can debug) → `FileAccess` write. The *caller* shows the notice; `Game` stays UI-free.

**`load_game`** — read, parse, `SaveCodec.decode_save(parsed, balance, ItemLibrary.get_items())`; any failure → warn + false with **`Game` untouched on every failure path** (decode fully, commit atomically). On success, defer `_apply_load` — F9 and the death overlay fire from handlers inside the very scene about to be freed, the same reason `change_scene` defers.

**`_apply_load`** — the commit point, end of frame:

1. Assign the three decoded resources onto `Game`.
2. `_change_scene_now(state.scene_path, &"default")` directly (already deferred). The fresh world's `JournalGate`s `_ready` against the just-restored journal — **006's cell-reload model pays off here: zero quest or world-state code in this spec.**
3. Same call stack, no frame in between — the spawn-marker positioning cannot win: apply `global_transform` and head pitch, then `stats.set_current_health/mana/stamina(...)`. The setters clamp and emit, so `HudBars` repaint; the components' `_ready` (which maxes pools) already ran inside `spawn_player`'s `add_child`.

*Rejected alternative — a SaveManager autoload or node:* autoloads are a last resort, and a second global owning serialization of the first global's fields is indirection with no second caller. The pure half lives in `SaveCodec`; the six lines of file I/O belong to the node whose state it is.

**Stated caveat:** quicksaving in the one-frame window of a deferred door transition saves the *old* scene. Self-healing on the next save; not guarded.

### Input, notice, death — the player-facing surface

- **`quicksave` (F5) / `quickload` (F9)** input actions; two branches in `Player._unhandled_input`. Save success → `show_notice(HudNotice.GAME_SAVED)`; load failure → `show_notice("No save to load.")`. Calls-down into the sanctioned autoload's own mutation API — the `TransitionDoor`/`DeathOverlay` precedent, not an ambient state read.
- **`HudNotice.GAME_SAVED`** (`"Game saved."`) joins `JOURNAL_UPDATED` — the reuse `hud_notice.gd` promised in 006.
- **Death overlay:** Reload becomes `if not Game.load_game(): Game.reload_current_scene()` — load-last-save with the exact 004 behavior as fallback when no save exists or the file is corrupt. The button relabels to "Load Last Save". **This closes 004's stated caveat — formal 004 amendment, same commit.** `reload_current_scene` survives as the fallback and the F6 debug path; its "007 replaces this" comment is rewritten to "fallback when no save exists."

## Architecture

| file | role |
|---|---|
| `scripts/systems/save_codec.gd` | `SaveCodec` + `SaveState` — pure codecs, schema, version + security checks |
| `scripts/items/item_library.gd` | cached id→ItemDef over `data/items/` |
| `scenes/debug/save_debug.tscn` (+ `save_debug_interior.tscn`) + `scripts/debug/save_debug.gd` | debug scene below |
| `tests/unit/test_save_codec.gd` | round-trip + refusal unit tests |
| `tests/unit/test_item_library.gd` | library unit tests |
| `tests/scenes/test_save_load.gd` | `Game`-level save/load scene tests |

**Modified:** `scripts/systems/game.gd` (`save_path`, `has_save`, `save_game`, `load_game`, `_apply_load`; docstring + caveat rewrites) · `scripts/player.gd` (quicksave/quickload branches) · `scripts/ui/hud_notice.gd` (`GAME_SAVED`) · `scripts/ui/death_overlay.gd` + `scenes/ui/death_overlay.tscn` (load-last-save + relabel) · `project.godot` (two input actions) · `tests/scenes/test_death_flow.gd` (fallback semantics + load-on-death) · `docs/specs/004-combat.md` (amendment note) · `docs/master-plan.md` + `CLAUDE.md` (housekeeping).

**Deleted:** none.

**`BalanceConfig` additions: none.** The save path and version are engine plumbing, not tuning. Third spec with an empty table, and that's still fine.

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Sheet round-trip (unit):** a mutated sheet (xp granted, level-up forced, attribute point spent) through `sheet_to_dict` → an *actual JSON string* → `sheet_from_dict`: every field equal, dictionary keys StringName, values int, `config` is the injected balance instance. Round-trips must pass through `JSON.stringify`/`parse_string` — that is what proves the String/float coarseness handling.
2. **Inventory round-trip (unit):** partial-stack order preserved (two part-stacks of one stackable id), gold, `ring_1` vs `ring_2` distinction, an equipped two-handed weapon; decoded items are *the same instances* as the resolver's defs; resolver is a fabricated in-memory dictionary — no disk.
3. **Journal round-trip (unit):** `entries` and `known_topics` order preserved exactly (order IS chronology).
4. **Transform + pools (unit):** 12-float round-trip within epsilon with an orthonormal decoded basis; full `encode_save`/`decode_save` carries `head_pitch` and all three pools.
5. **Refusal is atomic (unit + scene):** wrong `save_version`, non-Dictionary root, missing sections → null; unknown item id and unknown equipment slot → that stack/slot skipped with a warning, rest of the load intact; scene half — a corrupt file on disk → `load_game()` false and `Game`'s three resources are the same instances as before the attempt.
6. **ItemLibrary (unit):** loads exactly `data/items/`, keyed by id, cached across calls, `reset()` clears.
7. **Quicksave (scene):** `save_game()` writes the file and `has_save()` flips true; the no-world/no-player guard returns false and writes nothing; a `quicksave` input action through the player produces the file and a `HudNotice` child.
8. **Load restores the world (scene):** mutate (grant xp, add item, add journal entry, move, take damage) → save → mutate further → load → a *fresh* world instance whose `Game` resources are *new* instances equal to the save-point values (the post-save entry absent), player position ≈ the saved position, current health the saved value — not max.
9. **Death → last save (scene):** with a save present, the death overlay's button restores the save point; with none, it falls back to 004's default-spawn reload (existing `test_death_flow.gd` assertions hold on the fallback path).
10. **Security (unit):** a payload whose `scene_path` is `user://evil.tscn` (or any non-`res://`, nonexistent, or non-`PackedScene` path) decodes to null.

## How to implement

One commit each, full suite green before each.

1. `docs: spec 007 — save/load` — this document.
2. `items: ItemLibrary cached loader` — the library + unit tests (criterion 6).
3. `save: SaveCodec section round-trips` — sheet/inventory/journal codecs + typed-reconstruction unit tests (criteria 1–3, the unknown-id half of 5).
4. `save: full payload codec` — `SaveState`, `encode_save`/`decode_save`, transform helpers, version + scene-path security (criteria 4, 10, rest of unit-5).
5. `save: Game.save_game and load_game` — the `Game` methods + `_apply_load`; `tests/scenes/test_save_load.gd` on a scratch `save_path` (criteria 7–8, scene-5).
6. `input: F5 quicksave, F9 quickload` — actions, player branches, `GAME_SAVED` (the notice half of 7).
7. `ui: death reload becomes load-last-save` — overlay rewire + relabel + fallback; caveat-comment rewrites; **004 amendment note, same commit**; updated death-flow tests (criterion 9).
8. `debug: save debug scene + docs housekeeping` — the scene below; master-plan decision-log rows (unknown-id skip policy, the transition-window caveat); CLAUDE.md current focus → next spec.

**Debug scene** (`scenes/debug/save_debug.tscn`): a room with a `default` spawn; floor `WorldItem` pickups; a creature that hits back (pool divergence); a `JournalTrigger` landmark; a `TransitionDoor` pair into `save_debug_interior.tscn` and back; a live label dumping `has_save()`, the pools, position, and the journal tail. Manual checklist: pick up an item, take a hit, walk somewhere odd, F5 ("Game saved.") → move away, F9 → the exact spot, saved health, item held, entry present · F5 inside the interior, walk out, F9 → re-enters the interior at the saved spot · die with a save → the button lands at the save point · delete the file, die → degrades to the 004 default-spawn reload. Proves: the full loop — quicksave anywhere, quickload restoring scene, transform, pools, and identity through real JSON on disk; death folding into load-last-save; a missing save degrading gracefully.
