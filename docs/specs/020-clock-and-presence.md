# Spec 020 — Clock & NPC Presence (real-time bells)

**Status:** complete (2026-07-23)
**Depends on:** 005 (`Journal` — the day-stamp this closes 005's deferral for; `JournalPanel` renders "Day N"), 007 (`SaveCodec` — this bumps it to v6 with its fourth migration; `Game`-held identity the clock joins), 003/004 (`Npc`/`Creature` — presence toggles `Npc` visibility; rest checks for hostile `Creature`s), 017 (the `StashContainer` world-station + narrow-`Game`-access precedent the bed reuses; `Game.report_*`/ledger-section save pattern the clock mirrors)
**Consumed by:** 019 (day-stamped journal + the clock are ambient; no hard dep), 021 (fast-travel — deferred to Phase 3 — will advance the clock per route), Phase 3 (high-sky season keys off the clock; NPC daily life deepens the schedule)

## Scope

**In:** a **`WorldClock`** resource on `Game.clock` — an absolute `day` + a `bell`-of-day, advanced in **real time** by `Game._process` (rate from `BalanceConfig`), emitting `time_changed` on each bell/day rollover · **`SAVE_VERSION` → 6** + `_migrate_v5_to_v6` (seeds a start time) · **journal day-stamps** — `Journal` records the circuit-day each entry was written, `JournalPanel` shows "Day N" (**closes 005's deferral**) · **presence-lite** — an `NPCSchedule` sub-resource on `NPCDef` (the sanctioned amendment); a scheduled `Npc` shows/hides on scene entry and on `time_changed`, absent = shop closed for free (no pathing, no save blob) · **rest** — a `rest` input for wilderness rest (blocked by nearby hostiles) + a **bed** world-station for settlements; resting advances the clock and restores health/stamina · a **HUD clock** (bell + circuit-day) · a `BalanceConfig` **Time** group · canon-packet clock/rest strings + a **time lore stub** (bells / the 9-day circuit) · full GUT coverage.

**Out (later specs / backlog):**
- **High-sky season** → later. Canon flags its mechanics ("sky-gates only, or the roads too?") as **director-open**; the clock exposes `day`, a season layer reads it in a Phase-3 spec.
- **Full hourly NPC waypoint life / pathing** → never in presence-lite (Decision Log: "Morrowind itself had stationary NPCs — period-authentic"). Presence is a binary present-window per scheduled NPC; no navmesh, no walking.
- **Real day/night lighting** → there is no sun underground (constant under-sun, "never sets and never rises"); the clock is **bells**, not light. No lighting changes.
- **Timed/scheduled quests, entry-aging bounties, spoilage** → later; the clock is the primitive they'll read.
- **Fatigue/hunger, sleep interruption events (Morrowind's "rest disturbed")** → later; v1 rest is a clean time-skip + heal.
- **Multi-window daily schedules** → v1 is one present-window per NPC (director ruling); richer routines are a Phase-3 content pass.

## Design

### Faithfulness rulings (director, 2026-07-23)

1. **The clock ticks in real time.** Time advances continuously as you play (`real_seconds_per_bell`), with rest to skip ahead — not discrete-on-action.
2. **Time is bells, not a sun.** The roofed world has no day-night sky (canon: the under-sun "never sets and never rises"). The clock reads in **bells** (canon gate-/market-/bell-hours) within a day and the **9-day circuit** (canon civic time, `the_beaching`). "Absent by night" = **shuttered between bells** (canon: `suddel` — "between bells the counter is shuttered"), not darkness. A short time lore stub grounds this.
3. **Rest is Morrowind-faithful.** In the **wilderness** you may rest anywhere via the `rest` key **unless a hostile creature is near**; in a **settlement** you need a **bed** (a rest-station). Resting **restores health and stamina** over the bells passed.
4. **Presence-lite, a few NPCs.** Each scheduled NPC has one present bell-window; a handful of Lastdoor NPCs get schedules as the demo, everyone else stays always-present.

### The clock — `Game.clock` (`scripts/resources/world_clock.gd`)

**`WorldClock extends Resource`** (the `NoticeLedger` single-section shape): `@export var day: int = 1` (absolute circuit-day, for stamps), `@export var bell: float = START_BELL` (bell-of-day). Pure helpers:
- `advance(bells: float, config) -> void` — adds to `bell`; while `bell >= config.bells_per_day`, subtracts a day's worth and `day += 1`. Deterministic, unit-tested.
- `get_day() -> int`, `get_bell() -> int` (floor), `circuit_day() -> int` (`(day - 1) % config.circuit_length + 1`, the 1–9 position).

**`Game.clock`** wired like `notice`/`bounty` — built in `_ready`/`start_new_game`, on `SaveState`, restored in `_apply_load`. **`Game._process(delta)`** advances the clock **only while a world + player exist** (so headless tests without a world don't drift) by `delta / config.real_seconds_per_bell` bells, and emits **`signal time_changed(day, bell)`** when the integer bell or the day changes (not every frame). (The clock pauses with the tree while a menu is up — acceptable v1.)

### Save & migration — SAVE_VERSION → 6 (`scripts/systems/save_codec.gd`)

`const SAVE_VERSION := 6`; `"clock"` in `_ROOT_KEYS`; `SaveState.clock`; `clock_to_dict`/`clock_from_dict` (`{"day": int, "bell": float}`, the `notice` single-section precedent + float/int coercion); `_migrate_v5_to_v6(data)` seeds `WorldClock.new()` (day 1, `START_BELL`) + stamps `save_version = 6`; `_migrated` chains v1→…→v6. The four `SAVE_VERSION`-guard tests flip `5 → 6`.

### Journal day-stamps (closes 005's deferral) — `scripts/resources/journal.gd`

`Journal` gains `@export var entry_days: Array[int] = []`, parallel to `entries` (order is still chronology; the day is the new fact). `add_entry(id, day := 0) -> bool` appends the day alongside the id. Callers with `Game` access pass `Game.clock.get_day()`: `DialogueEvaluator.apply_effects` gains a trailing `day := 0` the `DialoguePanel` fills; `JournalTrigger`/`WorldItem` pass `Game.clock.get_day()`. `save_codec.gd journal_to_dict`/`_from_dict` carry `entry_days` (absent in pre-020 saves → default to zeros, rendered "Day —"). `JournalPanel` renders **"Day N"** (or the sequence fallback for day 0) instead of "Entry N".

### Presence-lite — `NPCSchedule` on `NPCDef` (`scripts/resources/npc_schedule.gd`, `scripts/world/npc.gd`)

**`NPCSchedule extends Resource`** (a sub-resource in the `NPCDef.tres`, the `ItemStack`/`DialogueChoice` pattern): `@export var present_from_bell: int`, `@export var present_to_bell: int` — present when `from ≤ bell < to`. **`NPCDef` gains `@export var schedule: NPCSchedule`** (null = always present — the sanctioned amendment, the second after nothing; NPCDef otherwise stays minimal). `Npc` connects `Game.time_changed` and calls `_update_presence()` on scene entry + each rollover: hides the mesh + disables the `Interactable`/collision when absent (world-state-derived-from-clock — no save blob, the merchant live-rebuild fence). Content: a few Lastdoor NPCs (e.g. Suddel/Tansy counter windows) get schedules; the demo shows a counter shuttering between bells.

### Rest — the key + the bed (`scripts/player.gd`, `scripts/world/rest_point.gd`)

- A **`rest` input** → `Player.try_rest()`: wilderness rest. Blocked (HUD notice) when a **hostile `Creature`** is near or when the scene is **not** wilderness (settlements need a bed). A world scene declares wilderness via a group on its root (`&"wild_rest"`) — no per-scene script. Hostile detection is a **group query**: creatures join a `&"hostile"` group as they enter `CHASE`/`ATTACK` (a `Creature.state` setter maintains it), so `Player.hostiles_near()` never reaches into sibling creature state (signals-up, gdscript-conventions review).
- A **`RestPoint`** node (the `StashContainer` Interactable pattern) is the settlement **bed**: interacting rests the player directly (still blocked by nearby hostiles).
- **Rest is a fixed span, not a duration picker** (amended — no `RestPanel`): `Player.rest()` calls `Game.advance_time(config.rest_bells)` (the one clock-mutation API) + restores health **and** stamina by `config.rest_heal_per_bell × config.rest_bells` through the `StatsComponent` deltas. The advance emits `time_changed` (presence + HUD update). A "rest how many bells?" panel is backlog — the director's ruling (rest-in-the-safe-open / bed-in-town) needs no duration choice for v1, and a fixed restful span is the simpler seam.

### HUD clock (`scripts/ui/hud_clock.gd` + player HUD)

A small persistent HUD label bound to `Game.time_changed` showing the current **bell** and **circuit-day** (e.g. "Circuit-day 3 · 5th bell"). The `HudBars` bind precedent; refreshed on scene entry and each rollover.

### `BalanceConfig` Time group (`scripts/resources/balance_config.gd` + `.tres`)

`@export_group("Time")`: `bells_per_day: int` (12), `circuit_length: int` (9 — canon), `real_seconds_per_bell: float` (30 → a 12-bell day ≈ 6 min), `rest_heal_per_bell: float` (health+stamina restored per bell rested), `rest_bells: int` (8 — the fixed span a rest passes), plus a `WorldClock.START_BELL` const (a few bells into the day). Every number config-sourced.

### Ripple check (why little else changes)

Additive. `Game.clock` is one new save section (v5 saves migrate); the tick is guarded to gameplay so tests don't drift. `Journal.entry_days` defaults empty and back-fills to zeros for old saves — every existing journal read is unaffected (order is still chronology). `NPCDef.schedule` defaults null → every unscheduled NPC is always-present as today. The `rest` input + `RestPoint` + `HudClock` are new nodes; no existing flow changes. The four `SAVE_VERSION`-guard tests flip 5→6 by design.

## Architecture

| new file | role |
|---|---|
| `scripts/resources/world_clock.gd` | `WorldClock extends Resource` — day + bell, pure `advance` |
| `scripts/resources/npc_schedule.gd` | `NPCSchedule extends Resource` — a present bell-window |
| `scripts/world/rest_point.gd` | `RestPoint extends StaticBody3D` — the settlement bed |
| `scripts/ui/rest_panel.gd` + `scenes/ui/rest_panel.tscn` | `RestPanel` — pick bells → advance + heal |
| `scripts/ui/hud_clock.gd` + a HUD node | the bell/circuit-day readout |
| `docs/lore/rules/…the-telling-of-time.md` (stub) | bells / the circuit / ebbs |
| `tests/unit/test_clock.gd` | `advance` rollover, circuit-day |
| `tests/scenes/test_clock_save.gd` (or into `test_save_load`) | clock round-trips; v5→v6 |
| `tests/scenes/test_presence.gd` | an NPC hides/shows across its window on `time_changed` |
| `tests/scenes/test_rest.gd` | rest advances the clock + heals; blocked by hostiles / no-bed |

**Modified:** `scripts/systems/game.gd` (`clock` + `_process` tick + `time_changed` relay + save wiring) · `scripts/systems/save_codec.gd` (v6 + `clock` section + `_migrate_v5_to_v6` + chain + `entry_days` in the journal codec) · `scripts/resources/journal.gd` (`entry_days` + `add_entry(id, day)`) · `scripts/dialogue/dialogue_evaluator.gd` (`apply_effects` day param) + `scripts/ui/dialogue_panel.gd` (pass `Game.clock` day) · `scripts/world/{journal_trigger,world_item}.gd` (stamp the day) · `scripts/ui/journal_panel.gd` ("Day N") · `scripts/resources/npc_def.gd` (`schedule`) + `scripts/world/npc.gd` (presence) · `scripts/player.gd` (`rest`) + `project.godot` (`rest` action) · `scripts/ui/hud_notice.gd` (rest-blocked strings) · `scripts/resources/balance_config.gd` + `.tres` (Time group) · a Lastdoor interior/scene gets a `RestPoint`, a couple NPC defs get schedules, wild scenes join `&"wild_rest"` · the four `SAVE_VERSION`-guard tests (5→6) · `tests/*` journal tests (day-stamp) · `docs/master-plan.md` · `CLAUDE.md`.

## Acceptance criteria (GUT tests)

1. **Clock math** (`test_clock.gd`): `advance` rolls `bell` over into `day += 1` at `bells_per_day`; multi-day advances carry; `circuit_day` wraps 1..`circuit_length`.
2. **Clock save** (`test_clock_save.gd` / `test_save_codec.gd` / `test_save_load.gd`): a save/load round-trips `day` + `bell` and the file carries `"save_version": 6`; a **v5 payload (no `clock`)** decodes to v6 with the seeded start time; a **v1 payload** chains v1→…→v6; a `SAVE_VERSION + 1` payload is still refused.
3. **Journal day-stamp**: `add_entry(id, day)` stores the day parallel to the id; a round-trip preserves `entry_days`; a pre-020 journal dict (no `entry_days`) decodes with zero-days; the panel labels stamped entries "Day N".
4. **Presence** (`test_presence.gd`): a scheduled `Npc` is visible/interactable inside its window and hidden/inert outside it; toggling `Game.clock` across the boundary and emitting `time_changed` flips it; an unscheduled NPC is always present.
5. **Rest** (`test_rest.gd`): resting advances the clock by `config.rest_bells` and restores health+stamina by the config rate; the `rest` key is refused with a hostile creature near and refused in a non-wilderness scene; the bed `RestPoint` rests the player directly; both are refused near a hostile.

Not machine-validated (human / canon-keeper review): the clock/rest prose + the time lore stub under the plain-meaning anchor, the bell/circuit tuning, the presence and rest feel.

## How to implement

One commit each, full suite green (605 →) before each:

1. This spec + master-plan status/queue note (+ 021 deferral row). (`docs: spec 020 begins — the telling of time`)
2. `WorldClock` + `Game.clock` + `_process` tick + `time_changed` + `SaveCodec` v6 + `_migrate_v5_to_v6` + Time tunables; flip the four guards; clock + save tests (criteria 1, 2). (`clock: SAVE_VERSION 6 — the real-time bell clock`)
3. Journal day-stamps (`Journal.entry_days` + `add_entry(id, day)` + evaluator/caller threading + codec + panel) (criterion 3). (`clock: day-stamped journal entries — closing 005's deferral`)
4. `NPCSchedule` + `NPCDef.schedule` + `Npc` presence toggling on `time_changed` + a couple scheduled defs + `test_presence` (criterion 4). (`clock: presence-lite — the counter shutters between bells`)
5. The `rest` input + `RestPoint` bed + fixed-span rest (no `RestPanel`, amended) + wilderness/hostile gating + heal + `HudClock` + `test_rest` (criterion 5). (`clock: rest and the bell readout`)
6. Canon-packet pass → the time lore stub (`new-lore-entry`) + the clock/rest HUD strings + a `RestPoint` placed + scheduled-NPC content; `canon-keeper-reviewer` first. (`content: bells, the circuit, and a place to rest`)
7. Docs housekeeping — Decision Log rows + status + §4 (020 complete, 021 deferred); CLAUDE.md focus. (`docs: spec 020 complete`)
