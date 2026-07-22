# Spec 015 — Faction System

**Status:** ready to implement
**Depends on:** 003 (the `Game` autoload the numeric layer lands on), 005 (the `Journal` + `DialogueResponse` effect that membership rides today; the `DialogueEvaluator`/`DialoguePanel` the join retrofit amends), 007 (the `SaveCodec` this spec bumps to v2 and gives its first migration), 013 (the `DialogueChoice` prompt mechanism the join commits retrofit into)
**Consumed by:** 017 (crime docks per-faction reputation — the currency this spec makes able to go *down*), 018 (`is_chartered_under()` gates the 008 casting tiers), 019 (persuasion reads reputation; NPC faction tags land there when consumed), 025 (the save-slot furniture floats after this first `SAVE_VERSION` bump so migration and menu land proven together)

## Scope

**In:** a `FactionDef` content type + `FactionRank` sub-resource (the Golden Rule triple) · three faction defs re-surfacing the joinable guilds (`wardens`, `licensed_crews`, `reciters`) · a `FactionStanding` resource on `Game` holding per-faction reputation + rank, injected and serialized like the journal · a pure `FactionRules` (static, resolver-injected) owning `reconcile` / `can_advance` / `is_chartered_under` / `blocks_joining` · a `FactionLibrary` folder scanner · **the first `SAVE_VERSION` bump (1 → 2)** and **the first `SaveCodec` migration function** (`_migrate_v1_to_v2`, seeding faction records from a v1 save's `joined_*` journal entries) · the 013-style choice-prompt retrofit of the two named join commits (`take_the_cord`, `the_roofed_cache`) · `game_ids:` lore bridges from the guild entries to the new `faction:<id>` ids · full GUT coverage (data validator, two unit suites, migration test, join scene test).

**Out (later specs / backlog):**
- **`NPCDef` gets no faction field** — reputation is per-faction on `Game`; an NPC needs a faction tag only when disposition/reactions read it (**director ruling: build-when-consumed — 019/017**). The NPC fence (spec 005) stays closed here.
- **No reputation mutation** — crime docking (017) and persuasion reads (019) are the callers; within 015 standing is a pure function of the journal. The `adjust_reputation` setter ships and is unit-tested, but nothing calls it yet.
- **No promotion conversations / rank-up UI** (**director ruling: system + join retrofit only**) — `can_advance` ships and is tested; multi-rank advancement dialogue is a later content spec.
- **The charter is applied to nothing here** — 015 owns charter *state* + the `is_chartered_under()` query; 018 (magic v2) applies it to casting alongside notice-cost (the license-teeth split, Decision Log).
- **Exclusivity content stays permissive** — the `rivals` field + `blocks_joining` query ship, but every def's `rivals` is empty (**director ruling: independent, mechanism-ready**). All three guilds stay joinable in parallel, matching the shipped "every guild courts the outsider" ruling.
- **The Reciters join (`the_reading`) is not retrofitted** — 013 named only `take_the_cord` and `the_roofed_cache`; whether `the_reading` also becomes a choice prompt for symmetry is a **director content call**, flagged not silently taken.

## Design

### The problem (ground truth from the shipped data)

"Faction membership" today is one `StringName` in `Journal.entries`: `joined_the_wardens`, `joined_the_licensed_crews`, `joined_the_reciters`. It is written by a `DialogueResponse.journal_entry` effect (Torrum's `resp_torrum_join_stood` in `take_the_cord.tres` sets `joined_the_wardens` and hands a sword) and read by `requires_journal` / `blocked_by_journal` gates. A journal entry is a boolean that only goes *up*. Phase 2 needs a value that can go **down** (crime docks it — 017), that carries **rank** with thresholds, and that expresses a **charter** (the license 018 gates casting on). None of that fits a journal entry; pure journal-derivation would need baroque `offended_*` counter-entries. So 015 adds a numeric layer — the classic-Morrowind shape (Decision Log).

### Content model — the Golden Rule triple

**`FactionDef`** (`scripts/resources/faction_def.gd`; content in `data/factions/*.tres`):

| field | type | meaning |
|---|---|---|
| `id` | StringName | matches the filename stem (`wardens`, `licensed_crews`, `reciters`) |
| `display_name` | String | |
| `lore_sources` | Array[StringName] | wikilink bridge to `docs/lore/factions/` (validator-checked against `docs/lore`) |
| `join_journal_entry` | StringName | the `joined_*` id — **the additive link to the journal** (both the join effect and the migration key off it) |
| `ranks` | Array[FactionRank] | ordered low→high; index 0 is the joining rank |
| `charter_rank` | int = -1 | rank index that confers a charter; **-1 = never charters** |
| `rivals` | Array[StringName] | faction ids that block joining; **ships empty** |

**`FactionRank`** (`scripts/resources/faction_rank.gd`) — a sub-resource inside `FactionDef.ranks`, never a standalone file (the `QuestStage` / `DialogueChoice` pattern; no data folder, no scaffold):

| field | type | meaning |
|---|---|---|
| `id` | StringName | e.g. `warden_gatewatch` |
| `title` | String | display name of the rank |
| `reputation_min` | int | reputation needed to advance **into** this rank; rank 0's is the reputation seeded on joining |
| `skill_id` | StringName = `&""` | optional governing-skill gate (`&""` = none) |
| `skill_min` | int = 0 | required skill level when `skill_id` is set |

*Rejected alternative:* per-faction reputation/rank as loose fields on `Game`. Bundling them in one injected-and-serialized resource follows the sheet/inventory/journal precedent exactly — one owner, one save section, testable without a scene tree. **Director ruling:** the resource.

### Runtime state on `Game`

**`FactionStanding`** (`scripts/resources/faction_standing.gd`) — pure state, numbers only, the next sanctioned `Game` identity field after sheet/inventory/journal:

- `reputation: Dictionary[StringName, int]`
- `rank: Dictionary[StringName, int]` — **membership = key present**
- `is_member(id)`, `get_reputation(id)`, `get_rank(id)`, `adjust_reputation(id, delta)`, and `seed_if_absent(id, rank, reputation)` — the last is **idempotent**: it seeds a *missing* record and never touches an existing one. This is the property that keeps `reconcile` safe once 017 starts docking reputation and future specs raise rank — reconcile can run at every scene entry without ever resetting live state.

Serializes exactly like `CharacterSheet.attributes` — reuse `SaveCodec._ids_to_strings` / `_strings_to_id_ints`.

`Game` gains `var faction_standing: FactionStanding`, built fresh in `_ready`, reset in `start_new_game`, replaced whole in `_apply_load`, and reconciled at every identity setup (see below). It stays a `Game` field; the player node does not need it yet, so `setup_identity` is left alone until a component consumes it (build-when-consumed).

### Pure queries — `FactionRules` (static, resolver-injected, like `SaveCodec`)

`scripts/systems/faction_rules.gd`, all static, no scene tree, resolvers passed in:

- `reconcile(standing, journal_entries, library) -> void` — for each `FactionDef` whose `join_journal_entry` is in `journal_entries`, `standing.seed_if_absent(id, 0, ranks[0].reputation_min)`. Idempotent. **This one function is both the runtime membership seeder and the core of the save migration.**
- `can_advance(def, standing, sheet) -> bool` — member, has a next rank, `reputation >= next.reputation_min`, and (`skill_id == &""` OR `sheet.skills.get(skill_id, 0) >= skill_min`).
- `is_chartered_under(faction_id, standing, library) -> bool` — the def's `charter_rank >= 0` AND member AND `rank >= charter_rank`. Charter is **derived from membership** — no separate ledger (**director ruling**).
- `blocks_joining(def, standing) -> bool` — any of `def.rivals` is a current member. Always false for shipped content (empty rivals); the mechanism 015 provides.

`Game` exposes a thin `is_chartered_under(faction_id) -> bool` wrapper (018's call site) delegating to `FactionRules` with its standing + `FactionLibrary.get_factions()`, and calls `FactionRules.reconcile(...)` at identity setup: in `start_new_game`, in `_apply_load`, and in `_adopt_boot_scene` — so a fresh join materializes into a record on the next scene entry, the 006 cell-reload cadence. Within a session before a door transition the journal entry is already the source of truth for dialogue, so no feature observes a stale record.

**`FactionLibrary`** (`scripts/systems/faction_library.gd`) — folder scanner mirroring `ItemLibrary` / `QuestLibrary`; `get_factions() -> Dictionary[StringName, FactionDef]`.

### Save + migration — the `SaveCodec` architectural first

- `const SAVE_VERSION := 2`.
- Add `"factions"` to `_ROOT_KEYS`; `SaveState` gains `faction_standing`.
- `encode_save` writes `"factions": {"reputation": {…}, "rank": {…}}`; `factions_from_dict` rebuilds it, shape-validated like the sheet (reuse `_is_id_number_dict` / `_strings_to_id_ints`).
- **Version handling changes** at `save_codec.gd:85`. Today it rejects any `save_version != SAVE_VERSION`. New logic:
  - `== SAVE_VERSION` → proceed.
  - `> SAVE_VERSION` → still refused (a save from a newer build is forward-incompatible; the existing "future version refused" test stays green).
  - a recognized older version → migrate first. `_migrate_v1_to_v2(data, library)` synthesizes the missing `"factions"` section by running `reconcile` over an empty `FactionStanding` seeded from `data["journal"]["entries"]`, encodes it into `data`, and stamps `save_version = 2`; decoding then continues on the upgraded dict.
- `decode_save` gains a `library: Dictionary[StringName, FactionDef]` resolver param (exactly like `items`); `Game.load_game` passes `FactionLibrary.get_factions()`.

The migration is deliberately the same `reconcile` the runtime uses — a v1 save is just a v2 save whose faction records haven't been seeded yet, so one function covers both and there is no second code path to drift.

### Join-commit choice-prompt retrofit (013 pattern, canon-packet authored)

Retrofit `data/dialogue/take_the_cord.tres` and `data/dialogue/the_roofed_cache.tres` exactly as 013 retrofitted `tablet_law`: the join commit response gets `choice_gated = true`; a **prompt** response is inserted immediately before it carrying the same gates, offering ≥ 2 player-voiced replies — a join line whose `topic` re-enters the commit, and a "not yet" dismissal (`topic = &""`). The commit still writes its `journal_entry` unchanged, so `reconcile` turns it into the faction record and every existing `requires_journal` gate keeps working — the additive contract. `take_the_cord` has two state-forked join variants (`resp_torrum_join_stood` requires `stood_for_the_tallies`; `resp_torrum_join_makegood` requires `refused_the_square` + `the_moth_test`), so the prompt is state-forked the same way 013 forks by `requires_journal` / `blocked_by_journal`. Reply lines are authored via the `canon-packet` skill under the plain-meaning anchor — a button says exactly what it commits.

### Ripple check (why nothing else changes)

The additive ruling is what contains the blast radius: every `requires_journal` / `blocked_by_journal` reference in `data/dialogue/` and `data/quests/` still keys off the unchanged `joined_*` entries, so the `test_lastdoor_chain.gd` guild-independence contract holds untouched. Quests read the same journal entries — zero quest change. The only save-payload growth is one additive section; old v1 saves migrate rather than break. The two shipped SAVE_VERSION guard tests (`test_player_casting.gd`, `test_title_screen.gd`) flip 1 → 2 by design — they are the intended tripwires for exactly this bump.

## Architecture

| new file | role |
|---|---|
| `scripts/resources/faction_def.gd` | `FactionDef extends Resource` |
| `scripts/resources/faction_rank.gd` | `FactionRank extends Resource` — sub-resource only |
| `scripts/resources/faction_standing.gd` | `FactionStanding extends Resource` — runtime state on `Game` |
| `scripts/factions/faction_rules.gd` | `FactionRules` — pure static queries + reconcile/migration core (domain folder, matching `scripts/quests/`) |
| `scripts/factions/faction_library.gd` | `FactionLibrary` — folder scanner |
| `data/factions/wardens.tres` · `licensed_crews.tres` · `reciters.tres` | three faction defs (`charter_rank` set on `wardens` only; `rivals` empty on all) |
| `tests/data/test_faction_defs.gd` | content validator (Golden Rule) |
| `tests/unit/test_faction_standing.gd` | pure state + serialization |
| `tests/unit/test_faction_rules.gd` | reconcile / can_advance / is_chartered_under / blocks_joining |
| `tests/scenes/test_faction_join.gd` | join choice prompt → record seeded on scene entry |

**Modified:** `scripts/systems/game.gd` (the `faction_standing` field + reconcile call sites + `is_chartered_under` wrapper) · `scripts/systems/save_codec.gd` (`SAVE_VERSION` → 2, factions section, `_migrate_v1_to_v2`, library resolver on `decode_save`) · `data/dialogue/take_the_cord.tres` · `data/dialogue/the_roofed_cache.tres` · `tests/unit/test_save_codec.gd` (factions round-trip + **the first v1→v2 migration test**) · `tests/scenes/test_save_load.gd` (asserts `save_version` 2, factions restored) · `tests/scenes/test_player_casting.gd` & `tests/scenes/test_title_screen.gd` (the two guards asserting `SAVE_VERSION == 1` → 2) · `docs/lore/factions/{wardens,licensed_crews,reciters}.md` (`game_ids:` bridge to `faction:<id>`, canon-keeper reviewed) · `docs/specs/013-dialogue-choice-prompts.md` (inline note the two join retrofits are done) · `docs/master-plan.md` (§4 row → complete, Decision Log rows, vault count) · `CLAUDE.md` (Current focus).

**`BalanceConfig` additions: none** — rank thresholds are content on `FactionRank`, per the Golden Rule.

## Acceptance criteria (GUT tests)

1. **Data validation** (`tests/data/test_faction_defs.gd`): the 3 defs load; ids unique and equal to filename stems; non-empty `display_name`; `join_journal_entry` resolves to `data/journal/<id>.tres`; `ranks` non-empty with non-decreasing `reputation_min`; every non-empty `skill_id` resolves to a `SkillDef` in `data/skills/`; every `rivals` id resolves to a `FactionDef`; `charter_rank` in `[-1, ranks.size())`; **every shipped `rivals` array is empty** (pins the independence ruling); every `lore_sources` id exists under `docs/lore`.
2. **State** (`tests/unit/test_faction_standing.gd`): `seed_if_absent` seeds a missing record and is a no-op on an existing one — reputation and rank both preserved (the property that keeps reconcile safe under 017's future mutation); `adjust_reputation` moves the int up and down; `get_rank` / `is_member` reflect seeded records; the two dicts round-trip through the codec helpers.
3. **Rules** (`tests/unit/test_faction_rules.gd`): `reconcile` seeds exactly the factions whose join entry is held and is idempotent across repeated calls (a second call with a bumped reputation leaves it bumped); `can_advance` true only when reputation **and** skill gates both pass, false at the top rank; `is_chartered_under` true only for a member at `rank >= charter_rank` and false when `charter_rank == -1`; `blocks_joining` true against a synthetic rival def and false for every shipped def.
4. **Save / migration** (`tests/unit/test_save_codec.gd`): a factions section round-trips through a real JSON string (String-key/float coercion proven); a **v1 payload** — no `factions` section, `save_version: 1`, `joined_the_wardens` in the journal — decodes to a v2 `SaveState` whose standing holds a seeded Wardens record; a `SAVE_VERSION + 1` payload is still refused.
5. **Scene** (`tests/scenes/test_faction_join.gd` + `tests/scenes/test_save_load.gd`): pressing the join choice prompt appends the player line, fires the commit, writes `joined_the_wardens`, and after a scene entry `Game.faction_standing.is_member(&"wardens")` is true; a save/load round-trip through `/root/Game` preserves standing and the written file carries `"save_version": 2`.

Not validated, by design: the reply-line plain-meaning anchor (canon-packet human review, canon-keeper-reviewer on the lore bridges); whether `the_reading` should also become a prompt (director content call).

## How to implement

One commit each, full suite green (461 →) before each:

1. This spec + master-plan status. (`docs: spec 015 begins — the island learns to keep its own rolls`)
2. `FactionDef` + `FactionRank` + `data/factions/*.tres` + `FactionLibrary` + `test_faction_defs.gd` (criterion 1). (`factions: FactionDef content type + the three guild defs`)
3. `FactionStanding` + `FactionRules` + unit tests (criteria 2–3) — pure, no `Game` yet. (`factions: standing state + pure rules (reconcile, charter, advancement)`)
4. `Game` field + reconcile call sites + `is_chartered_under` wrapper. (`factions: Game owns faction standing, reconciled at identity setup`)
5. `SaveCodec` → v2 + factions section + `_migrate_v1_to_v2` + resolver; flip the two SAVE_VERSION guards; `test_save_codec` + `test_save_load` (criterion 4 + scene half). (`save: SAVE_VERSION 2 — factions section + first migration`)
6. Canon-packet pass → the two dialogue retrofits → `test_faction_join.gd` (criterion 5); `game_ids:` lore bridges, canon-keeper-reviewer first. (`content: guild joins speak as choice prompts (013 retrofit)`)
7. Docs housekeeping — master-plan Decision Log rows + status + queue row; CLAUDE.md focus; 013 note. (`docs: spec 015 complete`)
