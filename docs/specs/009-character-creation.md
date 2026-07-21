# Spec 009 — Character Creation Flow

**Status:** ready to implement
**Depends on:** 001 (the sheet contract: 7 attributes at `attribute_start`, one favored attribute at 40 per the "(40 in one attribute of the player's choice)" clause, exactly 5 major skills — this spec closes 001's "creation flow itself is a later spec" caveat), 002/005 (fresh `Inventory`/`Journal` as the rest of a new identity), 007 (`has_save`/`load_game` power the Continue button; `SaveCodec` already round-trips attributes + majors, so `SAVE_VERSION` stays 1 — the 008 no-new-Game-state rule), 011 (nothing consumed: the title/creation UI is chrome only — see the flavor-text caveat)
**Consumed by:** 010 (the narrative opening — the bait_square wake-up — wraps this flow: 010 decides what the player sees before/after the form; any flavor prose added then goes through the canon packet), Phase 2 (birthsign-analog perks or backgrounds would extend the form)

## Scope

**In:** a title screen boot scene replacing `main_scene` (New Game / Continue / Quit), a character-creation form (pick exactly 5 of the 12 skills as majors, pick one favored attribute, live derived-stats preview, Confirm/Back), a `BalanceConfig` favored-start value, static `list_skill_defs` + `build_creation_sheet` beside `build_default_sheet`, a sanctioned `Game.start_new_game(sheet)`, Continue gated on `Game.has_save()` with a corrupt-save notice, tests.

**Out (later specs / backlog):** the narrative opening and ANY flavor prose — title and form are UI chrome; **any future player-facing flavor text on these screens must go through the canon-packet skill (spec 011)** · a name field (no name on `CharacterSheet`; `SAVE_VERSION` stays 1; being name-less is itself canon — 010's problem) · races, birthsigns, portraits, appearance · class presets / recommended builds · attribute point-buy beyond the single favored pick · settings/options menu · save-slot management (one quicksave slot per 007) · an in-game route back to the title (boot-only in v1).

## Design

### Boot flow

- `project.godot` `run/main_scene` flips from `res://scenes/main.tscn` to `res://scenes/ui/title_screen.tscn`.
- `Game._ready` is untouched: it still builds the default sheet (the F6 debug fallback — every debug scene keeps working) and `_adopt_boot_scene` still runs. The title scene has **no** `spawn_points` marker, so `_adopt_boot_scene` sets `current_world` and returns without spawning — inert boot for free. Because `current_world` is set before the marker check (do not reorder that), the first `change_scene`/`load_game` frees the title scene through the existing managed-world machinery — no special-case code.
- **New Game** → hides the title column, shows the creation form. **Confirm** → `Game.start_new_game(sheet)` → the starting world at `&"default"`. **Back** → returns to the title column, selections preserved.
- **Continue:** `disabled = not Game.has_save()`, re-checked each time the title column shows. Pressed → `Game.load_game()`; on `false` (corrupt/unreadable file — decode-before-touch per 007) a notice Label shows "The save file could not be read." and the title stays up. No `HudNotice` here — that is an in-world overlay; one hidden Label is the whole mechanism.
- **Quit** → `get_tree().quit()`.
- Mouse stays `MOUSE_MODE_VISIBLE` throughout (set in `_ready`); no pausing — this is not an in-world overlay, so the journal-panel pause/capture dance does not apply. (Mouse mode is never asserted headless.)

### One scene, two states

`title_screen.tscn` is the single boot scene with two visual states — title column and creation form — swapped by `visible`. Deliberately NOT two scenes: `Game.change_scene` unconditionally spawns the player at a marker, so routing a title→creation transition through the sanctioned path is wrong by construction, and bypassing it would abandon `current_world` tracking. One scene also keeps picks alive across Back → New Game for free.

The form is a separately instanced scene (`creation_form.tscn`, hidden child) with its own script, so tests drive it in isolation with no `Game` in the loop. It is pure UI + selection state, talking to the world only via `confirmed(sheet)` / `cancelled`; `TitleScreen` wires those to `Game.start_new_game` and the state swap.

### The creation form

- **Majors picker:** 12 toggle-mode `Button`s in three archetype columns (Combat | Magic | Stealth — the 001 table's 4/4/4 split), labels from `SkillDef.display_name`, built at `_ready` from `StatsComponent.list_skill_defs()` — no hand-authored skill list anywhere in scene or script. A "Majors: n / 5" counter. At 5 selected, unchecked toggles disable; deselecting re-enables them.
- **Favored attribute:** 7 toggle `Button`s sharing a `ButtonGroup` (native radio behavior), one per `CharacterSheet.ATTRIBUTE_NAMES` entry, capitalized ids as labels (attributes have no Def resources; ids are the display contract, as in the stats debug scene).
- **Derived-stats preview:** four labels (Max Health / Mana / Stamina / Carry) recomputed on favored change from a scratch `CharacterSheet` holding config + attributes only. Makes the pick legible: endurance shows 80.0 health vs 65.0; intellect 60.0 mana vs 45.0. Stated quirk: favoring **presence** moves no derived stat yet (its payoff is persuasion, later) — the preview honestly shows no change.
- **Confirm:** `disabled = not can_confirm()`; on press builds the sheet via `build_creation_sheet` and emits `confirmed(sheet)`.
- **Direct-call API (the test surface — buttons route through the same methods):** `toggle_major(skill_id) -> bool` (false + unchanged when it would exceed 5 or the id is unknown), `set_favored(attribute) -> void` (replaces), `can_confirm() -> bool` (exactly 5 majors and a favored pick), `confirm() -> void` (no-op + `push_warning` when not confirmable — an exercised guard, never `push_error`).

### Sheet construction — pure logic home

`StatsComponent` gains two statics beside `build_default_sheet` (the precedent home for scene-free sheet building):

- `static func list_skill_defs() -> Array[SkillDef]` — the `data/skills/` enumeration factored out of `build_default_sheet` (which now calls it); also feeds the picker. No new library class for a directory listing with two callers.
- `static func build_creation_sheet(major_skills: Array[StringName], favored: StringName) -> CharacterSheet` — mirrors `build_default_sheet`: load balance, `setup(skill_ids, majors, balance)`, then `set_attribute(favored, balance.attribute_favored_start)`. Asserts favored is a real attribute; `setup` already asserts exactly 5 majors. The form's `can_confirm` gate means the statics are never called with invalid state — they stay strict.

### `Game.start_new_game` — the one sanctioned addition

Adopts the created sheet, resets `inventory` and `journal` to fresh instances (a new game is a whole new identity — `_ready`'s instances may have been dirtied by an earlier session), and enters `MAIN_SCENE_PATH` (`res://scenes/main.tscn`) at `&"default"`. No new `Game` fields — `SAVE_VERSION` stays 1; `SaveCodec` already persists attributes and the majors list faithfully with no default rebuild on load.

## Architecture

| file | role |
|---|---|
| `scenes/ui/title_screen.tscn` | boot scene: title column (New Game / Continue / Quit + notice Label), hidden `creation_form` instance. **No spawn marker — deliberately.** |
| `scripts/ui/title_screen.gd` | `TitleScreen extends Control` — state swap, Continue gating + notice, `confirmed` → `Game.start_new_game` |
| `scenes/ui/creation_form.tscn` | centered PanelContainer: header, three archetype columns of skill toggles, counter, favored ButtonGroup row, preview labels, Back/Confirm |
| `scripts/ui/creation_form.gd` | `CreationForm extends Control` — selection state, direct-call API, `signal confirmed(sheet)`, `signal cancelled` |
| `tests/scenes/test_creation_form.gd` | form suite (standalone, no Game) |
| `tests/scenes/test_title_screen.gd` | title-flow suite (Game snapshot/restore harness) |

**Modified:** `scripts/systems/stats_component.gd` (`list_skill_defs`, `build_creation_sheet`) · `scripts/systems/game.gd` (`start_new_game`, `MAIN_SCENE_PATH`) · `scripts/resources/balance_config.gd` + `data/balance/balance_config.tres` · `project.godot` (`run/main_scene`) · `tests/data/test_balance_config.gd`, `tests/unit/test_stats_component.gd`, `tests/scenes/test_game.gd` · docs (001 amendment, master-plan, CLAUDE.md).

`BalanceConfig` addition (group "Attributes"):

| constant | default |
|---|---|
| `attribute_favored_start` | 40 |

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Balance (data):** `attribute_favored_start` loads from `balance_config.tres`; `attribute_start < attribute_favored_start <= attribute_max`; a resource edit changes creation results with no code change.
2. **Sheet construction (unit):** `build_creation_sheet` puts the favored attribute at `attribute_favored_start` and the other six at `attribute_start`; the 5 picked majors start at `skill_start_major`, the other 7 at `skill_start_minor`; all 12 skills present; derived getters reflect the favored pick. `list_skill_defs` returns 12 defs deterministically; `build_default_sheet` behavior unchanged (regression).
3. **Form population (scene):** the form builds 12 toggles grouped 4/4/4 by archetype with `display_name` labels and 7 favored options — all sourced from `data/skills/` and `ATTRIBUTE_NAMES`, no hardcoded lists.
4. **Selection gating (scene):** `can_confirm()` false initially, false at 5 majors without favored, false at favored with <5 majors, true at exactly 5 + favored; a 6th `toggle_major` returns false and changes nothing (unchecked buttons disabled at 5); deselecting re-enables; `set_favored` replaces.
5. **Confirm (scene):** a valid `confirm()` emits `confirmed` exactly once with a sheet matching the picks (favored value, a major at 25, a minor at 5); an invalid `confirm()` emits nothing.
6. **Preview (scene):** favoring endurance shows max health `health_base + attribute_favored_start × health_per_endurance` vs the unfavored value — both read from the balance resource, not literals.
7. **start_new_game (scene):** adopts the passed sheet (`player.stats.sheet` is the same instance after spawn), replaces `inventory`/`journal` with fresh instances, enters `main.tscn` at `&"default"` in the sandboxed `world_parent`, pools full.
8. **Title flow (scene):** Continue disabled with no file at `save_path`, enabled with one; a corrupt file → `load_game()` false, the notice Label visible, no scene change; New Game shows the form; `cancelled` returns to the title column with the notice hidden.
9. **Boot inertness (scene):** `title_screen.tscn` instantiated contains no node in group `spawn_points`; `ProjectSettings` `application/run/main_scene` is the title scene.
10. **Persistence (scene):** after `start_new_game` with a created sheet, a `save_game`/`load_game` round-trip restores the favored attribute and chosen majors exactly — `SaveCodec` untouched, `SAVE_VERSION` still 1.

## How to implement

One commit each, full suite green before each: spec doc + 001 amendment italics → `attribute_favored_start` in BalanceConfig + `.tres` + coherence tests → `list_skill_defs` factor + `build_creation_sheet` + unit tests → `Game.start_new_game` + `MAIN_SCENE_PATH` + test_game coverage → CreationForm scene/script + form tests → TitleScreen scene/script + `run/main_scene` flip + title tests + created-sheet save round-trip → docs housekeeping (master-plan row + Current Status, CLAUDE.md Current focus).

**No debug scene** — the title screen is itself F6-able and is its own manual-test surface; every existing debug scene keeps working through `Game._ready`'s untouched default-sheet fallback.

**Manual pass:** F5 boots to the title; Continue greyed with no `user://save.json`; New Game → Confirm stays disabled until 5 majors + a favored pick; favoring intellect visibly raises the mana preview; Confirm drops into main.tscn with the chosen sheet (majoring no magic school → all schools at 5, only tier-0 workings castable); save, quit, relaunch → Continue restores; corrupt the save file → Continue shows the notice and stays put; F6 `stats_debug.tscn` still boots on the default sheet.
