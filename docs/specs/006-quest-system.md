# Spec 006 — Quest System (Journal-Derived Stages)

**Status:** ready to implement
**Depends on:** 003 (world-node + `Interactable` patterns, `Game` scene flow; amendment target: `WorldItem`), 004 (named physics layers; the sanctioned-`Game`-read precedent), 005 (`Journal`/`JournalEntryDef`, `DialogueResponse` conditions + effects, id-by-convention, the library/panel idioms; amendment target: `DialogueResponse` and the content defs), 011 (canon vault, canon-packet protocol, the `quests` pass prompt pack; amendment target: the `game_ids` bridge)
**Consumed by:** 007 (nothing new to serialize — quest state derives from the `Journal` that `Game` already holds; `HudNotice` reused for "Game saved."), 010 (re-homes the chain into the village, stages recruitment for the other two guilds, multiplies quest content), Phase 2 (the faction spec consumes the `joined_*` convention as its migration input), Phase 3 (bulk quest generation targets `QuestDef`; `test_quest_defs.gd` + the `lore_sources` bridge are the quality gates)

## Scope

**In:** `QuestDef`/`QuestStage` content type + `data/quests/` + validator · `QuestEvaluator` + `QuestLibrary` pure logic · `blocked_by_journal` response condition (005 amendment) · `JournalTrigger` world node (location arrival) · `JournalGate` world node (post-quest world change) · `WorldItem.journal_entry` (003 amendment) · `HudNotice` + `Player.show_notice` · a Chronicle | Quests toggle in the journal panel · `lore_sources` citations on quest/dialogue/journal content, validated against the vault (005 amendment + backfill) · the `quests` worldbuilding pass (12 seeds × 3 guilds, drafts in lore) · the Suddel favor retrofit quest · one branching Reciters chain (recruitment beat + the removed-tablet mystery; 4–6 stages, one decision point, two outcomes) with its NPCs, topics, and journal entries · `game_ids` gains the `quest` kind + bridge floor · debug scene · tests.

**Out (later specs / backlog):** the main quest (010 stages the opening; Phase 3 produces it) · implementing the other ~34 seeds (010 / Phase 3 — they live in lore until then) · recruitment for wardens and licensed_crews (010) · guild-exclusivity *policy* (the mechanism ships; whether joining one guild blocks another is ruled with 010/Phase 2 content — decision-log row) · any faction data type, rank number, or reputation (**the fence holds** — `joined_*` journal entries are the only membership signal until the Phase 2 faction spec) · gold rewards (gold is not an ItemDef per 005; rewards are `give_items` and access — barter is Phase 2) · kill-*counting* triggers (loot-as-proof via `take_items` already covers kill quests — the Suddel favor is one; counting without loot waits for a spec that needs it) · timed or scheduled quests (no clock exists, per 005's day-stamp ruling) · live `JournalGate` re-evaluation mid-scene (load-time only; live re-eval is backlog behind a spec that adds journal signals) · quest markers (**rejected permanently** — anti-pillar; directions and landmarks) · a runtime QuestLog resource (**rejected** — see the architectural decision) · a `quest_links` frontmatter field (**rejected** — 011 offered it; 006 declines: `game_ids` + `lore_sources` are the two validated bridge directions, and a third soft link field would drift) · repeatable/radiant quests · quest-granted XP (progression stays use-based per 001).

## Design

### Quests are read from the journal — the architectural decision

**A quest is a lens over the journal, not a second state machine.** `QuestDef` names an ordered sequence of stages, each bound to one `JournalEntryDef` id; runtime quest status is *derived*, on demand, from `Journal.entries` — the resource `Game` already owns and 007 already plans to serialize. No quest state is stored anywhere.

**`QuestDef`** (`scripts/resources/quest_def.gd`, `data/quests/` — new content type per the Golden Rule):

| field | type | meaning |
|---|---|---|
| `id` | StringName | unique, == filename stem |
| `display_name` | String | the quest title, shown in the Quests view |
| `lore_sources` | Array[StringName] | lore entry ids this quest derives from (see *Citations persist*) |
| `stages` | Array[QuestStage] | ordered; **array index IS the stage index** |

**`QuestStage`** (`scripts/resources/quest_stage.gd`) — a sub-resource inside the quest `.tres`, no data folder of its own, exactly like `DialogueResponse` and `ItemStack`: stages have no independent identity, one quest is one reviewable file, and the validator walks the nested array.

| field | type | meaning |
|---|---|---|
| `journal_entry` | StringName | resolves to `res://data/journal/<id>.tres` |
| `outcome` | StringName = `&""` | `&""` (progress) · `&"complete"` · `&"fail"` — `VALID_OUTCOMES` allow-list, the `ArmorDef.slot` StringName-enum precedent |

Derivation semantics — exact, implemented once in `QuestEvaluator`:

- **COMPLETED** if the journal holds any stage entry whose `outcome == &"complete"`; else **FAILED** if it holds any `&"fail"` stage entry; else **ACTIVE** if it holds any stage entry at all; else **NOT_STARTED**. The precedence makes the degenerate case (both terminals held) defined rather than undefined — well-authored gating should prevent it, but derived state must never be ambiguous.
- **Current progress** = the highest stage index whose entry is held. Entries are a set; arrival order doesn't matter — reaching stage 3 before stage 2 is legal by construction (the journal-index model of the design inspiration). Skipped stages are simply unheld.
- **One entry per stage.** Branching is expressed as multiple stages at different indices with different outcomes, not as alternative entries within a stage — fields stay flat for validators and the Phase 3 generator (005's "fields are flat" ruling).
- A failure route is just a stage with `outcome = &"fail"`, reached through the same trigger surface as any other stage.

*Rejected alternative — an explicit QuestLog resource (per-quest stage counters + a new `advance_quest` dialogue effect):* it is a second sanctioned `Game` field and a second 007 serialization surface; it duplicates what `journal_entry` effects already do; and it creates the classic drift bug (journal says X, log says Y) that derivation makes structurally impossible. What a QuestLog buys is *silent* progress — stages with no journal text — and for a text-first game whose pillar artifact is the readable journal, silent progress is an anti-feature. If a future spec (radiant work, reputation) genuinely needs non-journaled state, that spec adds it; don't grow this one silently (the CreatureDef/NPCDef ruling pattern).

**Proof by retrofit:** the shipped Suddel favor becomes `data/quests/a_small_favor.tres` with zero new code: a new journal entry on the existing "come back with a pelt" nudge response (the offer beat — text canon-packeted at implementation) becomes stage 0 (progress), and the existing `suddels_stores_favor` entry becomes stage 1 (`complete`). A quest system that can't read a quest 005 already shipped by accident would be the wrong quest system.

### QuestEvaluator & QuestLibrary — pure logic

Both in `scripts/quests/`, static, RefCounted, zero scene-tree dependencies, fully deterministic — the `CombatMath`/`DialogueEvaluator` testability pattern.

| class | API |
|---|---|
| `QuestEvaluator` | `enum Status { NOT_STARTED, ACTIVE, COMPLETED, FAILED }` · `static func status(quest: QuestDef, journal: Journal) -> Status` — the derivation above · `static func latest_stage_index(quest, journal) -> int` — highest held index, −1 if none · `static func reached_stages(quest, journal) -> Array[QuestStage]` — held stages in stage order, for the panel · `static func group_by_status(quests: Array[QuestDef], journal) -> Dictionary` — Status → Array[QuestDef]; within a group, quests order by the journal chronology of their earliest held entry (stable ordering derived from existing state — no new state) |
| `QuestLibrary` | `static func get_quests() -> Dictionary` — id → QuestDef, loading `data/quests/` via `ResourceLoader.list_directory` (the validator idiom), cached in a static var · `static func reset()` for tests — byte-for-byte the `DialogueLibrary` shape |

### Advancing quests — the trigger surface

Because state is derived, "trigger" always means exactly one thing: *something calls `Journal.add_entry`*. Three triggers ship; all reuse the idempotence `add_entry` already guarantees.

**1. Dialogue effects (exists — the primary trigger).** Every `DialogueResponse.journal_entry` effect is already a stage-advance; 005's Consumed-by line promised precisely this. One condition is missing for branching: **`blocked_by_journal: Array[StringName]`** joins the response condition table — the response matches only if the journal holds *none* of the listed entries. Within one topic, first-match-wins ordering already expresses branch-taken-beats-offer; `blocked_by_journal` is for exclusion *across* NPCs and topics — after taking branch A at NPC A, branch B's offer at NPC B must stop matching, which would otherwise take O(NPCs × branches) "too late" filler responses. Mechanics: `DialogueEvaluator.matches` gains the check; `is_unconditional()` gains `blocked_by_journal.is_empty()` (keeping the unreachable-response validator honest); the dialogue validator resolves the ids. **This is a formal amendment to 005's response table, applied in the same commit per the amendment ritual.**

**2. Location arrival — `JournalTrigger`** (`scripts/world/journal_trigger.gd` + `scenes/world/journal_trigger.tscn`): `JournalTrigger extends Area3D`, a world node like `WorldItem` — *not* a content type; its exports are placement data in the scene, which is where placement lives.

| export | type | meaning |
|---|---|---|
| `journal_entry` | StringName | entry added on qualified entry |
| `requires_journal` | Array[StringName] | all must be held for the trigger to arm |
| `blocked_by_journal` | Array[StringName] | none may be held |

Collision mask: the player's physics layer (004's named layers); on `body_entered`, cast to `Player`, evaluate conditions against `body.journal`, `add_entry`, and on a *new* entry call `body.show_notice(...)`. Re-entry is naturally a no-op (idempotent add → no notice). The gating matters for spoilers: wandering into a landmark before the quest points there adds nothing.

**3. Item/document acquisition — `WorldItem.journal_entry`** (one exported StringName, default `&""`): on pickup, add the entry via the `by` the pickup already receives. The "concrete item or document" every seed names becomes playable: the document *is* a WorldItem whose pickup writes the journal. **Formal amendment to 003's world-objects table, same commit.**

Kill quests need no fourth trigger: `take_items` is an implicit condition (005), so pelt-in-hand already proves the rat — loot-as-proof. Stated in Out so the absence of kill-counting isn't a silent gap.

### Changed worlds — JournalGate

`JournalGate extends Node3D` (`scripts/world/journal_gate.gd`): **its children are the conditional content.** At `_ready` it evaluates `requires_journal` (all held) and `blocked_by_journal` (none held); if the condition fails, it `queue_free()`s itself, children and all. Free, don't hide — a hidden StaticBody still collides, and "the rubble is gone" must mean gone.

- Memorial-appears: `requires_journal = [<chain outcome entry>]`. Rubble-until-done: `blocked_by_journal = [<entry>]`. Two arrays, both directions, one node.
- **The journal IS the world-flags store.** A separate flags dictionary on `Game` was considered and rejected: every world change in this game is narratively a journal-worthy event, and a flags store would be a third sanctioned `Game` field, a second source of truth, and new 007 surface. With gates deriving from the journal, 007's cost is zero: restore the journal, and every gate evaluates correctly on next load.
- **Sanctioned `Game.journal` read, stated here so it isn't silent:** gates evaluate during world `_ready`, which runs while the world is added — *before* `spawn_player`, so there is no player to inject from. Precedent: 004's amendment sanctioning `Creature`'s `Game.player` read. Same shape: `JournalGate` reads `Game.journal`, with a testable `journal_override: Journal` so scene tests inject without the autoload *(Amendment, implementation: a plain var, not an export — the `Creature.target` precedent; an exported override would be an editor footgun)*.
- **Stated limitation:** evaluation is load-time only. Completing a quest mid-scene changes the world on next entry — the cell-reload behavior of the design inspiration, honestly held. Live re-evaluation needs journal signals; `Journal` is signal-less by design (005), so that's backlog behind a spec that needs it.

### Guild membership without factions

The 011 fence holds: factions are prose canon, and nothing here mints a faction data type. Membership is a journal fact like everything else:

- **The `joined_*` convention** — joining a guild is a journal entry (`joined_the_reciters` in this spec; `joined_the_wardens`, `joined_the_licensed_crews` when 010 stages them), added by a recruitment dialogue response. Guild quests root their `requires_journal` chains at it. This is a *named convention*, documented here and in the pass digest, so 010 and Phase 3 author against it.
- **Exclusivity is mechanism now, policy later.** `blocked_by_journal` makes "joining A blocks B" expressible in pure data; whether the game *says* it is ruled when a second guild becomes joinable (010/Phase 2) — decision-log row, deliberately open.
- **Rank is deferred.** Chain entries may *read* like standing; no rank ladder exists. The Phase 2 faction spec consumes `joined_*` entries as its migration input — promote them to real membership state or keep deriving, its call.

### Quest log presentation — Chronicle | Quests

`JournalPanel` gains a two-view toggle; the input action, panel lifecycle, and pause behavior are untouched.

- **Chronicle** — the existing chronological render, byte-for-byte.
- **Quests** — `QuestLibrary.get_quests()` × `QuestEvaluator.group_by_status(...)`: groups in Active · Completed · Failed order, **empty groups hidden** (no dead "Failed" header while no content can fail), each quest as its `display_name` header followed by its `reached_stages` entry texts in stage order, resolved from `data/journal/` exactly as the Chronicle resolves them. A quest is its own story in order; the Chronicle stays the diary.

*Rejected alternatives:* chronicle-only (period-pure, but interleaved chains confuse exactly when 010 multiplies content — the design inspiration itself added quest sorting in its expansion, and the slice exit criterion is a stranger finishing a questline unaided) · a separate quests panel + input action (a third pause-panel for no benefit).

### Journal notices outside dialogue — HudNotice

Dialogue effects already surface inline ("Your journal has been updated." in the transcript). A `JournalTrigger` or document pickup firing *silently* in the open world reads as broken — the same silent no-op problem 005's playtest amendment fixed for keywords. Ship the minimal fix: `scenes/ui/hud_notice.tscn` + `scripts/ui/hud_notice.gd`, a queue of brief fading lines under the player's existing `$HUD` CanvasLayer beside `HudPrompt`/`HudBars`; `Player.show_notice(text: String)` appends. `JournalTrigger` and `WorldItem` call it on the player they already hold (the operate-on-who-touched-me precedent). The dialogue panel does **not** route through it — its transcript notices stay, and nothing double-notices. Fade time is UI styling, not balance. 007 inherits it for "Game saved."

### Citations persist — lore_sources

*(Director addition, ruled 2026-07-20.)* The canon-packet protocol produces citations and then throws them away with the packet; the cost lands later, when a canon entry changes and nobody knows which shipped text derived from it. 006 makes citations durable:

- **`lore_sources: Array[StringName]`** — lore entry ids (vault filename stems) — on `QuestDef` (born with it), and amended onto `DialogueTopicDef` and `JournalEntryDef` (**formal 005 amendment, same commit**). It is the one data-side field that points at the vault: deliberately the inverse of `game_ids`, and deliberately many-to-many where `game_ids` is exactly-one-ownership — a topic quoting three entries cites all three; only one entry *owns* it.
- **Floor:** every `QuestDef` cites ≥1 source; every `DialogueTopicDef` and `JournalEntryDef` cites ≥1, except `greeting` (engine furniture — the M3-amendment exemption, reused). 005's 8 shipped topic/journal files are backfilled with at least their `game_ids`-owning entry (that mapping was established in the M3 retrofit).
- **Validation, both suites:** the data validators enforce the non-empty floor; the canon suite gains the **reverse citation bridge** — every `lore_sources` id across `data/quests/`, `data/dialogue/`, `data/journal/` must resolve to a live, non-deprecated vault entry (the `game_ids` bridge's mirror; citing a deprecated entry fails like linking one).
- **What it buys:** a changed entry greps to its exact blast radius — `grep -rl <id> data/` returns every file whose text must be re-read, which bounds the post-slice rewrite cost the moment canon moves. The canon-keeper checks produced lines against committed citations instead of session-ephemeral review notes.
- Other def types (NPCDef descriptions, ItemDef flavor) stay uncited for now — their text is thin and `game_ids` ownership covers them; extending the floor is backlog, noted so it isn't silent.

### Content: the pass, the packets, and the shipped chain

**The `quests` worldbuilding pass runs first** (it was defined in 011 and gated to 006 — "there is no quest folder until 006 decides quest representation"; this spec is that decision). Per the pass contract: an interactive director session; per guild, 12 seeds — ≥4 noncombat-forward, ≥3 exposing faction hypocrisy or internal conflict, ≥4 requiring travel to a named landmark, ≥2 changing the environment after completion; every seed names an NPC role and a concrete item or document; per-seed schema title · premise · initiating NPC · location · decision point · consequence if completed · consequence if ignored · reusable lore surfaced. Seeds land as `## Quest hooks` bullets in existing entries plus `--stub` entries for new NPC roles; drafts only; canon-keeper reviews the diff. **The session also rules the packet's open gaps**, recorded into entries or the decision log: who authorized the removal and under what reading (reserved material — ruled at whatever spoiler tier the director sets); the chain's named reciter NPCs (stubs); the recruiting officer's subgroup; what recruitment concretely grants an unrolled outsider; whether the removed name and the Walker's extra name braid (nowhere stated — ruling, not assumption); the environment change the chain leaves behind (the JournalGate payoff); and the Homebringers coinage (standing veto).

**Canon-packet before all quest text, always** — the two-pass cited protocol from 011. The chain below is sketched *only* from packet facts; everything else above is deliberately unnamed.

**The Reciters chain** (director-ruled 2026-07-20; one branching chain, 4–6 stages, one decision point, two outcomes):

- **Recruitment beat** — the order's courtship of the untaken player: the arrival is their theological event, and the Column-Readers want the player read aloud in the court [reciters] [the_untaken_arrival]; standing is every faction's first offer to an unrolled outsider [underfirst]. Completing the beat adds `joined_the_reciters` — the convention's first live use.
- **The spine — the removed tablet:** a tablet gone in the night, mortar still damp, no declaration filed, and the reciters skipped the name without breaking stride [grief_court]; the order's own law has no procedure for what one of them plainly did, and who authorized it is held by the inner circle [reciters]. Investigation runs the rite's geography: the court's tablet walls and nine-day circuit [grief_court], closing at the first_roof's name-columns [first_roof] — where the yearly rope across the collapsed lower gallery was found cut from the far side, and custom has no procedure for that either [first_roof]. The travel stage is a `JournalTrigger` placement; the found document is a `WorldItem` with a `journal_entry` *(Amendment, implementation: the found object is the waxed staff — an item rather than a document; the approved Filled-Stops seed braided in as the chain's evidence beat)*.
- **The decision point — expose or absolve:** force the order to face what its law cannot name, or use the order's quiet second currency — absolution, hearing a thing said and sealing it unsaid [reciters]. Two completion outcomes, mutually excluded across NPCs via `blocked_by_journal`; the court changes either way behind a `JournalGate` (which change, per outcome, is the pass session's ruling).
- Voice for all of it at implementation time: reciter register is measured formula, High Register surfacing untranslated at rite moments [underfirst] [reciters]; tone defaults measured · euphemistic · exact · warm-dry · unhurried, under-naming the danger [bible]. High Register vocabulary is reserved — the chain quotes none of it.

**The Suddel retrofit** rides the same commit as `QuestDef`: the favor loop — bring the pelt, take the draught, be entered in the book [suddel] — becomes the first `.tres` in `data/quests/`.

**Content deltas:** `data/quests/` 0→2 · `data/dialogue/` 5→~9 · `data/journal/` 3→~10 · `data/npcs/` 3→~5 (the chain's reciters, from pass-session stubs). Exact counts pin `EXPECTED_COUNT` in the validators when the chain lands; the *quests* count is exact: 2. The chain's world nodes live in the debug scene until 010 re-homes them into the village — stated so it isn't a silent choice.

### The lore bridge — game_ids gains quest

- `tests/lore/test_lore_canon.gd`: `GAME_ID_FOLDERS` gains `"quest": "quests"` — canon entries may claim quest stems (`quest:a_small_favor` joins Suddel's existing claims [suddel]; the chain quest is claimed by the entry whose hook it implements).
- `tests/lore/test_lore_floors.gd`: `BRIDGED_DATA` gains `data/quests` — **every quest stem canon-claimed by exactly one entry**, extending the M3 bridge floor to the most narrative content type there is.
- Landing order: the constants, the claims, and the reverse citation bridge land together, *after* the quest `.tres` files exist — extending a floor before its data exists would redline the suite.
- `VALID_SURFACES` already contains `quest`; `BASE_KEYS` unchanged; `quest_links` declined (see Out).

## Architecture

| file | role |
|---|---|
| `scripts/resources/quest_def.gd` | `QuestDef extends Resource` |
| `scripts/resources/quest_stage.gd` | `QuestStage extends Resource` — sub-resource only |
| `scripts/quests/quest_evaluator.gd` | status derivation + grouping; static + pure |
| `scripts/quests/quest_library.gd` | cached loader for `data/quests/` |
| `scripts/world/journal_trigger.gd` + `scenes/world/journal_trigger.tscn` | gated area → journal entry |
| `scripts/world/journal_gate.gd` | load-time conditional subtree |
| `scripts/ui/hud_notice.gd` + `scenes/ui/hud_notice.tscn` | fading notice queue on the player HUD |
| `data/quests/*.tres` ×2 | `a_small_favor` + the Reciters chain |
| `data/npcs/` +~2 · `data/dialogue/` +~4 · `data/journal/` +~7 | chain + retrofit content, canon-packeted |
| `tests/data/test_quest_defs.gd` | quest validator |
| `tests/quests/test_quest_evaluator.gd` | derivation + grouping unit tests |
| `tests/scenes/test_journal_trigger.gd` · `test_journal_gate.gd` · `test_hud_notice.gd` | scene tests |
| `scenes/debug/quest_debug.tscn` + `scripts/debug/quest_debug.gd` | debug scene below |

**Modified:** `scripts/resources/dialogue_response.gd` + `scripts/dialogue/dialogue_evaluator.gd` + `tests/data/test_dialogue_topics.gd` (`blocked_by_journal`; `lore_sources` floor) · `scripts/resources/dialogue_topic_def.gd` + `scripts/resources/journal_entry_def.gd` (`lore_sources`) · `tests/data/test_journal_entry_defs.gd` (floor) · existing `data/dialogue/` + `data/journal/` `.tres` (citation backfill; the `a_small_favor` nudge gains its offer entry) · `scripts/world/world_item.gd` (`journal_entry` hook) · `scripts/ui/journal_panel.gd` + `scenes/ui/journal_panel.tscn` (Quests view) · `scripts/player.gd` + `scenes/player.tscn` (`HudNotice`, `show_notice`) · `tests/lore/test_lore_canon.gd` (`GAME_ID_FOLDERS`; reverse citation bridge) · `tests/lore/test_lore_floors.gd` (`BRIDGED_DATA`) · `docs/lore/` (36 seeds as hooks, stubs, rulings, `game_ids` claims) · `docs/specs/003-interaction-system.md` + `docs/specs/005-dialogue-and-journal.md` (amendment notes, each in the commit that amends it) · `docs/master-plan.md` + `CLAUDE.md` (housekeeping).

**Deleted:** none.

**`BalanceConfig` additions: none.** Rewards are `give_items` (gold stays out of dialogue per 005); trigger extents are per-placement Area3D shapes (scene data); notice fade is UI styling. Second spec with an empty table, and that's still fine.

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Derivation (unit):** NOT_STARTED on a fresh journal; ACTIVE after any stage entry; COMPLETED once a `complete` stage's entry is held; FAILED once a `fail` entry is held with no `complete`; COMPLETED wins when both terminals are held; out-of-order arrival (index 2 before 1) yields `latest_stage_index == 2` and correct status; `reached_stages` returns held stages in stage order.
2. **Grouping + library (unit):** `group_by_status` buckets correctly; within a group, quests order by journal chronology of their earliest held entry; `QuestLibrary.get_quests` loads exactly `data/quests/`, caches, and `reset()` clears.
3. **blocked_by_journal (unit):** a response with a held blocker never matches; `is_unconditional` is false when only `blocked_by_journal` is set; the cross-NPC scenario — after branch A's entry lands, branch B's offer response at another NPC stops matching.
4. **JournalTrigger (scene):** unarmed while `requires_journal` unmet; adds its entry exactly once when a qualifying player enters; shows a notice on the new entry only; blocked when `blocked_by_journal` held; re-entry is a silent no-op.
5. **JournalGate (scene):** `requires_journal` gate frees its subtree when unmet and keeps it when met; `blocked_by_journal` inverse; a freed gate's children are absent from the tree (a collision probe finds nothing); after the journal changes, a TransitionDoor round-trip re-evaluates the freshly instanced gates; `journal_override` injects for tests. *(Amendment, implementation: scene tests prove re-evaluation by fresh instancing plus a no-override `Game.journal` test — no shipped scene holds a gate before the debug scene, so the TransitionDoor round-trip is the debug scene's manual proof.)*
6. **WorldItem hook (scene):** pickup with `journal_entry` set adds the entry once and notices; default `&""` changes nothing.
7. **HudNotice (scene):** notices queue, display, and free themselves; several in quick succession all show; dialogue-panel effects produce no HUD notice (no double-noticing).
8. **Quests view (scene):** the toggle swaps views; groups render Active · Completed · Failed with empty groups hidden; each quest shows `display_name` + reached entry texts in stage order; the Chronicle view is unchanged from 005's criterion 8.
9. **Retrofit end-to-end (scene):** on shipped data with zero quest-specific code paths — fresh journal → `a_small_favor` NOT_STARTED; after Suddel's nudge response → ACTIVE; after the exchange → COMPLETED.
10. **Data validation — quests:** every `data/quests/*.tres` loads as QuestDef; `EXPECTED_COUNT` 2; ids unique and == filename stems; non-empty `display_name`; ≥1 source in `lore_sources`; ≥1 stage; every stage's `journal_entry` resolves to `data/journal/<id>.tres`; every `outcome` in `VALID_OUTCOMES`; ≥1 `complete` stage per quest (a quest that cannot complete fails the suite); the final stage carries a terminal outcome (a trailing progress stage is unreachable-narrative smell — the analogue of 005's no-response-after-unconditional rule); no duplicate `journal_entry` within a quest; across quests, each journal id claimed by **at most one** quest (005's flavor entries stay quest-less).
11. **Data validation — dialogue + journal extensions:** every `blocked_by_journal` id resolves by convention; every topic except `greeting` and every journal entry carries ≥1 `lore_sources` id; the amended `a_small_favor` topic still passes the full 005 validator.
12. **Lore bridge (canon suite):** `quest:` `game_ids` resolve to `data/quests/<id>.tres`; both quest stems claimed by exactly one entry; **reverse citation bridge** — every `lore_sources` id across `data/quests/`, `data/dialogue/`, `data/journal/` resolves to a live, non-deprecated vault entry.

## How to implement

One commit each, full suite green before each. The `quests` pass is commit 1 — a seed shape that breaks this spec's schema forces an amendment *before* code lands, and every later commit builds on the session's rulings.

1. `lore: quests pass — 36 seeds + chain rulings` — the interactive `worldbuilding-pass quests` session, all three guilds; seeds land as Quest-hooks bullets + stubs via `new-lore-entry`; the packet-gap rulings (removal authorization, chain NPCs, recruitment grant, the braid question, the gate payoff, the Homebringers veto) recorded into entries and the decision log; canon-keeper-reviewer on the diff.
2. `quests: QuestDef content type + Suddel retrofit` — `quest_def.gd` (with `lore_sources`), `quest_stage.gd`, `data/quests/a_small_favor.tres`, the nudge-offer journal entry (canon-packet for its text) + the `journal_entry` edit in `data/dialogue/a_small_favor.tres`, `tests/data/test_quest_defs.gd`, count bumps.
3. `quests: evaluator + library` — `QuestEvaluator`, `QuestLibrary`, unit tests (criteria 1–2).
4. `dialogue: blocked_by_journal condition` — field, `matches`, `is_unconditional`, validator ids; **005 amendment note, same commit** (criterion 3).
5. `content: lore_sources citations` — fields on `DialogueTopicDef`/`JournalEntryDef`, the 8-file backfill, data-side floors in both validators; **second 005 amendment note, same commit** (criterion 11's floor half).
6. `world: journal triggers and gates` — `JournalTrigger` + scene, `JournalGate`, `WorldItem.journal_entry`; **003 amendment note + the `Game.journal` read sanction, same commit**; scene tests (criteria 4–6, minus notices).
7. `ui: hud notices` — `HudNotice` + `Player.show_notice` + trigger/pickup wiring; scene tests (criterion 7, notice halves of 4/6).
8. `ui: quests view in the journal panel` — toggle + grouped render; scene tests (criterion 8).
9. `content: the reciters chain` — **canon-packet sessions first, per text**; the chain's NPCs/topics/journal entries/quest def; branch exclusion via ordering + `blocked_by_journal`; `joined_the_reciters` recruitment beat; count bumps; canon-keeper on lore-side stubs, golden-rule + gdscript-conventions reviewers on data/scripts (criterion 9 lands here).
10. `lore: quest bridge + reverse citations` — `GAME_ID_FOLDERS`, `BRIDGED_DATA`, `game_ids` claims on the owning entries, the reverse `lore_sources` check in the canon suite (criterion 12).
11. `debug: quest debug scene + docs housekeeping` — the scene below; master-plan §9 + decision-log rows for anything ruled mid-implementation; CLAUDE.md current focus → 007.

**Debug scene** (`scenes/debug/quest_debug.tscn`): a room with a `default` spawn; Suddel and a floor `rat_pelt` (the retrofit, playable start to finish); the chain's NPCs spaced out; a `JournalTrigger` on a mock landmark; a `JournalGate` pair (one `requires_journal`, one `blocked_by_journal`) around visible props; a TransitionDoor pair into a side room and back (gate re-evaluation, journal persistence); a live label dumping each quest's status + latest stage index and the journal tail. Proves: derivation on real data, both new triggers, notices, branch exclusivity across NPCs, the gate payoff appearing/vanishing across a reload, and the Quests view against the Chronicle.
