# Master Plan — Open-World RPG (working title TBD)

*The living source of truth for this project. Started July 2026. Keep the Decision Log and Current Status sections up to date — this file sits in the Claude project knowledge so every conversation starts from it.*

## 1. Vision & Pillars

A solo-developed, AI-assisted open-world RPG in the spirit of Morrowind's design: a handcrafted, alien-feeling world on a single landmass; joinable guilds with real advancement and consequences; deep classless-ish character building; exploration guided by directions and landmarks, not quest markers; text-rich, topic-based dialogue.

**Pillars (every feature must serve at least one):** Exploration · Guilds & Consequence · Character Building. Anything that serves none of these goes to the backlog file, not the game.

**Anti-pillars (deliberately out):** voiced dialogue throughout, procedural main content, multiplayer, console ports, quest markers.

## 2. Decision Log

| date | decision | rationale |
|---|---|---|
| 2026-07 | Engine: **Godot 4 + GDScript** (over OpenMW, Unity, Unreal) | Modern sellable codebase; plain-text scenes/resources are maximally agent-friendly; free, no royalties |
| 2026-07 | **Claude Code** as primary engineer; spec-driven workflow (`docs/specs/NNN-*.md`), CLAUDE.md conventions, GUT tests mandatory | One reviewable system at a time; human retains design authority |
| 2026-07 | **Data-driven architecture**: all content as `.tres` Resources with validation tests | Enables bulk AI content generation with quality gates |
| 2026-07 | **Original IP** — no Bethesda names, lore, or assets; license manifest (`assets/LICENSES.md`) updated same-commit | Legal safety for commercial release |
| 2026-07 | **PC-first** (Steam + itch.io); GPL-platform constraints irrelevant on this path but consoles still out of scope | Solo scope control; core audience is on PC |
| 2026-07 | **Text-first dialogue** with short voiced barks at most | Authentic to inspiration; enormous cost/scope savings |
| 2026-07 | Derived stats always computed, never accrued | Kills retroactive-bonus bugs; respec-friendly |
| 2026-07 | **`Game` autoload** owns persistent identity (character sheet, inventory) and scene changes — the sanctioned exception to autoloads-last-resort | Cross-scene persistence needs exactly one owner; access rule in CLAUDE.md keeps it from becoming a global grab-bag |
| 2026-07 | **Physical hit resolution** — a connecting swing always hits; weapon skill scales damage. No dice-roll to-hit, ever (spec 004) | Morrowind's most-criticized mechanic; skill still gates power without visible whiffs |
| 2026-07 | **Creatures are not characters** — lightweight `CreatureDef` stat block (flat damage/armor, no skills, no xp), never a `CharacterSheet` (spec 004) | Keeps the 001 spine for player/NPC characters only; creature content stays cheap to author in bulk |
| 2026-07 | **Keyword-unlock dialogue via validated inline `[[markup]]`** — displaying a response learns its marked topics; markup is simultaneously the highlight, the unlock, and a validator target. Auto-scanning display names and silent unlock arrays rejected (spec 005) | One mechanism, no invisible unlocks; every keyword resolves or the data suite fails — the Phase 3 bulk-generation gate |
| 2026-07 | **Journal = one resource (entries + known topics) on `Game`**, injected at spawn like sheet/inventory — the second sanctioned `Game` field (spec 005) | Cross-scene dialogue/journal state needs one owner; 007 still just "serializes what Game holds" |
| 2026-07 | **NPCs are dialogue anchors** — `NPCDef` is id + name + flavor only; no faction, stats, or schedules without a new spec (spec 005) | Mirror of the creatures ruling; keeps NPC content cheap and the 001 spine uncontested |
| 2026-07 | **Dialogue and journal pause the game**; container looting stays real-time (spec 005) | Text-rich dialogue is a pillar — reading under attack is hostile; looting stays tense |
| 2026-07 | **Lore canon is markdown-in-git** — `docs/lore/` vault: strict YAML-subset frontmatter, `[[id]]` wikilinks reusing the 005 markup, filename stem = id, GUT-validated; YAML addons and external canon stores (MCP knowledge graphs, wiki apps) rejected (spec 011) | Canon must live where diffs, review, and validators reach it; agents author with native file tools |
| 2026-07 | **Graduated lore validation; reachability replaces count pins** — drafts parse-and-link only, reviewed/canon require the full spine; every non-deprecated entry must be reachable from `bible.md`; no EXPECTED_COUNT for the vault (spec 011) | Strictness where it protects canon, none where it taxes bulk drafting; orphan lore fails the suite like unreachable topics |
| 2026-07 | **The faction fence extends to lore** — `docs/lore/factions/` entries describe factions as prose canon; no faction game-data type until the Phase 2 spec (spec 011) | The bible needs factions for hooks and cultures now; game systems don't — the 005 NPC ruling stays uncontested |
| 2026-07 | **Quests are journal-derived** — `QuestDef` stages bind `JournalEntryDef` ids; status and progress derive from `Journal.entries`; no runtime QuestLog, no new `Game` field (spec 006) | One source of truth — journal/quest drift is structurally impossible; 007 still just serializes the journal; silent progress is an anti-feature in a text-first game |
| 2026-07 | **One chain first: the Reciters** — 006 ships the removed-tablet chain (recruitment beat, expose-vs-absolve decision) + the Suddel retrofit; the other 34 seeds stay lore hooks until 010/Phase 3 (spec 006) | Prove one line of cause and effect before multiplying content; keeps the wardens' arrival material clear of 010's opening |
| 2026-07 | **Recruit-first membership, exclusivity deferred** — joining a guild = a `joined_*` journal entry; `blocked_by_journal` is the exclusion mechanism, and whether guilds exclude each other is ruled with 010/Phase 2 content (spec 006) | Guild gating that never breaches the faction fence; policy waits for content that can express it |
| 2026-07 | **Chronicle/Quests toggle in the journal panel**, empty groups hidden; quest markers stay rejected (spec 006) | Interleaved chains confuse exactly when content multiplies — the expansion's lesson, applied early; the slice exit needs a stranger to finish a questline unaided |
| 2026-07 | **World triggers notice on-screen** — `HudNotice` queue on the player HUD for journal writes outside dialogue (spec 006) | A trigger firing silently reads as broken — the 005 silent no-op lesson, generalized |
| 2026-07 | **Citations persist as data** — `lore_sources` lore-entry ids on quest/dialogue/journal `.tres`, floor ≥1 (`greeting` exempt), validated live alongside the `game_ids` bridge (spec 006) | A changed canon entry greps to its exact rewrite set — bounded post-slice rewrite cost; canon-packet citations stop being session-ephemeral |
| 2026-07 | **Quests-pass rulings (spec 006, commit 1)** — 36 seeds landed (12 per guild); the removed tablet is an absolution debt (a death in the fields hidden as a Taking, confessed under the seal), braided with the extra name; the chain's payoff is the wall answering (restored tablet vs. kept blank gap); the Homebringers coinage stands; the reading is the recruitment rite granting novice standing without a roll-name; chain cast: Kellom (Column-Reader sponsor) and Ollun (Walker), draft entries | The chain's spine is director-ruled before any code lands; the roll-name lever, the warden captaincy, and exile-from-the-roof stay banked for 010 |
| 2026-07 | **Saves are versioned JSON through one pure codec** — `SaveCodec` (static, resolver-injected) owns the whole payload: identity resources as plain data, items by id through the new `ItemLibrary`, `save_version` equality-checked, `scene_path` allow-listed to existing `res://` scenes; per-resource `to_dict` methods and `.tres` saves via ResourceSaver rejected (spec 007) | One home for JSON coercion and future migrations; loading resources from `user://` is a code-execution hole a save file must never open |
| 2026-07 | **Single slot, quicksave-first; unknown ids skip** — one `user://save.json`, F5/F9, death folds into load-last-save with the 004 reload as no-save fallback; slots/menu/autosave deferred; a saved item id that no longer exists skips that stack with a warning instead of failing the load (spec 007) | Ship the loop before the furniture; content renames must not brick saves — the silent-loss tradeoff is accepted and logged here |
| 2026-07 | **All three guilds joinable independently** — `joined_the_wardens`, `joined_the_licensed_crews`, and `joined_the_reciters` never block each other in the slice; `blocked_by_journal` stays reserved for quest-level conflicts (branch exclusion inside a chain); rank conflicts wait for the Phase 2 faction spec (spec 010) | Morrowind-style breadth: a 30–60 min stranger should see all three guilds courting the untaken outsider — every guild wants first claim, none has veto |
| 2026-07 | **Warden-chain rulings (spec 010, Phase 1 session)** — a **Gate-captain** holds the Lastdoor captaincy (the standing request is operational, not rite or pure science; Doctrinists and Tally-keepers argue around the player); `for_the_tallies` runs 8 stages with the **moth test** as the second warden's playable rehearsal beat; the courtship is **free-order** — three named faces give their guilds' readings, the stage entry writes when the third lands (each face carries a gated final-reading response variant); **refusal defers, not closes** — after `refused_the_square` a make-good beat re-opens the captain's offer (dialogue pass shapes it); the crews join is the **`the_roofed_cache` mini-quest** (quests → 4); the skipped-name nodes re-home into a **gate-shrine interior** grown from the crew shrine of borrowed grief-tablets | The opening chain's spine is director-ruled before any content lands; deferring refusal keeps all three guilds reachable in one save, which the all-three-joinable ruling wants |
| 2026-07 | **Slice roster (spec 010, roster session)** — six new Lastdoor NPCs from the culture name-lists: **Torrum** (Underfirst Gate-captain, chain-giver), **Bryony** (Lastlight second warden, moth cages, the rehearsal beat), **Wester** (Lastlight crew boss — ruled the boss of Suddel's crew, closing that open question), **Dossun** (Underfirst gate reciter, shrine keeper), **Wren** + **Munnok** (the gossip pair across the cut); all drafted, reviewed after the dialogue pass; **kellom/ollun ratified draft → reviewed** | Roster before dialogue: every voice the chain needs now has a name, a culture, and a canon-cited seat in the town |
| 2026-07 | **Player-voiced dialogue choices are a Phase 2 spec** — decision points (the refusal, expose-vs-absolve) currently resolve by topic click per 005's model; the director ruled the real fix is a choice-prompt mechanism on `DialogueResponse` (player replies rendered as buttons), queued as spec 013 rather than patched per-topic (spec 010 playthrough) | One-click decisions read abrupt, but the model change belongs to a spec that amends 005 coherently — not to a content fix |
| 2026-07 | **The plain-meaning anchor** — every dialogue response must land who/what/what-you-can-do on first read; euphemism seasons, never carries alone (ruled during the 010 exit playthrough; bible Content grammar amended; ten responses re-anchored across the reciters' tail and the warden post) | Playtest found the registers compounding into riddles; comprehension is a pillar-level concern for a text-first game |
| 2026-07 | **The scaffold debts, named (010 lore-audit)** — two acknowledged Core-promise breaches ride into Phase 2/3 as work, not blockers: (1) a **material re-skin pass** — the item/spell scaffold (iron/leather/wood gear, mana draughts) is generic-medieval against the bible's ban and the chitin/rope/lava-glass material logic; (2) **magic's costs and licenses get teeth** — casting spends mana while the_workings prices workings in notice, and chartered/ordained tiers gate on skill number with no charter or membership requirement (natural home: the Phase 2 faction spec) | The audit found the 010 narrative layer clean; the drift lives in the pre-011 systems scaffold, and closing 010 over documented debts beats blocking Phase 1 on a re-skin |
| 2026-07 | **Phase 2 queue ratified — thirteen specs (013–025) in five waves** (planning session, 2026-07-22): 013 dialogue choice prompts · 014 material re-skin · 015 factions · 016 barter · 017 crime/stealth/locks · 018 magic v2 · 019 persuasion & disposition · 020 clock & NPC presence · 021 fast-travel · 022 alchemy · 023 enchanting-analog · 024 creature variety · 025 save furniture; longest chain 013 → 015 → 017 → 018 → 023; the queue table (§4) is the commitment, spec stubs are written just-in-time per wave | Every Out-list deferral from 002–012 and both audit debts map to exactly one owning spec; a hidden prerequisite (the in-game clock) surfaced during planning and got its own spec instead of being smuggled into schedules |
| 2026-07 | **Faction state is numeric on `Game`** — per-faction reputation int + rank, established by the faction spec (015), which also migrates the three `joined_*` entries; the first `SAVE_VERSION` bump (→ 2) and the first 007 migration function land with it | Crime docks reputation and persuasion reads it — Phase 2 needs a currency that can go *down*, and pure journal-derivation would need baroque `offended_*` counter-entries; classic-Morrowind shape |
| 2026-07 | **The license teeth split across 015/018** *(amends the scaffold-debts row's "natural home")* — 015 owns charter *state* and an `is_chartered_under()` query; 018 (magic v2) applies it to casting alongside notice-cost and the overcast state | Notice/overcast is mechanically substantial on its own (new save state, HUD, enforcement, an 008 amendment); folding it into the faction spec would double that spec against the small-reviewable culture |
| 2026-07 | **Bounty and notice are separate ledgers over one witness primitive** — bounty is a per-jurisdiction legal debt that clears by fine; notice is a personal ledger that never clears (overcast is its permanent failure state); the witness/observation query is built once in 017 and consumed by 018 — hence 017 before 018 | Merging the ledgers would flatten the_workings' lore; the genuinely shared machinery is "did an authority-aligned observer see the act," which sneak and theft need anyway |
| 2026-07 | **Deposit lands as one sanctioned player stash** — a single `Game`-owned container in Lastdoor (016, e.g. a rented room's chest); any-container persistence stays out and the world-state-from-journal fence holds | Persistent container contents would be the first world-object blob in the save payload; one stash solves the encumbered-relief debt at a fraction of the machinery, and it is exactly what Morrowind players did with one house anyway |
| 2026-07 | **Schedules ship presence-lite** — an in-game clock on `Game` (020: hour/day, sleep/wait) plus day/night NPC placement swaps (at-post by day, home/absent by night); no pathing or navmesh; a merchant absent is a shop closed for free | Morrowind itself had stationary NPCs — period-authentic; full hourly waypoint life serves Exploration weakly for its cost, and the clock alone unlocks day-stamped journal entries and travel time |
| 2026-07 | **Phase 2 planning defaults** — the re-skin (014) changes display/description/material surface only, item ids stay stable (007's unknown-id-skip would silently vaporize renamed items from saves; any unavoidable rename waits for a SAVE_VERSION migration carrying an id-remap) · no dynamic crafted items in Phase 2: alchemy (022) ships fixed recipes into existing `ConsumableDef`s and enchanting (023) ships hand-authored bound-working defs (`ItemLibrary` serializes by id; player-authored dynamic items are a Phase 3 serialization decision) · regional prices ship as a multiplier hook only (one settlement exists; Phase 3 world production populates it) · levitation + the tri-key stay a lore-backed hook, not queued | Confident defaults logged so no spec drifts into them mid-implementation |

*(Append new rows as decisions land. A decision isn't made until it's in this table.)*

## 3. Scope Budget — defend this

One island crossable on foot in ~15–20 minutes. 1 city · 3–4 villages · 12–20 dungeons from a reusable kit · 3 joinable guilds × 8–10 quests each · main quest of 12–15 quests · ~40–60 quest-relevant NPCs · 12 skills, 7 attributes. Target playtime: 15–25 hours.

Calibration: this is roughly 10–15% of Morrowind's content with 100% of its systemic feel. New ideas that expand this budget go to `backlog.md`.

## 4. Roadmap

### Phase 0 — Foundations ✅ complete (July 2026)
Engine bake-off done, Godot chosen, repo + CLAUDE.md + spec workflow established, walkable gray-box world running.

### Phase 1 — Vertical Slice (target: 2–3 months at part-time pace)
**Exit criterion:** a stranger plays 30–60 minutes — creates a character, explores a village, talks, fights, casts, completes a short questline, saves and reloads — and it *feels like the game*.

Spec queue (one spec = one reviewable unit of work):

| # | spec | status |
|---|---|---|
| 001 | Character stats system | ✅ complete |
| 002 | Items & inventory (equipment slots, weight vs. carry capacity) | ✅ complete |
| 003 | Interaction system (raycast interact: doors, containers, pickups, NPCs) | ✅ complete |
| 004 | Combat v1 (melee, stamina costs, damage, basic enemy AI) | ✅ complete |
| 005 | Dialogue system (topic-based, data-driven) + journal | ✅ complete |
| 006 | Quest system (journal-derived stages, triggers, gates, guild chain) | ✅ complete |
| 007 | Save/load | ✅ complete |
| 008 | Magic v1 (evocation / mending / warding) | ✅ complete |
| 009 | Character creation flow (attributes, 5 major skills) | ✅ complete |
| 010 | Slice content: first village, ~10 NPCs, 30–60 min questline | ✅ complete (director playthrough accepted + lore-audit passed, 2026-07-22) |
| 011 | Lore bible & worldbuilding system (canon vault + validators + skills; foundation & regional-skeleton passes) | ✅ complete (jumped the queue so 006/010 draw on canon) |
| 012 | Inventory panel UI (view / use / equip; mini-spec prerequisite for 010) | ✅ complete |

*(013, formerly parked here as "queued (Phase 2)", moved to the Phase 2 queue below when that phase was planned.)*

### Phase 2 — Systems Depth (target: 3–4 months)
**Exit criterion:** all 1.0 systems exist and interlock; content still thin. Wave 5 closes with the Phase 2 exit audit: the lore-audit skill plus an interlock playthrough against this criterion.

Spec queue (planned 2026-07-22 — the four planning rulings and the defaults are Decision Log rows; the queue table is the commitment, spec stubs are written just-in-time as each wave approaches):

| # | spec | status |
|---|---|---|
| 013 | Dialogue choice prompts (player-voiced decision replies as buttons; amends 005; retrofits the two shipped decision points) | queued (Wave 1) |
| 014 | Material re-skin pass (content mini-spec: chitin/rope/lava-glass over the generic-medieval scaffold; ids stay stable; closes audit debt 1) | queued (Wave 1) |
| 015 | Faction system (`FactionDef` + rank sub-resources; numeric reputation/rank on `Game`; advancement checks; exclusivity policy; charter state + `is_chartered_under()`; migrates the three `joined_*` entries; `SAVE_VERSION` → 2 + first migration) | queued (Wave 2) |
| 016 | Barter economy v1 (`MerchantDef`; barter panel off dialogue; pure price math with persuasion as the inert-friendly price lever; drop-to-world; the player stash; gold quest rewards unlocked; 2–3 Lastdoor merchants; regional multiplier as hook) | queued (Wave 2) |
| 017 | Crime, stealth & locks v1 (ownership fields; the witness primitive; `sneak` + `security` go live; lockpicking; theft → bounty on `Game`; warden confrontation — pay or resist; stolen-flag → merchant refusal) | queued (Wave 3) |
| 018 | Magic v2 (notice as spent currency per the_workings; the overcast state; charter gate on the 008 tiers via 015's query; witnessed-unlicensed-working enforcement via 017; HUD notice; amends 008; closes audit debt 2) | queued (Wave 3) |
| 019 | Persuasion & disposition (disposition model: `NPCDef` base + faction standing + persistent per-NPC modifier; persuasion attempts as 013 choice prompts — admire/intimidate/bribe; disposition-gated dialogue conditions; price nudge into 016's formula) | queued (Wave 4) |
| 020 | Clock & NPC presence (in-game clock on `Game`: hour/day, sleep/wait; day-stamped journal entries close 005's deferral; presence-lite day/night placement swaps; schedule sub-resource is the sanctioned `NPCDef` amendment) | queued (Wave 4) |
| 021 | Fast-travel network (mini-spec: transport hubs, gold fares via 016, time advance via 020, known hubs derived from journal; map-anywhere stays rejected) | queued (Wave 4) |
| 022 | Alchemy (`IngredientDef` on canon materials; skill-derived effect discovery — derived, never stored; brewing UI; fixed recipes → existing `ConsumableDef` outputs) | queued (Wave 3, parallel) |
| 023 | Enchanting-analog (hand-authored bound-working defs; acquired via 015 ranks / 016 rare stock; priced in 018's notice economy; on-hit/on-use/constant hooks into the 004/008 pipelines) | queued (Wave 5) |
| 024 | Creature variety pass (content spec, the 010 shape: ~6–10 canon-material `CreatureDef`s; 1–2 cheap AI additions; loot aligned with 016 prices + 022 ingredient drops) | queued (Wave 5) |
| 025 | Save/load furniture (mini-spec: save slots + metadata, save/load menu mirroring `JournalPanel`, settings file; floats — schedule after the first `SAVE_VERSION` bump so migration and slot menu land proven together) | queued (floating) |

**Waves:** 1 — 013 ∥ 014 (code-side vs content-side, no contention) · 2 (the spine) — 015 ∥ 016 · 3 (the law) — 017 → 018, with 022 parallel anywhere here · 4 (interlock) — 019 ∥ 020 ∥ 021 · 5 (capstone) — 023 ∥ 024, then the exit audit. Longest chain: 013 → 015 → 017 → 018 → 023; everything else hangs off it with slack. Not queued: birthsign-analog perks/backgrounds (009's deferral, backlog) · levitation + the tri-key (lore-backed hook, Decision Log).

### Phase 3 — World Production (target: 4–8 months; the AI-leverage phase)
Terrain via Terrain3D, region by region · settlement and dungeon kits (kitbash sets with an art bible) · bulk quest/dialogue generation pipeline: LLM generates against schemas → validators reject malformed content → human editorial pass on every line · guild questlines · main quest · economy and loot population.
**Exit criterion:** the full scope budget exists in-game.

### Phase 4 — Polish (target: 2–3 months)
Audio pass (music, ambience, SFX, barks) · UI/UX rework · performance and streaming · difficulty tuning · two closed playtest waves via itch.io with structured feedback.
**Exit criterion:** strangers finish a guild questline unaided; stable 60fps on mid-range hardware.

### Phase 5 — Release
Steam page live early in Phase 3 for wishlists ($100 fee) · demo in a Steam Next Fest · devlogs (written or video) from Phase 3 onward as the marketing engine · launch 1.0 · post-launch patch window.

**Honest total: 18–36 months at 10–15 hrs/week.** AI compresses production, not decisions.

## 5. AI Production Pipelines

| asset type | pipeline | quality gate |
|---|---|---|
| Code | Claude Code per spec, small commits | GUT tests + human review of every commit |
| Quests/dialogue/lore | LLM generates against schemas, guided by the `docs/lore/` canon vault (spec 011: canon-packet retrieval + `bible.md` content grammar) | Schema validators (data + lore suites) + human edits every line |
| 3D props/kits | CC0 libraries (Kenney, Quaternius, PolyHaven) + text-to-3D (Meshy/Tripo) for gaps; Blender cleanup | Art bible; tri-count and texture-size budgets |
| Characters | Base-mesh tool + Mixamo/Cascadeur animation | Shared rig; silhouette check |
| Textures/2D | Local Stable Diffusion; fixed palette and resolution | Art bible |
| Music/SFX | Suno/Udio paid tier or CC0; freesound | License manifest |
| Voice barks | ElevenLabs, sparingly, late | Phase 4 only |

Every asset entering the repo gets a `assets/LICENSES.md` line in the same commit.

## 6. Cadence & Rituals

- **Weekly playable build, no exceptions.** Tag `v0.<week>` each week; momentum is the scarcest resource.
- **Session protocol:** agent reads CLAUDE.md → implements current spec section → tests pass → small commit → human reviews and plays it.
- **Specs before systems:** no system gets built without a numbered spec; design decisions happen in specs, not mid-implementation.
- **Monthly checkpoint:** review scope budget, prune backlog, update this file's status and decision log.

## 7. Risks & Mitigations

- **Scope creep** → pillars test + scope budget + backlog file. The sequel can have your new idea.
- **AI asset soup** → art bible (palette, texture resolution, style refs) before Phase 3 begins; kitbash from a small trusted set.
- **Untested agent code rot** → tests are non-negotiable per CLAUDE.md; review every commit; never merge what you can't explain.
- **Burnout** → weekly build ritual, monthly checkpoint, and permission to shrink the scope budget — shipping small beats abandoning big.
- **Legal drift** → license manifest discipline; zero Bethesda IP; verify commercial terms on every paid AI tool.

## 8. Definition of Done (1.0)

The scope budget in §3 fully present · a new player can finish the main quest and one full guild line without help · save/load robust across versions within a release · runs at 60fps on mid-range hardware · every asset licensed in the manifest · Steam build passes review.

## 9. Current Status

**As of July 21, 2026:** Phase 1 underway — specs 001–005 (stats, items & inventory, interaction, combat, dialogue + journal) and 011 (the lore bible) are implemented and playtested. **Spec 006 (quest system) is complete:** journal-derived quests are live — `QuestDef` stages bind journal entries and a pure `QuestEvaluator` derives status (no runtime quest state; 007 gets saves for free), triggers ride dialogue effects plus `JournalTrigger`/`WorldItem` grants, `JournalGate` changes the world at load, `HudNotice` surfaces writes, and the journal gained the Chronicle/Quests toggle. The `quests` worldbuilding pass landed 36 seeds (12 per joinable guild) as vault hooks; the vault stands at 56 entries (19 canon, 34 reviewed, 3 draft) with the `lore_sources` citation bridge validated both ways alongside `game_ids`. Two quests shipped: *A Small Favor* (the Suddel retrofit) and *The Skipped Name* (the branching Reciters chain — the reading, the removed tablet, expose-or-absolve). **Spec 007 (save/load) is complete:** "serialize what Game holds," delivered — a pure `SaveCodec` writes versioned, human-readable JSON to `user://save.json` (items by id via the new `ItemLibrary`, scene + exact transform + current pools captured, journal restore reconstitutes all quest/world state for free per 006), F5/F9 quicksave/quickload with HUD notices, and the death overlay now loads the last save, closing 004's caveat (the old reload survives as the no-save fallback). **Spec 008 (magic v1) is complete:** the three schools are live on the 001 spine — a `SpellDef` content type + `SpellLibrary` with 5 canon-named workings (Flamespark, Flamelash, Tidemend, Stoneroof, Greatroof), RMB cast / R cycle, skill-gated learning derived from the sheet (licensing tiers 0/25/50 per the_workings; no new Game state, `SAVE_VERSION` still 1), evocation bolts riding `HurtBox` and the 004 defense pipeline untouched, mending self-heal, a timed ward pool soaking after block+armor, passive mana regen, and the HUD's mana/ward bars + selected-working label. The aspect↔school ruling (Flame→evocation, Stone→warding, Tide→mending) is recorded in the_workings. Suite: 401 tests green. **Spec 009 (character creation) is complete:** the game finally has a front door — a title screen (`New Game` / `Continue` / `Quit`) boots instead of the raw world, and the creation form implements 001's contract as written: pick exactly 5 of the 12 skills as majors (archetype columns, data-driven from `data/skills/`) and one favored attribute starting at `attribute_favored_start` (40), with a live derived-stats preview. `Game.start_new_game` is the commit point (fresh identity wholesale); Continue rides `has_save`/`load_game` with a corrupt-save notice; no new Game state, `SAVE_VERSION` still 1; every F6 debug scene still boots on the default-sheet fallback. Suite: 421 tests green. **Spec 012 (inventory panel) is complete:** the mini-spec landed in three commits — `InventoryPanel` on the journal-panel lifecycle (I opens, pauses, same key closes), one list of carried stacks then `[E]` equipment rows via an explicit row model, a context-sensitive Use/Equip/Unequip action riding the existing component API (zero new inventory logic), a gold/weight/AR footer, and purely signal-driven refresh. **Spec 010 (slice content) is COMPLETE — and with it, Phase 1.** The director's exit playthrough is accepted and the lore-audit passed (the vertical-slice checklist holds: 1 hub, 1 route, 1 dungeon, 3 joinable factions, 11 NPCs, 2 branching chains; world inferable without codex; canon findable bidirectionally). Playthrough fixes landed along the way: spawn/clip/ramp geometry, larger reading panels, gear enters the slice (old-roof cache + the warden-issue blade), the plain-meaning anchor pass over the dialogue, and the deferred-decisions record (drop-when-encumbered accepted; player-voiced choices queued as spec 013). The audit's two named debts — the material re-skin and notice-cost/license-teeth magic — ride into Phase 2/3 as logged work. The vault stands at 62 entries (19 canon, 42 reviewed, 1 draft). Suite: 444 tests green. **Phase 1's exit criterion is met: a stranger creates a character, explores Lastdoor, talks, fights, casts, completes a questline, saves and reloads — and it feels like the game. Phase 2 is planned (2026-07-22):** a thirteen-spec queue (013–025) in five waves — see §4 — with the planning rulings logged in the Decision Log: numeric faction reputation on `Game` (first `SAVE_VERSION` bump), the 015/018 license-teeth split, bounty/notice as separate ledgers over one witness primitive, one sanctioned player stash, presence-lite schedules, and the confident defaults (re-skin keeps ids; no dynamic crafted items; regional prices as hook). Spec 013 has a stub (`docs/specs/013-dialogue-choice-prompts.md`); later stubs are written just-in-time per wave. **Next: Wave 1 — spec 013 (dialogue choice prompts) ∥ spec 014 (material re-skin pass).** Repo local at `~/personal_projects/open-world-game`; GitHub remote pending — link to this Claude project when live.
