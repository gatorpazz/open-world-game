# Spec 019 — Persuasion & Disposition

**Status:** ready to implement
**Depends on:** 005 (`DialogueResponse`/`DialogueEvaluator` — the gate threads through `matches`/`pick_response`/`available_topics`; the panel applies the persuasion effect), 013 (`DialogueChoice` — the three moves are choice prompts, `choice_gated` commits), 015 (`FactionStanding.get_reputation` — the faction term; `NPCDef.faction` reads it), 016 (`BarterRules` `persuasion_factor` — the price nudge wires the pinned lever live; `spend_gold` for bribe beads), 017 (`BountyLedger`/`Game.bounty` — the ledger + `SAVE_VERSION`/migration pattern the disposition ledger mirrors; the `requires_bounty` threading the `requires_disposition` gate copies; `LockRules`/`Lockpicking` — the pure-chance + injected-roll shape the persuade roll reuses), 018 (`Game.notice.is_overcast` — the overcast disposition penalty; `Working` orchestrator the `Persuasion` orchestrator mirrors)
**Consumed by:** Phase 3 (disposition-reactive schedules/greetings; hearth-name intimacy on the reserved NPCs once the director ratifies; per-order faction charters deepen the faction term)

## Scope

**In:** the **disposition model** — `NPCDef.base_disposition` (+ optional `NPCDef.faction` for the reputation contribution, the second sanctioned `NPCDef` amendment) + a **`Game`-held per-NPC modifier ledger** (`Game.disposition` = `DispositionLedger`, **`SAVE_VERSION` → 7** + `_migrate_v6_to_v7`) + the **018 overcast penalty** (reads `Game.notice`) · pure **`DispositionRules`** (`scripts/social/`) — `disposition(base, faction_rep, modifier, overcast, config) -> int` (clamped) + `persuade_chance` (the `LockRules.pick_chance` analog) + `move_delta` + `bribe_cost` + `price_factor` · **persuasion attempts** — admire / intimidate / bribe as 013 choice prompts via a new `DialogueResponse.persuade: StringName` effect applied in `dialogue_panel._apply_effects` (beside `pay_fine`) through a **`Persuasion` orchestrator** (the `Theft`/`Working` analog: reads the sheet's `persuasion` skill, **rolls** `randf() < chance`, mutates `Game.disposition`, spends beads for bribe, flashes the HUD) · **disposition-gated dialogue** — `DialogueResponse.requires_disposition: int` + a trailing `disposition: int = 0` threaded through the evaluator (the exact `requires_bounty` seam) fed by `dialogue_panel._current_disposition()` · the **barter price nudge** — a disposition-derived `persuasion_factor` fed into `BarterRules.buy_price`/`sell_price` (the existing pinned 4th arg, wired live) · a `BalanceConfig` **Disposition** group · canon-packet persuasion prose · full GUT coverage.

**Out (later specs / backlog):**
- **The barter buy/sell split** → backlog. The director ruled **one symmetric factor** for v1 (the pinned `persuasion_factor`, wired live) — it slides the whole price scale with disposition rather than lowering buy *and* raising sell independently. A `buy_factor`/`sell_factor` split is a Phase-3 refinement (the acknowledged imperfection).
- **Hearth-name intimacy on the six reserved NPCs** → director-reserved taste (the canonically "illegible" stranger). 019 stays off those lines unless ratified — the 022 regard-give-back precedent.
- **NPC-disposition reactions beyond dialogue gates + prices** (greetings, schedules, combat aggro from low disposition) → Phase 3.
- **A persuasion mini-game / haggling** → rejected in 016; disposition is the whole social lever.

## Design

### Faithfulness rulings (director, 2026-07-23)

Canon grounds **admire** (hearth-name intimacy, first-dose hospitality), **intimidate** (threat / exposure / "unroofing"), and **bribe** (beads, tolls, the wash) as **prose customs, not a numeric scale** — there is no canon disposition number, reaction roll, or persuasion-skill flavor. 019 invents the number and *dresses* it in those customs (the reckoning-prose precedent: wear canon clothing, invent no apparatus). Rulings:

1. **Disposition = base + faction reputation + per-NPC modifier − overcast penalty, clamped 0..100.** The faction term reads `FactionStanding.get_reputation(NPCDef.faction)` (an NPC of a guild you stand well with likes you more); the modifier is the persistent per-NPC number persuasion moves shift; overcast (018) subtracts a flat penalty (the remarkable outsider unsettles everyone).
2. **The three moves roll to succeed** (Morrowind-faithful — the one place the social layer takes dice, alongside 017's lockpicking): `chance = f(persuasion skill, disposition, difficulty)`; success shifts the modifier up, failure does nothing (admire/bribe) or **backfires down** (intimidate). The pure `persuade_chance` + injected `randf()` roll mirrors `LockRules`/`Lockpicking` so it stays testable.
3. **Intimidate risks a lasting drop; bribe spends beads** ∝ the goodwill bought (and fails before the roll if the player can't pay). Admire is the safe, skill-cheap move; intimidate is the high-delta gamble; bribe buys odds with beads.
4. **One symmetric barter factor** (no buy/sell split for v1): disposition scales the existing `persuasion_factor` — a friendly merchant slides cheaper, a cold one dearer.

### Disposition model — `NPCDef` + `Game.disposition` + `DispositionRules`

- **`NPCDef.base_disposition: int`** (default `config.disposition_base_default`, e.g. 40) and **`NPCDef.faction: StringName`** (empty = no faction term). Both additive amendments; existing defs default to base-only, unchanged behaviour.
- **`DispositionLedger`** (`scripts/resources/disposition_ledger.gd`, the `BountyLedger` twin): `@export var modifier: Dictionary[StringName, int]`; `get_modifier(npc_id)` / `adjust(npc_id, delta)`. On `Game.disposition`, its own save section.
- **`DispositionRules.disposition(base, faction_rep, modifier, overcast, config) -> int`**: `clampi(base + roundi(faction_rep * config.disposition_faction_weight) + modifier - (config.disposition_overcast_penalty if overcast else 0), config.disposition_min, config.disposition_max)`. Pure — the panel and barter panel compose the inputs from `Game`.

### Persuasion moves — `persuade` effect + `Persuasion` orchestrator (`scripts/social/`)

- **`DispositionRules.persuade_chance(move, skill, disposition, config) -> float`**: `clampf(config.persuade_base + skill * config.persuade_skill_weight + (disposition - config.disposition_neutral) * config.persuade_disposition_weight - config.persuade_move_difficulty[move], 0.05, 0.95)`. (Intimidate is harder at high disposition — bullying a friend backfires; admire/bribe rise with rapport.)
- **`DispositionRules.move_delta(move, success, config) -> int`**: success → `config.persuade_gain[move]`; failure → 0 (admire/bribe) or `-config.intimidate_backfire` (intimidate).
- **`DispositionRules.bribe_cost(disposition, config) -> int`**: `config.bribe_cost_base + roundi(disposition * config.bribe_cost_per_disposition)` (buying goodwill off a friendly NPC costs more — diminishing returns).
- **`Persuasion.attempt(move, npc_id, actor) -> void`** (impure, `RefCounted`, the `Theft`/`Working` analog): read `actor.stats.sheet.skills.get(&"persuasion", 0)`; compute the live disposition; for bribe, `bribe_cost` and `spend_gold` first (HUD notice + return on fail); roll `randf() < persuade_chance`; `Game.disposition.adjust(npc_id, move_delta(...))`; flash the outcome on the HUD. `Game` keeps the mutation via the ledger it owns (the stash/bounty precedent).
- **Effect wiring**: `DialogueResponse.persuade: StringName` (empty = none; `&"admire"`/`&"intimidate"`/`&"bribe"`). Applied in `dialogue_panel._apply_effects` beside `pay_fine`, passing `_npc.id` and the player. A move is authored as a `choice_gated` commit sitting before its prompt (the 013 pattern): the prompt's replies are the three moves, each a choice → a topic → the commit carrying `persuade`.

### Disposition-gated dialogue — `requires_disposition` (the `requires_bounty` seam)

- **`DialogueResponse.requires_disposition: int`** (0 = no gate). In `DialogueEvaluator.matches`, a trailing `disposition: int = 0` param and `if response.requires_disposition != 0 and disposition < response.requires_disposition: return false`; threaded verbatim through `pick_response`/`available_topics` (beside `bounty`). Added to `is_unconditional()`.
- **`dialogue_panel._current_disposition()`**: composes `DispositionRules.disposition(_npc.base_disposition, Game.faction_standing.get_reputation(_npc.faction) if _npc.faction else 0, Game.disposition.get_modifier(_npc.id), Game.notice.is_overcast(config.overcast_threshold), config)` — the narrow, spec-sanctioned `Game` reads (the `_current_bounty` precedent). Fed into every `pick_response`/`available_topics` call beside `_current_bounty()`.

### Barter price nudge — the symmetric factor wired live

- **`DispositionRules.price_factor(disposition, config) -> float`**: `1.0 - (disposition - config.disposition_neutral) * config.disposition_price_swing` clamped to `[config.price_factor_min, config.price_factor_max]` — a friendly merchant (disposition > neutral) slides prices **down** (cheaper buys, the dominant player action), a cold one up. Symmetric: because the factor multiplies both `buy_price` and `sell_price`, goodwill also modestly lowers sell income — the acknowledged single-factor trade-off (the buy/sell split is backlog).
- **`barter_panel`** computes the factor once (the merchant NPC's disposition) and passes it into all four `BarterRules.buy_price`/`sell_price` call sites (lines 77/96/145/156), replacing the pinned `1.0`.

### `BalanceConfig` Disposition group

`@export_group("Disposition")`, all flat scalars (per-move values are `_admire`/`_intimidate`/`_bribe` fields, not a typed dict — matching the flat config style and dodging the typed-dict-literal parser gotcha): `disposition_base_default` (40), `disposition_min` (0), `disposition_max` (100), `disposition_neutral` (50), `disposition_faction_weight` (0.5), `disposition_overcast_penalty` (20), `persuade_base` (0.4), `persuade_skill_weight` (0.006), `persuade_disposition_weight` (0.004), `persuade_chance_min` (0.05), `persuade_chance_max` (0.95), `persuade_difficulty_admire` (0.0), `persuade_difficulty_intimidate` (0.15), `persuade_difficulty_bribe` (-0.1), `persuade_gain_admire` (6), `persuade_gain_intimidate` (12), `persuade_gain_bribe` (8), `intimidate_backfire` (10), `bribe_cost_base` (10), `bribe_cost_per_disposition` (0.4), `disposition_price_swing` (0.004), `price_factor_min` (0.8), `price_factor_max` (1.2). Every number config-sourced.

### Ripple check (why little else changes)

Additive. `Game.disposition` is one new save section (v6 saves migrate to v7 with an empty ledger). `NPCDef.base_disposition`/`faction` default to base-only — every existing NPC behaves as today until authored. The `requires_disposition`/`disposition` param defaults to 0 everywhere, so all existing `pick_response`/`available_topics`/`matches` calls are unaffected (the `requires_bounty` proof). The `persuade` effect is empty on every current response. The barter factor was already a pinned parameter — the four call sites change their argument, not their shape. The four `SAVE_VERSION`-guard tests flip 6→7 by design.

## Architecture

- **Content types:** `NPCDef` gains `base_disposition` + `faction` (amended). No new content-type file — the moves are dialogue data.
- **State:** `DispositionLedger` on `Game.disposition` (`scripts/resources/`), saved section, `SAVE_VERSION` → 7 + `_migrate_v6_to_v7`.
- **Pure logic:** `DispositionRules` (`scripts/social/disposition_rules.gd`) — all math, no `Game`, unit-tested directly.
- **Orchestrator:** `Persuasion` (`scripts/social/persuasion.gd`, `RefCounted`) — the one impure path, rolls + mutates `Game` + HUD, off the dialogue effect (calls-down from the panel).
- **Seam threading:** `requires_disposition` through the pure evaluator (the `requires_bounty` copy); `_current_disposition()` composes the live inputs in the panel.

## Acceptance criteria (GUT tests)

1. **Disposition math** (`test_disposition_rules.gd`): `disposition` sums base + weighted faction rep + modifier − overcast penalty, clamped to `[min, max]`; `persuade_chance` rises with skill and (for admire/bribe) disposition, is clamped `[0.05, 0.95]`, and is lower for intimidate at high disposition; `move_delta` returns the gain on success and 0 / −backfire on failure per move; `bribe_cost` rises with disposition; `price_factor` falls below 1 above neutral and is clamped.
2. **Ledger + save** (`test_disposition_ledger.gd` / `test_save_codec.gd` / `test_save_load.gd`): `adjust`/`get_modifier` round-trip; a save/load carries `"save_version": 7`; a **v6 payload (no `disposition`)** decodes to v7 with an empty ledger; a v1 payload chains v1→…→v7; a `SAVE_VERSION + 1` payload is still refused.
3. **Persuasion attempt** (`test_persuasion.gd`): a forced-success attempt shifts the NPC's modifier by the move's gain and persists across save/load; a bribe with insufficient beads fails before the roll and moves nothing; a failed intimidate lowers the modifier; the roll reads the `persuasion` skill. (Determinism: test `DispositionRules` directly for the math; drive `Persuasion` with skill/disposition set so `persuade_chance` clamps to 0.05/0.95 for a near-deterministic outcome, asserting the ledger + gold effects.)
4. **Disposition gate** (`test_dialogue_disposition.gd`): a `requires_disposition` response is hidden below the threshold and shown at/above it across `matches`/`pick_response`/`available_topics`; a 0 gate is always eligible; `is_unconditional()` is false for a gated response.
5. **Price nudge** (`test_barter_disposition.gd` or extend `test_barter_rules.gd`): `buy_price`/`sell_price` with a `price_factor` below 1 are cheaper than at 1.0; the factor composes from disposition through `price_factor`.

Not machine-validated (human / canon-keeper review): the persuasion prose (admire/intimidate/bribe wearing the hearth-name/threat/beads customs, staying off the reserved hearth-name lines), the disposition/move/price tuning, the social feel.

## How to implement

One commit each, full suite green (626 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 019 begins — the reading of strangers`)
2. `NPCDef.base_disposition` + `faction` + `DispositionRules` (the full math) + the Disposition config group + `test_disposition_rules.gd` (criterion 1). (`social: disposition math + the NPCDef amendment`)
3. `DispositionLedger` + `Game.disposition` + `SaveCodec` v7 + `_migrate_v6_to_v7` + flip the four guards + ledger/save tests (criterion 2). (`social: SAVE_VERSION 7 — the disposition ledger`)
4. `requires_disposition` threaded through the evaluator + `_current_disposition()` in the panel + `test_dialogue_disposition` (criterion 4). (`social: disposition-gated dialogue`)
5. The `persuade` effect + `Persuasion` orchestrator (admire/intimidate/bribe roll + bribe beads) + HUD strings + `test_persuasion` (criterion 3). (`social: admire, intimidate, bribe`)
6. The barter price nudge — `price_factor` fed into the four `BarterRules` call sites + `test_barter_disposition` (criterion 5). (`social: goodwill at the counter`)
7. Canon-packet pass → persuasion prose (a demo prompt on a Lastdoor NPC wearing the three customs) + `canon-keeper-reviewer` first. (`content: the three ways to move a stranger`)
8. Docs housekeeping — Decision Log rows + status + §4; CLAUDE.md focus. (`docs: spec 019 complete`)
