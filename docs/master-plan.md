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
| 006 | Quest system (quest resources, stages, journal integration) | queued |
| 007 | Save/load | queued |
| 008 | Magic v1 (evocation / mending / warding) | queued |
| 009 | Character creation flow (attributes, 5 major skills) | queued |
| 010 | Slice content: first village, ~10 NPCs, 30–60 min questline | queued |
| 011 | Lore bible & worldbuilding system (canon vault + validators + skills; foundation & regional-skeleton passes) | spec written — **next up**, jumps the queue so 006/010 draw on canon |

### Phase 2 — Systems Depth (target: 3–4 months)
Factions with ranks, reputation, and advancement requirements · crime & bounty · barter economy with regional prices · NPC daily schedules · alchemy · enchanting-analog · fast-travel network (transport hubs, not map-anywhere) · persuasion mechanics · creature variety pass.
**Exit criterion:** all 1.0 systems exist and interlock; content still thin.

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

**As of July 19, 2026:** Phase 1 underway — specs 001 (character stats), 002 (items & inventory), 003 (interaction system), 004 (combat v1), and 005 (topic-based dialogue with keyword unlocking + journal) are implemented with debug scenes and a passing test suite (240 tests / 27 scripts); 005 is playtested with a first polish pass. **Spec 011 (lore bible & worldbuilding system) is written and jumps the queue ahead of 006** so quest and slice content draw on real canon: a validated markdown canon vault at `docs/lore/`, lore skills (`new-lore-entry`, `canon-packet`, `lore-audit`, `worldbuilding-pass`) + a canon-keeper reviewer, and the blank-slate foundation + regional-skeleton passes run as director sessions. Next: implement 011 M0 (parser, vault, validators, skills), then the M1 foundation session. Spec 006 (quests) follows, written from canon packets. Repo local at `~/personal_projects/open-world-game`; GitHub remote pending — link to this Claude project when live.
