# Spec 010 — Slice Content (Lastdoor, ~10 NPCs, 30–60 min questline)

**Status:** ready to implement
**Depends on:** 003 (TransitionDoor/spawn markers/world nodes — the scene grammar), 004 (creature placement per its Consumed-by), 005 (dialogue/journal defs, greeting coverage, `[[markup]]`), 006 (QuestDef, the `joined_*` convention, JournalTrigger/JournalGate/`WorldItem.journal_entry`, `blocked_by_journal`, `lore_sources`; the Reciters chain + `a_small_favor` are re-homed here), 007 (saves ride the journal for free; scene-path note below), 009 (`Game.start_new_game` is the wrap point; this spec closes 009's "being name-less is itself canon — 010's problem" deferral), 011 (canon vault, canon-packet, the `dialogue` and environmental passes, the exit checklist), 012 (inventory panel — playthrough usability)
**Consumed by:** Phase 2 (the faction spec consumes all three `joined_*` entries; barter reuses the town), Phase 3 (the main quest hangs from the arrival staging; bulk content scales these patterns; the 15–30 NPC audit floor is met there)

## Scope

**In:** Lastdoor as the playable hub — `scenes/world/lastdoor.tscn` greybox exterior + a `bait_square.tscn` approach + 2–3 interiors, TransitionDoor-linked · one wilderness route scene + a small `drowned_stair` dungeon · the opening staged at the bait square (`MAIN_SCENE_PATH` retarget; wake-up sequence; the "how" never explained) · the **warden opening chain** — a new branching QuestDef staging `joined_the_wardens` off the captain's standing request · a `joined_the_licensed_crews` recruitment beat from the crews seeds · re-homing the 006 chain world nodes out of the debug scene into shipped scenes · ~5 new fully-dialogued NPCs (roster session) + kellom/ollun ratification · the `dialogue` and `environmental-storytelling` worldbuilding passes as director sessions · creature placement (the existing 3 defs, no new) · flavor journal beats via JournalTrigger · validator count bumps · a slice chain scene test + a world-scene lint test · the 011 exit-checklist audit (lore-audit run + manual director playthrough).

**Out (later specs / backlog):** spell vendors/teaching — skill level stays the only gate; no teaching UX or learning items exist; a village spell-teacher waits for that spec (**flagged, not silent**) · barter/gold economy (Phase 2; rewards stay `give_items` + access) · guild rank ladders (Phase 2) · NPC schedules/movement (NPCs stay dialogue anchors per 005) · creature respawn · the main quest beyond the opening (Phase 3; the arrival's "how" is spoiler-high reserved) · the 15–30 NPC audit floor (011's checklist number; the slice ships ~10 fully-dialogued NPCs — met in Phase 3, recorded as a deliberate checklist deviation) · art (greybox boxes + existing prefabs only) · day/night, weather, the exposure clock · fast travel · opening main.tscn's boxes to players (it survives as wilderness-route stub and test target only).

## Design

### A content spec runs on director checkpoints — the structural decision

010 is the first spec whose deliverable is mostly *worldbuilding-session output*: names, chain beats, and dialogue are **director-ruled during implementation, not pre-written here**. The spec fixes *structure* — phase gates, stage-count envelopes, roster slots, count targets, acceptance criteria — and marks every narrative particular below **(proposal — session finalizes)**. Each phase ends at a director checkpoint; no phase's `.tres` content lands before the prior checkpoint's rulings are in the decision log or the vault. Deviations amend this spec same-commit.

### Guild ruling — all three joinable

All three guilds are joinable **independently** in the slice: `joined_the_wardens`, `joined_the_licensed_crews`, and the existing `joined_the_reciters` never block each other. `blocked_by_journal` is reserved for *quest-level* conflicts (branch exclusion inside a chain, as in `the_skipped_name`); rank conflicts are Phase 2's faction spec. Recorded as a master-plan Decision Log row; the three faction entries carry a one-line Systems-impact note.

### The warden opening chain (proposal — session finalizes)

Quest id proposal `for_the_tallies`. Built from canon seeds: the captain's standing request, the two-versions tally-log, the moth test, the town taking sides, with the banked **warden-captaincy lever** unbanked in-session. Branching shape mirrors `the_skipped_name`; envelope: 5–8 stages, ≥1 decision point, two terminal stages, `joined_the_wardens` on the join branch. Proposed skeleton:

| idx | journal entry (proposed) | outcome | trigger |
|---|---|---|---|
| 0 | `woke_in_the_bait_square` | progress | wake JournalTrigger at the arrival marker (island's record only; no "how") |
| 1 | `the_captains_request` | progress | warden-captain dialogue: return to the square under witness, for the tallies |
| 2 | `the_town_takes_sides` | progress | courtship beat — the science / trial / bait readings from named faces |
| 3 | `the_two_tally_logs` | progress | evidence beat — the arrival-window log in two versions, a gated WorldItem document |
| 4 | `stood_for_the_tallies` | progress | branch A — the retest: a gated JournalTrigger inside the scorch ring, under witness |
| 5 | `joined_the_wardens` | complete | branch A payoff — the captain's offer; the captaincy lever is the session's ruling |
| 6 | `refused_the_square` | complete | branch B — refusal through a faction-aligned response; excluded against A via `blocked_by_journal` |

Default: refusal closes the warden join for the slice (a sanctioned quest-level `blocked_by_journal` use); the session may rule otherwise.

**Side content:** the `joined_the_licensed_crews` beat hooks on the roofed-cache rumor (canon: a Lastdoor rumor; the cache landmark sits on the route). Session decides: pure dialogue beat (quests stay 3) or a 2–3-stage `the_roofed_cache` mini-quest (quests go to 4). The re-homed `the_skipped_name` + `a_small_favor` ship unchanged as data — placement only.

### NPC roster (5 existing + ~5 proposed slots; roster session rules names per culture conventions)

Existing: suddel (canon) · swift (canon) · tansy (canon) · kellom (draft) · ollun (draft). 006 shipped kellom/ollun player-facing at draft; the roster session ratifies both to **reviewed** (canon at the director's option, never assumed).

| slot | role | why the slice needs them |
|---|---|---|
| warden-captain | chain-giver; the standing request and the join offer; subgroup allegiance = the captaincy ruling | the chain cannot exist without them |
| second warden | the post's dissenting voice on retest/revere/revise; moth-test informer | makes the institutional fight audible |
| crew boss | licensed_crews recruitment; the roofed-cache rumor | `joined_the_licensed_crews` needs a mouth |
| gate reciter | the reciters' Lastdoor presence; anchors the re-homed chain geography | courtship beat + re-homing |
| 1–2 market/gate faces | the legend's three versions, the nine-strokes chalk, greeting texture | the town must gossip |

All new entries via `new-lore-entry` (draft, inbound link from `lastdoor.md`, suite green); ratified to reviewed before their dialogue commits.

### Scene inventory (greybox + existing prefabs only)

| scene | contents |
|---|---|
| `scenes/world/bait_square.tscn` | scorch rings, tally-posts, the warden blind, the new ring at the arrival marker; spawns `default` (wake point) + `from_lastdoor`; wake JournalTrigger; gated retest JournalTrigger; door → lastdoor |
| `scenes/world/lastdoor.tscn` | the hub: the never-fully-closed gate, market row (tansy), warehouse row, warden-post facade, chalk-tally walls, crew shrine; NPCs: swift, crew boss, market faces, gate reciter; doors → bait_square, warden post, suddels stores, (gate shrine), route |
| `scenes/world/lastdoor_warden_post.tscn` | interior: captain + second warden, the tally-log WorldItem (gated), chain JournalGates |
| `scenes/world/suddels_stores.tscn` | interior: suddel re-homed, `a_small_favor` intact, WorldContainers, the quarantine row's always-empty shelf |
| `scenes/world/gate_shrine.tscn` *(session may fold into the exterior)* | kellom + ollun re-homed; the skipped-name nodes (columns trigger, staff, restored/gap/rubble gates) transplanted from `quest_debug.tscn`'s wiring |
| `scenes/world/scar_route.tscn` | wilderness route: covered-edge pieces, scar_hounds ×2, vault_rats, the roofed-cache landmark + trigger, doors ← lastdoor / → drowned_stair |
| `scenes/world/drowned_stair.tscn` | small dungeon: switchback flights, waterline, upper-flight caches, stair_drowned ×2–3 below the waterline, the sealed gate as diegetic dead end |

**Route ruling:** a new `scar_route.tscn`, not main.tscn re-dressed — `test_game.gd` hardcodes main.tscn in five call sites and several suites transit it; main.tscn survives untouched as the wilderness-route stub and test target (stated so it isn't a silent leftover). `quest_debug.tscn` also stays — debug scenes are keepers; the canonical placements move to shipped scenes.

### Opening staging

- `Game.MAIN_SCENE_PATH` → `res://scenes/world/bait_square.tscn`; `start_new_game` otherwise untouched. The player wakes at `&"default"` inside the new scorch ring; the wake trigger writes stage 0. The title screen stays chrome-only; opening flavor prose goes through canon-packet.
- **Name-less is canon, closed here:** dialogue addresses the player as the stranger / the untaken; no name field; `SAVE_VERSION` stays 1.
- **The "how" is never explained** — the opening presents only the island's record; spoiler-high material stays reserved.
- **Save compatibility (stated):** old saves carry `scene_path: res://scenes/main.tscn` and load there exactly as saved — a save is a place, not a boot target.
- **Test impact (stated):** `start_new_game` tests boot bait_square.tscn — it must instantiate headless with a `default` marker; `test_game`'s own `MAIN_SCENE` const keeps exercising main.tscn transitions.

### Content count targets (validators pin exacts per commit)

| validator | now | slice target |
|---|---|---|
| `test_npc_defs` | 5 | 10 |
| `test_dialogue_topics` | 9 | ~20 (greeting covers all 10 NPCs; every non-greeting topic keyword-reachable) |
| `test_journal_entry_defs` | 10 | ~20 |
| `test_quest_defs` | 2 | 3 (4 if the cache mini-quest is ruled in) |
| items | 15 | +1–3 (tally-log document; cache goods) |
| creatures | 3 | 3 (placement only) |
| lore entries | 56 | +5–8; kellom/ollun draft → reviewed |

No `BalanceConfig` additions.

### Authoring discipline (restated as gates)

Canon-packet before every line of player-facing text. The dialogue pass runs per-NPC as a director session with the 011 prompt pack (6 one-liners · 2 informer conversations · 1 life-story · 1 decision conversation; every line marked with canon fact ids; gaps → stubs, never invention). The environmental pass runs as a director session over the built greyboxes. The citation bridge holds at every commit; only the director ratifies canon.

## Architecture

**New:** the 7 scenes above · `data/npcs/` +5 · `data/dialogue/` +~11 · `data/journal/` +~10 · `data/quests/` +1–2 · `data/items/` +1–3 · `docs/lore/npcs/` +5 (+ stubs) · `tests/scenes/test_lastdoor_chain.gd` (chain end-to-end on shipped data) · `tests/scenes/test_world_scenes.gd` (scene lint).
**Modified:** `scripts/systems/game.gd` (`MAIN_SCENE_PATH` const only) · `data/dialogue/greeting.tres` + existing topics (keyword weave) · the four EXPECTED_COUNT validators · `docs/lore/` (ratifications, hook strikethroughs, `game_ids` claims) · `docs/master-plan.md` + `CLAUDE.md`.

## Acceptance criteria

1. **Counts (data):** all four validators green at the new EXPECTED_COUNTs; new items and placements validate.
2. **Citation bridge (canon suite):** every new `.tres` stem claimed by exactly one entry's `game_ids`; every `lore_sources` id live; greeting covers all 10 NPCs from fresh state; every non-greeting topic `[[keyword]]`-reachable.
3. **Quest data:** the warden chain (and cache quest if ruled) passes the full 006 validator — completable, terminal final stage, journal ids unique across quests.
4. **Chain end-to-end (scene, `test_lastdoor_chain.gd`):** fresh journal → NOT_STARTED; wake trigger → ACTIVE; both branches walkable to their terminals; after one branch's entry the other branch's responses stop matching across NPCs; `joined_the_wardens` lands only on branch A.
5. **Three guilds independent (scene):** from one journal all three `joined_*` entries can be held simultaneously; no shipped response's `blocked_by_journal` lists another guild's join entry.
6. **Scene lint (scene, `test_world_scenes.gd`):** every `scenes/world/*.tscn` instantiates headless; every TransitionDoor target + marker resolves; every JournalTrigger/JournalGate/WorldItem journal id resolves; every NPC def resolves; every world scene has a `default` marker.
7. **Opening (scene):** `start_new_game` lands at bait_square `&"default"`; the wake entry is added exactly once (re-entry silent); a mid-chain save/load round-trip restores derived quest status.
8. **Exit checklist (manual, director):** the 011 vertical-slice audit — 1 hub, 1 wilderness route, 1 dungeon, 3 factions represented, ≥10 NPCs (15–30 floor deferred, logged), 1 branching chain; a 30–60 min unaided playthrough finishing the warden chain; the three audit questions answered via a `lore-audit` run + playthrough notes. Not a GUT test — the phase-5 checkpoint.

## How to implement

Phased; every commit suite-green; canon-keeper on lore diffs, golden-rule/conventions on data/scripts:

**Phase 0** — this spec + the all-three-joinable Decision Log row + faction Systems-impact notes + CLAUDE.md focus.
**Phase 1 (director checkpoints)** — warden-chain rulings session (stage ids/branches, captaincy lever, courtship sequencing, crews beat shape, shrine-vs-exterior) → roster session (5 new NPC entries draft → reviewed; kellom/ollun ratification). No Phase-2 `.tres` before both land.
**Phase 2 (dialogue pass, one canon-packet session per cluster)** — warden chain + post voices → crews recruitment + crew boss → town faces + greeting coverage + keyword weave (→ route/stair rumors if ruled).
**Phase 3 (scenes)** — lastdoor + interiors + re-homed 006 nodes + scene lint → bait square → scar route + drowned stair + creatures → environmental-storytelling session beats.
**Phase 4** — `MAIN_SCENE_PATH` retarget + criterion-7 test.
**Phase 5** — chain end-to-end test → the manual exit-checklist playthrough + `lore-audit` → fixes → docs housekeeping.

**Risks (stated):** greeting.tres grows to 10 responses — first-match ordering review each commit · EXPECTED_COUNT bumps ride their content commits · bait_square is on the boot-test path — keep it prefab-light.
