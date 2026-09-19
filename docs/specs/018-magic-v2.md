# Spec 018 — Magic v2 (Notice, Overcast & the License Teeth)

**Status:** complete (2026-07-23)
**Depends on:** 008 (`SpellDef`/`SpellLibrary`/`PlayerCasting` — the casting spine this amends; `min_skill` is the tier ladder the license gate reads; the `try_cast` mana-spend path notice hangs off), 015 (`FactionRules.is_chartered_under` / `Game.is_chartered_under` — the charter query this spec finally applies to casting; charter = member at ≥ `charter_rank`), 017 (`WitnessQuery.is_witnessed` — the observation query built once there and consumed here for witnessed unlicensed workings; `Theft`/`CrimeRules`/`Game.report_theft`/`BountyLedger`/`Game.bounty` — the orchestrator + ledger patterns this spec mirrors for casting; the `SaveCodec` migration chain this spec extends; Torrum's `the_reckoning` — a witnessed working's warden bounty settles there, no new dialogue)
**Consumed by:** 019 (persuasion & disposition — the overcast "permanently remarkable" social penalty deepens into disposition reactions; 019 owns NPC attitude), 022 (alchemy — no direct dep), 023 (enchanting-analog — priced in *this* spec's notice economy; a worked thing "holds regard"), 024 (creatures — creature casters are a later concern; player-only here as in 008)

## Scope

**In:** a **`NoticeLedger`** on `Game` — the personal, **never-clearing** notice ledger (**`SAVE_VERSION` → 5** + `_migrate_v4_to_v5`, chain v1→…→v5) · a **`SpellDef.license_order`** field (the aspect order that charters a working; empty = hearth-charm, free) + validator invariant (`min_skill == 0` ⟺ `license_order == &""`) · pure **`WorkingRules`** (`scripts/magic/`) — the unlicensed verdict + notice/bounty costs (mirrors `CrimeRules`) · a **`Working`** orchestrator (mirrors `Theft`) driven by a new `PlayerCasting.working_cast` signal (signals-up) and wired in the `Player`: an unlicensed working **always accrues notice**, and if **witnessed** (`WitnessQuery`, or always when overcast) additionally draws a **warden bounty** via `Game.report_working` (bounty + reputation dock — the first magic caller of the 017 bounty path) · the **overcast state** — derived from notice ≥ threshold, **permanently remarkable**: always exposed to the witness query, a one-time reputation dock on crossing, a HUD beacon · a **HUD notice bar + overcast beacon** (the `HudBars` mana/ward pattern) · a `BalanceConfig` **Notice** group · `data/spells` updated with `license_order` (Flamelash ordained-Flame, Greatroof chartered-Stone) · canon-packet HUD strings (regard/notice/overcast) · **amends 008** and **closes audit debt 2** · full GUT coverage.

**Out (later specs / backlog):**
- **Levitation + the tri-key** → explicitly **not queued** (lore-backed hook, Decision Log). This spec gates *aspect casting* on the charter (order business); levitation runs on the separate tri-key and is untouched.
- **Order factions to earn a casting charter** → Phase 3. The aspect orders (Flame/Stone/Tide) have **no `FactionDef`** and are canon **not joinable** (the vent-parishes' umbrella). So in v1 `is_chartered_under(<order>)` is always false and the outsider's higher magic is always unlicensed — the intended teeth. `license_order` ids (`flame_order`/`stone_order`/`tide_order`) ship as forward-compatible placeholders.
- **Roof-vs-open notice** → canon prices an open-air working higher ("spends the crossing's budget and the worker's notice both"); v1 has no roofed/open world data, so the **witness query is the exposure proxy**. Roof state is Phase 3 world production.
- **Overcast as NPC-disposition reaction** ("feared as contagion, sheltered as a question") → **019** owns disposition; v1 overcast ships the mechanical core (always-exposed + a reputation dock + the beacon), the social reactions are 019's.
- **Notice-priced enchanting** → **023** consumes this notice economy.
- **Elemental damage types, spellmaking, channeled/concentration, magic resistance, silence** → still the 008 backlog; untouched.
- **Dice-roll spell failure** → permanently rejected (008).

## Design

### Faithfulness rulings (director, 2026-07-23 — the_workings as the target)

1. **Notice accrues from unlicensed casting only.** A working above hearth-charm (`min_skill > 0`, i.e. a `license_order` is named) cast **without the charter** for its order is *unlicensed* → accrues notice. Hearth-charm (`license_order == &""`) and licensed casting are notice-free. Mana stays the per-cast cost (008, unchanged). *Canon carve:* the_workings says "every working spends notice"; the game reads that as the **exposure of unlicensed working** — a licensed caster's regard is the order's to hold, so it doesn't mark *them*. Keeps licensed play unpunished and makes notice the outsider's risk.
2. **Overcast is permanently remarkable.** Derived from notice ≥ `overcast_threshold` (notice never decreases, so overcast is permanent). Effects: the witness query treats an overcast caster as **always seen** (unlicensed workings can no longer be hidden — "the sky answers invitations"); a **one-time reputation dock** with the jurisdiction on crossing; a persistent **HUD beacon**. Deeper NPC reactions are 019.
3. **The charter gate is a soft notice-gate, not a cast-lock.** No charter never stops a cast — it makes the working unlicensed. Faithful (unlicensed working is possible, it just "makes the worker remarkable") and playable, and it resolves the no-order-faction data gap without locking the spellbook.
4. **A witnessed unlicensed working draws both ledgers.** Notice always (permanent, magical); a warden **bounty** additionally when witnessed (clearable, legal — settled at Torrum's `the_reckoning`, reusing 017 whole). Bounty and notice stay separate ledgers (Decision Log).

### The license seam — `SpellDef.license_order` (`scripts/resources/spell_def.gd`; content in `data/spells/*.tres`)

A working's *tier* is already the `min_skill` int (0/25/50 = hearth-charm/chartered/ordained — 008). 018 adds the **licenser**:

| field | type | meaning |
|---|---|---|
| `license_order` | StringName | the aspect order that charters this working; **empty = hearth-charm** (free, unlicensed by nature). Non-empty for chartered/ordained tiers. |

**Invariant (validator-tested): `min_skill == 0` ⟺ `license_order == &""`.** Hearth-charm is always license-free; every chartered/ordained working names its order. Aspect↔order mapping (canon, the_workings): **Flame → evocation, Stone → warding, Tide → mending**; order ids `flame_order` / `stone_order` / `tide_order`. Shipped content: **Flamelash** (`greater_bolt`, evocation, min_skill 50 → `flame_order`, ordained), **Greatroof** (`greater_ward`, warding, min_skill 25 → `stone_order`, chartered); the three hearth-charm starters (`minor_bolt`, `minor_mend`, `lesser_ward`) keep `license_order == &""`.

### Pure logic — `WorkingRules` (static, `scripts/magic/`, the `CrimeRules` shape)

- `is_unlicensed(spell: SpellDef, chartered: bool) -> bool` — `spell.license_order != &"" and not chartered`. Hearth-charm and a held charter are licensed; everything else above hearth-charm is not.
- `notice_cost(spell: SpellDef, config) -> int` — `config.notice_per_unlicensed_working` (flat in v1; tier-scaling by `min_skill` is a noted tuning lever, kept out to avoid a magic divisor).
- `working_bounty(spell: SpellDef, config) -> int` — `config.unlicensed_working_fine` (the warden fine for a *witnessed* unlicensed working; reuses the bounty ledger).
- `reputation_dock(config) -> int` — `config.crime_reputation_dock` (shared with `CrimeRules` — an offense is an offense).
- `ASPECT_ORDERS: Array[StringName]` const (`flame_order`/`stone_order`/`tide_order`) — the validator checks `license_order` is empty or one of these.

### Notice ledger + overcast — `Game.notice` (`scripts/resources/notice_ledger.gd`)

**`NoticeLedger extends Resource`** — `@export var notice: int = 0`; `get_notice()`, `add(amount)` (monotonic — no `clear`, unlike `BountyLedger`, the whole point), `is_overcast(threshold: int) -> bool` = `notice >= threshold`. Lives on **`Game.notice`**, wired exactly like `bounty`: built in `_ready`, reset in `start_new_game`, carried on `SaveState.notice`, restored in `_apply_load`.

**`Game.report_working(jurisdiction, bounty_amount, reputation_dock) -> void`** — mirrors `report_theft` (bounty + rep dock); the witnessed-working legal path. Game mutates its own state (the sanctioned pattern).

### The `Working` orchestrator + casting wiring (`scripts/magic/working.gd` + `player_casting.gd` + `player.gd`)

Mirrors `Theft` exactly. Casting stays where it is; enforcement rides **signals-up**:
- `PlayerCasting` gains `signal working_cast(spell: SpellDef)`, emitted at the end of `try_cast` after mana is spent and the effect dispatched (every successful cast — the orchestrator decides if it mattered). `PlayerCasting` reads no `Game` state — it just reports the cast up.
- `Player` connects `casting.working_cast` → `_on_working_cast(spell)` → `Working.report(self, spell)`.
- **`Working.report(actor: Player, spell: SpellDef) -> bool`** (static, returns witnessed):
  - `var chartered := Game.is_chartered_under(spell.license_order)` (empty order → treat as chartered/licensed; hearth-charm short-circuits).
  - if not `WorkingRules.is_unlicensed(spell, chartered)` → return false (licensed / hearth-charm — nothing accrues).
  - `var was_overcast := Game.notice.is_overcast(threshold)`; `Game.notice.add(WorkingRules.notice_cost(spell, actor.config))`; HUD "the working draws regard."
  - `var witnessed := Game.notice.is_overcast(threshold) or WitnessQuery.is_witnessed(actor, actor.get_parent(), actor.stats.sheet.skills.get(&"sneak", 0), actor.sneaking, actor.config)` — **overcast ⇒ always seen**.
  - if witnessed: `Game.report_working(Working.JURISDICTION, WorkingRules.working_bounty(spell, config), WorkingRules.reputation_dock(config))` + HUD "you were seen at the working."
  - if newly overcast (`not was_overcast and Game.notice.is_overcast(threshold)`): a one-time extra reputation dock + HUD "you are overcast."; the beacon lights.
  - `Working.JURISDICTION := &"wardens"` (the canon measurer/witness; the `Theft.JURISDICTION` precedent).
- After `Working.report`, `Player` refreshes the notice HUD.

### Overcast effects (v1 mechanical core)

1. **Always exposed** — `Working.report`'s witness check ORs in `is_overcast`, so an overcast caster's unlicensed workings are always witnessed (always fined). (Extending exposure to *theft* is a cross-system nicety left for later; 018 scopes it to workings.)
2. **A standing reputation hit** — the one-time dock on crossing (above); ongoing disposition is 019.
3. **The beacon** — a persistent HUD indicator while overcast (below).

### HUD — notice bar + overcast beacon (`scripts/ui/hud_bars.gd` + player HUD; `hud_notice.gd` strings)

- `HudBars` gains a **`$Notice`** ProgressBar (`max_value = overcast_threshold`), the `$Mana`/`$Ward` pattern, plus an **overcast beacon** indicator. A `bind_notice`-style hook isn't enough (notice lives on `Game`, not a signalling component), so the `Player` owns the bridge: `refresh_notice()` reads `Game.notice` and sets the bar + beacon, called in `_ready` (shows persisted notice on scene entry) and after each `working_cast`.
- `HudNotice` constants (canon-packet): `WORKING_NOTICED` ("The working draws regard."), `WORKING_SEEN` ("A warden saw the working."), `OVERCAST` ("You are overcast."). Terminology from the_workings (regard / notice / overcast); canon-keeper reviewed.

### `BalanceConfig` Notice group (`scripts/resources/balance_config.gd` + `.tres`)

A `@export_group("Notice")` (or extend Magic): `overcast_threshold: int` (e.g. 100), `notice_per_unlicensed_working: int` (e.g. 10), `unlicensed_working_fine: int` (e.g. 15). The reputation dock reuses `crime_reputation_dock`. Every number config-sourced.

### Save & migration — SAVE_VERSION → 5 (`scripts/systems/save_codec.gd`)

`const SAVE_VERSION := 5`; `"notice"` in `_ROOT_KEYS`; `SaveState.notice: NoticeLedger`; `notice_to_dict`/`notice_from_dict` (`{"notice": int}`, the simplest section); encode/decode + the section-dict + null guard; `_migrate_v4_to_v5(data)` seeds `notice = 0` + stamps `save_version = 5`; `_migrated` chains v1→v2→v3→v4→v5. The four `SAVE_VERSION`-guard tests flip `4 → 5` (`test_save_codec`, `test_save_load`, `test_player_casting`, `test_title_screen`).

### Ripple check (why little else changes)

Additive. `license_order` defaults empty, so every unedited spell is hearth-charm/licensed-free and casts as before; only the two licensed-tier spells gain teeth. `PlayerCasting.working_cast` fires on every cast, but `Working.report` no-ops for hearth-charm/licensed/charterless-but-empty-order — so the shipped hearth-charm starters are untouched. Notice is one additive save section (v4 saves migrate). The witnessed-working bounty reuses `Game.bounty` + Torrum's reckoning verbatim — no new dialogue. `is_chartered_under` was shipped-and-tested in 015 for exactly this caller.

## Architecture

| new file | role |
|---|---|
| `scripts/resources/notice_ledger.gd` | `NoticeLedger extends Resource` — the never-clearing notice int + `is_overcast` |
| `scripts/magic/working_rules.gd` | `WorkingRules` — pure unlicensed verdict + notice/bounty/dock costs |
| `scripts/magic/working.gd` | `Working` — the orchestrator: ties `WorkingRules` + `WitnessQuery` to the live game |
| `tests/unit/test_working_rules.gd` | the unlicensed verdict + cost math |
| `tests/scenes/test_working.gd` | unlicensed → notice; witnessed → bounty; overcast → always-seen + crossing dock |
| `tests/scenes/test_notice_save.gd` (or folded into `test_save_load`) | notice round-trips; v4→v5 migration |

**Modified:** `scripts/resources/spell_def.gd` (`license_order`) + `data/spells/greater_bolt.tres` · `greater_ward.tres` (the two licensed-tier defs) · `scripts/magic/player_casting.gd` (`working_cast` signal) · `scripts/player.gd` (`_on_working_cast` + `refresh_notice`) · `scripts/systems/game.gd` (`notice` + `report_working` + save wiring) · `scripts/systems/save_codec.gd` (v5 + `notice` section + `_migrate_v4_to_v5` + chain) + `SaveState` · `scripts/resources/balance_config.gd` + `data/balance/balance_config.tres` (Notice group) · `scripts/ui/hud_bars.gd` + the player HUD scene (`$Notice` bar + beacon) · `scripts/ui/hud_notice.gd` (working/overcast strings) · `tests/data/test_spell_defs.gd` (the `license_order` invariant) · the four `SAVE_VERSION`-guard tests (4 → 5) · `docs/specs/008-magic-v1.md` (amend — the deferred regard/overcast/license bullets close) · `docs/master-plan.md` · `CLAUDE.md`.

## Acceptance criteria (GUT tests)

1. **License content** (`test_spell_defs.gd`): every spell satisfies `min_skill == 0` ⟺ `license_order == &""`; a non-empty `license_order` is one of the known aspect orders; the two licensed-tier defs carry their canon order (Flamelash→`flame_order`, Greatroof→`stone_order`).
2. **Working verdict + costs** (`test_working_rules.gd`): `is_unlicensed` is false for a hearth-charm spell and for a licensed one (chartered true), true for a chartered/ordained spell with no charter; `notice_cost`/`working_bounty`/`reputation_dock` read the config.
3. **Notice on an unlicensed working** (`test_working.gd`): casting Flamelash with no charter (no order faction exists) raises `Game.notice` by `notice_cost`; casting a hearth-charm starter raises it by nothing; a hearth-charm cast is never a crime.
4. **Witnessed working → bounty** (`test_working.gd`): an unlicensed working with an NPC in range + LOS raises `Game.bounty(&"wardens")` by `working_bounty` and docks reputation; unseen, notice still accrues but no bounty.
5. **Overcast** (`test_working.gd`): once notice ≥ `overcast_threshold`, `is_overcast` holds; an overcast caster's unlicensed working is witnessed even with no NPC present (always exposed); crossing the threshold applies the one-time reputation dock exactly once.
6. **Notice + save** (`test_notice_save.gd` / `test_save_load.gd` + `test_save_codec.gd`): a save/load round-trip preserves `Game.notice` and the file carries `"save_version": 5`; a **v4 payload (no `notice`)** decodes to a v5 `SaveState` with notice 0; a **v1 payload** chains v1→…→v5; a `SAVE_VERSION + 1` payload is still refused.

Not machine-validated (human / canon-keeper review): notice/overcast/fine balance, the HUD notice-bar + beacon feel, the working HUD strings under the plain-meaning anchor, the "unlicensed outsider" difficulty in play.

## How to implement

One commit each, full suite green (571 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 018 begins — the license teeth`)
2. `NoticeLedger` + `Game.notice` + `report_working` + `SaveCodec` v5 + `_migrate_v4_to_v5` + chain; flip the four SAVE_VERSION guards; the `BalanceConfig` Notice group; notice save tests (criterion 6). (`save: SAVE_VERSION 5 — the notice ledger + v4→v5`)
3. `SpellDef.license_order` + the two licensed-tier `.tres` + `WorkingRules` + the `test_spell_defs` invariant + `test_working_rules` (criteria 1, 2). (`magic: the license seam — SpellDef.license_order + WorkingRules`)
4. `Working` orchestrator + `PlayerCasting.working_cast` signal + `Player` wiring (notice accrual + witnessed bounty) + `test_working` (criteria 3, 4). (`magic: unlicensed workings draw notice and, if seen, a bounty`)
5. Overcast — always-exposed in the witness check + the one-time crossing dock + the HUD notice bar/beacon + `Player.refresh_notice` (criterion 5). (`magic: the overcast state — permanently remarkable`)
6. Canon-packet pass on the working/overcast HUD strings + amend `docs/specs/008-magic-v1.md` (deferred bullets closed); `canon-keeper-reviewer` first. (`content: the working's regard — notice strings, canon-voiced`)
7. Docs housekeeping — master-plan Decision Log rows (the four rulings) + status + §4 row → complete + **audit debt 2 closed**; CLAUDE.md focus. (`docs: spec 018 complete`)
