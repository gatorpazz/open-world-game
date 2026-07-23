# Spec 025 — Save/load furniture (slots, pause menu, settings)

**Status:** ready to implement
**Depends on:** 007 (`SaveCodec`/`Game.save_game`/`load_game`/`save_path` — the slot layer wraps the versioned payload; the migration machinery, proven across v2→v7, takes its eighth bump here), 020 (`Game.clock` — day/bell metadata; the `_process` tick playtime rides), 009 (the title screen — Continue routes into the load menu), 005/012 (`JournalPanel`/`InventoryPanel` — the panel lifecycle the menus mirror)
**Consumed by:** Phase 2's exit audit (this closes the queue); Phase 3 (a richer settings surface; autosave if wanted)

## Scope

**In:** **save slots** — a `SaveSlots` helper over a `user://saves/` directory: a reserved **quicksave** slot (F5/F9 unchanged) + **~6 numbered manual slots**, each file a **metadata header** above the versioned `SaveCodec` payload (`{"meta": {...}, "save": <payload>}`); the legacy single `user://save.json` is **adopted as the quicksave slot** (back-compat) · **`Game.save_game(slot)`/`load_game(slot)`** taking a slot id (default quicksave), `list_slots()` reading each header cheaply · **metadata** — system timestamp, in-game day/bell (020), a prettified scene name, character level, and **playtime** (a new `Game.playtime_seconds` ticked in `_process`, joining the payload — the **eighth `SAVE_VERSION` bump → 8** + `_migrate_v7_to_v8`) · a **`SaveLoadPanel`** (the `JournalPanel` lifecycle) listing slots with their metadata, save-to-slot / load / delete · an **Esc pause menu** (`PauseMenu`: Resume / Save / Load / Settings / **Quit to Title**) replacing Esc's bare mouse-release · **settings** — a `Settings` helper over `user://settings.cfg` (`ConfigFile`) holding **mouse sensitivity + master volume**, loaded at boot and applied (Player look + the audio master bus), edited in a small `SettingsPanel` · title-screen **Continue** routes into the load menu (slot-aware) · full GUT coverage.

**Out (later specs / backlog):**
- **Autosave** → backlog (director picked quicksave + manual slots; no auto-write trigger this pass).
- **Named saves / free-text slot names** → backlog (numbered slots, no in-panel text entry).
- **A fuller settings surface** (keybinds, invert-Y, resolution, per-bus volumes) → Phase 3; v1 ships the two settings that have a live effect today.
- **Save thumbnails / screenshots** → backlog (metadata is text only).

## Design

### Faithfulness rulings (director, 2026-07-23)

Furniture, not fiction — no canon-packet (chrome text only, the 009 title-screen precedent). Rulings: **quicksave + ~6 numbered manual slots** (the legacy save adopted as quicksave); **metadata includes playtime** (the `SAVE_VERSION → 8` the queue timed this spec to ride, proving a migration alongside the slot menu); **an Esc pause menu** as the home for save/load/settings/quit-to-title; **settings = mouse sensitivity + master volume**.

### Save slots — `SaveSlots` + the wrapped file format

`scripts/systems/save_slots.gd` (static helpers over a base dir): `SLOT_IDS` = `&"quicksave"` + `&"slot_1"`..`&"slot_6"`; `slot_path(dir, slot_id)`; `write(dir, slot_id, meta, payload)` (writes `{"meta": meta, "save": payload}` as JSON); `read_payload(dir, slot_id)` (returns the versioned payload, tolerating a **legacy bare file** — `data.get("save", data)` — so an old `save.json` decodes); `read_meta(dir, slot_id)` (just the header, for the menu); `list_slots(dir)` (each `SLOT_ID` → meta or empty); `exists`/`delete`. **Legacy adoption:** on first slot access, if `saves/quicksave.json` is absent and a legacy `save.json` exists, it is moved in.

### `Game` — slot-aware save/load + playtime

- `saves_dir := "user://saves"` (tests point it at a scratch dir, the `save_path` precedent). `save_game(slot_id := &"quicksave")` builds the `SaveState`, encodes the payload, builds the **metadata** (below), and `SaveSlots.write`s the slot. `load_game(slot_id := &"quicksave")` reads the payload via `SaveSlots.read_payload`, decodes (unchanged), applies. `has_save()` = any slot exists.
- **`playtime_seconds: float`** — ticked in the existing `_process` (guarded to gameplay, beside the clock tick), reset in `start_new_game`, restored on load. Joins the `SaveCodec` payload (a new section — the ledger precedent): **`SAVE_VERSION → 8`** + `_migrate_v7_to_v8` (seed `0.0`), the chain v1→…→v8.
- **Metadata** built at save time: `{"saved": Time.get_datetime_string_from_system(), "day": clock.get_day(), "bell": clock.get_bell(), "scene": current_world.scene_file_path, "level": character_sheet.level, "playtime": playtime_seconds}` — display-only, outside the versioned payload (no bump for the header itself; playtime bumps because it also lives *in* the save state).

### The menus — `SaveLoadPanel` + `PauseMenu` + `SettingsPanel` (the `JournalPanel` lifecycle)

- **`PauseMenu`** — Esc opens it (pauses the tree, `process_mode = ALWAYS`); buttons Resume (close), Save (`SaveLoadPanel` in save mode), Load (`SaveLoadPanel` in load mode), Settings (`SettingsPanel`), **Quit to Title** (`Game.change_scene(MAIN_SCENE)`). Replaces the Player's `ui_cancel` mouse-release; F5/F9 quicksave stay.
- **`SaveLoadPanel`** — lists `SaveSlots.list_slots()`: each row shows the slot label + metadata (`Day N · bell M · <Place> · Lv <level> · <played>`) or "(empty)". A **mode** (save / load): save writes the selected slot (overwrite-confirm on a filled one), load reads it, delete clears it. Save mode hides the quicksave row's overwrite (quicksave is F5's); load mode lists all.
- **`SettingsPanel`** — mouse-sensitivity + master-volume controls bound to `Settings`; changes apply live and persist to `settings.cfg`.
- **Title screen:** Continue opens the `SaveLoadPanel` in load mode (slot-aware) instead of loading the lone save; disabled when no slot exists.

### Settings — `Settings` + `settings.cfg`

`scripts/systems/settings.gd`: `load()`/`save()` a `ConfigFile` at `user://settings.cfg` with `mouse_sensitivity` (float) + `master_volume` (0..1); `apply()` pushes sensitivity to the Player's look and volume to the `Master` audio bus. Loaded at boot (the title screen / `Game`), re-applied when a new Player spawns. `Player.mouse_sensitivity` reads from `Settings` (its `@export` default is the fallback).

### Ripple check

The versioned payload grows one field (`playtime_seconds`) → `SAVE_VERSION → 8`, the only migration. The save *file* grows a `meta` wrapper, but `read_payload` tolerates a bare legacy file, so old saves load; the legacy `save.json` is adopted as quicksave once. F5/F9 keep working (now `save_game(&"quicksave")`). The Player's Esc handler changes (pause menu instead of mouse-release); every other input is untouched. New UI scenes are additive. Settings default to today's values, so a missing `settings.cfg` changes nothing.

## Architecture

- **Save layer:** `SaveSlots` (`scripts/systems/`, static) + `Game` slot API + the `playtime` payload section (`SaveCodec` v8 + migration). No new autoload.
- **UI:** `PauseMenu`, `SaveLoadPanel`, `SettingsPanel` (`scenes/ui/` + `scripts/ui/`), all on the `JournalPanel` pause-lifecycle; the Player owns/opens the pause menu (the journal/inventory precedent).
- **Settings:** `Settings` (`scripts/systems/`) over `ConfigFile`, applied at boot + on Player spawn.
- **Save-neutral except the one field:** playtime is the sole new save state; slots + metadata + settings are file-layout / config, not game state.

## Acceptance criteria (GUT tests)

1. **Slots round-trip** (`test_save_slots.gd`): `write` then `read_payload`/`read_meta` recover the payload + metadata; `list_slots` reports filled vs empty; `delete` clears; a **legacy bare file** (no `meta` wrapper) still `read_payload`s (back-compat); legacy `save.json` is adopted as quicksave.
2. **Playtime + v8** (`test_save_codec.gd` / `test_save_load.gd`): a save/load round-trips `playtime_seconds` and carries `"save_version": 8`; a **v7 payload (no playtime)** migrates to v8 seeding `0.0`; a v1 payload chains v1→…→v8; a `SAVE_VERSION + 1` payload is refused; the four guard tests flip 7→8.
3. **Slot save/load** (`test_save_load.gd`): `save_game(&"slot_2")` then `load_game(&"slot_2")` restores state; `save_game()`/`load_game()` default to quicksave; `has_save()` reflects any slot; F5/F9 still quicksave.
4. **Metadata** (`test_save_slots.gd`): a saved slot's metadata carries the day/bell, scene, level, and playtime from the live game; the scene name prettifies.
5. **Settings** (`test_settings.gd`): `Settings.save` then `load` round-trips mouse sensitivity + master volume through `settings.cfg`; `apply` sets the master bus volume; a missing file yields the defaults.
6. **Menus** (`test_pause_menu.gd` / `test_save_load_panel.gd`): the pause menu opens on Esc and pauses; Resume closes; the `SaveLoadPanel` lists slots and its save/load/delete actions call the right `Game`/`SaveSlots` API; Quit to Title changes scene. (Scene tests, headless — no mouse-mode asserts.)

Not machine-validated: the menu layout/feel, the metadata formatting, the pause-menu flow (director playthrough).

## How to implement

One commit each, full suite green (680 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 025 begins — the save shelf`)
2. `Game.playtime_seconds` + the `_process` tick + `SaveCodec` v8 + `_migrate_v7_to_v8` + flip the four guards + round-trip tests (criterion 2). (`save: SAVE_VERSION 8 — playtime`)
3. `SaveSlots` + the wrapped file format + `Game` slot API + legacy adoption + metadata + `test_save_slots` + the `test_save_load` slot tests (criteria 1, 3, 4). (`save: numbered slots and their metadata`)
4. `SaveLoadPanel` (list + save/load/delete modes) + `test_save_load_panel` (criterion 6). (`save: the save/load menu`)
5. `PauseMenu` (Esc) + Quit to Title + wiring Save/Load + the Player Esc-handler change + `test_pause_menu` (criterion 6). (`save: the pause menu`)
6. `Settings` + `settings.cfg` + `SettingsPanel` + boot/spawn apply + title-screen Continue → load menu + `test_settings` (criterion 5). (`save: settings and the sensitivity/volume file`)
7. Docs housekeeping — Decision Log rows + status + §4; CLAUDE.md focus. **Phase 2 closes.** (`docs: spec 025 complete — Phase 2 done`)
