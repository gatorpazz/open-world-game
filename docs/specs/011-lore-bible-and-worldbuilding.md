# Spec 011 — Lore Bible & Worldbuilding System

**Status:** ready to implement
**Depends on:** 005 (the `[[markup]]` syntax and `DialogueMarkup`, the validator idioms, the "names are placeholders pending the lore bible" contract), master-plan §5 (the lore-bible commitment this spec fulfills)
**Consumed by:** 006 (quest text written from canon packets; the quest-pass prompt pack), 008 (the M2 magic-rules canon feeds the magic design), 010 (village content is the first full consumer; the environmental-storytelling pass), Phase 2 (faction prose canon becomes faction game types), Phase 3 (the bulk-generation pipeline's source of truth and style guide)

*This spec is deliberately ~3× the length of 005 because it carries two things: a **system** (the canon vault, its grammar, its validators, its skills) and a **process** (the worldbuilding passes that fill it). Its research basis is `docs/research/lore-bible-research.pdf`, adapted throughout from that report's team-and-commercial-tools assumptions to this repo's reality: one director, AI agents, git, GUT. The report's operating principle survives adaptation intact: **every lore entry must justify itself in play.***

## Scope

**In:** a canon lore vault at `docs/lore/` — one markdown entry per fact-bearing thing, hub `bible.md` · a strict YAML-subset frontmatter grammar with a hand-rolled parser (`scripts/lore/`, pure RefCounted) · `[[id]]` wikilinks reusing 005's `DialogueMarkup` · a draft → reviewed → canon (→ deprecated) lifecycle with graduated validation · GUT lore validators (`tests/lore/`) with reachability-from-`bible.md` replacing count pins · a `game_ids` bridge from canon entries to `data/*.tres` · four skills (`new-lore-entry`, `canon-packet`, `lore-audit`, `worldbuilding-pass`) plus a `canon-keeper-reviewer` agent · vault templates and two quarantined schema examples · the worldbuilding process as milestones: M1 foundation pass and M2 regional skeleton executed **blank-slate** with the director, M3 schema stress + first canon batch + placeholder retrofit · docs housekeeping (master-plan decision rows and §5 path fix, CLAUDE.md lore rules — landed with this spec's commit).

**Out (later specs / backlog):** quest and rumor entry types (006 owns quest representation — until then quest seeds live in the mandatory *Quest hooks* body sections; rumors arrive with the spec that plays them, 006/010) · the quest/dialogue and environmental-storytelling passes as content (run during 006/010 with this spec's tooling; the report's vertical-slice audit numbers become 010's exit checklist) · architecture-kit entries (Phase 3 art bible) · in-game lore books, codex, or any player-facing rendering of the vault (a future content spec — the vault is a production tool; exported builds don't even pack `docs/`) · faction game-data types, ranks, reputation (Phase 2; see *The faction fence*) · second-region content beyond locked stubs (one-active-region rule, below) · a lore-audit git hook or CI step (backlog until the vault is big enough to drift between sessions) · lore localization (single-language canon until a localization spec) · a `quest_links` typed frontmatter field (if 006 wants one, it amends this schema in its own spec) · voiced or in-engine lore delivery (**rejected permanently** for v1 surfaces — text-first pillar) · a YAML addon dependency (**rejected permanently** — the strict subset *is* the schema's first gate; full YAML accepts garbage) · uppercase prefixed ids like `LOC-MARSHGATE-001` from the report (**rejected permanently** — house snake_case; the folder and `type` field carry everything a prefix would) · per-entry `change_log`/`owner`/`visibility`/`production_needs` frontmatter from the report (**rejected permanently** — git is the changelog, there is one director, `spoiler` covers visibility, production needs rot before Phase 3) · an external knowledge store for canon — MCP knowledge-graph servers, wiki apps, World Anvil (**rejected permanently** — canon must live where diffs, review, and validators reach it) · real-language copies in naming guides (**rejected permanently** — original-IP ruling).

## Design

### The vault — the architectural decision

**Canon is markdown in git.** `docs/lore/` holds one `.md` file per entry; the file is simultaneously the human-readable page, the agent-retrievable source, and the validator's input. The agent interface is the native toolset — Read, Grep, Glob — plus the GUT suite; no MCP server, no addon, no app is required to author, query, or validate canon. *Decision: `.tres`-native lore rejected* — lore is prose-heavy, and long prose in string fields diffs terribly, has no link graph, and would mix design-time reference into runtime `data/` where validators pin counts and systems load content. *Decision: external stores rejected* — an Obsidian MCP or knowledge-graph memory server would fork canon out of git review; the same failure mode as hardcoded content, one layer up. Obsidian the *app* is still welcome: the vault is deliberately Obsidian-compatible (YAML frontmatter, `[[wikilinks]]`), so pointing it at `docs/lore/` gives the director graph view and backlink navigation for free. `.obsidian/` gets a `.gitignore` line; the app writes nothing canon-bearing.

Prior art, for the record: this shape — markdown + frontmatter bible, agent skills, deterministic continuity checks that treat contradictions like compile errors — is the emerging standard for agent-maintained story bibles (e.g. the story-skills project), and it is the report's Obsidian-plus-relational-tool stack collapsed into the one tool this repo already trusts: the test suite.

Two link syntaxes coexist in the vault: `[[id]]` wikilinks are the canonical, validated cross-reference; standard markdown links (`[text](../master-plan.md)`) are allowed for pointing *outside* the vault and are not validated. Inside the vault, always link by `[[id]]`.

```
docs/lore/
├── bible.md            # the hub; type: hub; the reachability root
├── _templates/         # quarantined: entry_base.md + one per type (9)
├── _examples/          # quarantined: 2 filled demos (the report's Marshgate Weir
│                       #   location + Salt Tribunal faction, converted to this
│                       #   schema) — schema reference, never canon
├── rules/              # world_rule — cosmology, magic, technology, death/travel
├── timeline/           # timeline_event — era + order fields
├── regions/            # region — the active region + locked stubs
├── locations/          # location — kind: settlement|landmark|dungeon|route|danger_zone
├── cultures/           # culture — carries naming/speech/material-culture sections
├── factions/           # faction — prose canon only (see The faction fence)
├── npcs/               # npc — canon people (not 1:1 with data/npcs)
└── items/              # item — notable items, materials, documents
    wildlife/           # wildlife — flora and fauna
```

Nine of the report's thirteen entity types get folders now. The other four are deferred with owners (see *Out*): quest and rumor to 006/010, architecture kits to Phase 3, and **dialogue tone sheets are not a type at all** — per-culture voice lives *inside* culture entries as required sections (below), and world-level tone defaults live in `bible.md` *Content grammar*. A standalone tone-sheet type would silo voice away from the culture it belongs to.

There is deliberately no `foundation/` folder for the report's briefs: the Pillars sheet and Aesthetic brief are `bible.md` sections, and the Active-area brief **is** the active region's entry (its *Function* section is "why the story starts here"; its *Systems impact* is the traversal loop and travel constraints). One hub, no parallel brief documents to rot.

### Entry anatomy & the frontmatter schema

Every entry is frontmatter + a fixed body spine. The filename stem **is** the id — there is no `id:` field. *Decision: id-by-convention extends to the vault* — 005's rule (`id` == filename stem) already governs all game content; duplicating the id inside the file is drift waiting to happen. Ids are `[a-z0-9_]+`, unique across the **whole vault** (unqualified `[[id]]` links demand global uniqueness), and live in the folder matching their `type`.

The shipped `_examples/marshgate_weir.md` (converted from the report; quarantined, never canon) illustrates the shape:

```
---
title: Marshgate Weir
type: location
status: draft
region: fen_coast
kind: settlement
pitch: "A levee-town that survives by taxing the river it fears."
spoiler: low
surface:
  - dialogue
  - environment
---

## Function
The player's first hub; introduces water-tithe law and the conflict
between civic survival and ritual obligation.

## Canon summary
Built where three raised channels meet a blackwater basin, Marshgate
Weir began as a flood refuge and became a toll city after
[[second_drowning|the Second Drowning]]. Its rulers, [[salt_tribunal]],
claim ownership of all elevated waterworks...

## Visible traits
Bronze flood bells. Stone slabs engraved with water quotas...
```

**Base frontmatter (all types):**

| field | required at | validated how |
|---|---|---|
| *(filename stem)* | always | `[a-z0-9_]+`; unique vault-wide; folder matches `type` |
| `title` | always | non-empty |
| `type` | always | one of `hub` · `world_rule` · `timeline_event` · `region` · `location` · `culture` · `faction` · `npc` · `wildlife` · `item`; `hub` used exactly once, by `bible.md`, the only root-level file |
| `status` | always | `draft` · `reviewed` · `canon` · `deprecated` |
| `region` | always | `world` or an existing `regions/` entry id |
| `pitch` | reviewed+ | non-empty one-liner |
| `spoiler` | reviewed+ | `none` · `low` · `high` (see *Skills* for the packet ceiling) |
| `surface` | reviewed+ | list ⊆ `dialogue` · `journal` · `environment` · `rumor` · `quest` · `none`; where this entry is meant to reach the player — `none` is legal but `lore-audit` reports canon stuck at none |
| `tags` | optional | string list; magic/economy/locked have defined meanings (below) |
| `game_ids` | optional | list of `<kind>:<id>` with kind ∈ `npc`·`topic`·`journal`·`item`·`creature`, each resolving to the matching `data/<folder>/<id>.tres` — **validated at every status** (it points at an existing corpus; a typo is wrong regardless of maturity) |
| `superseded_by` | deprecated only, optional | resolves to a live entry |

**Per-type additions:** `location.kind` (required always; `settlement`·`landmark`·`dungeon`·`route`·`danger_zone` — the M2 floors count these) · `timeline_event.era` (required always; drawn from `VALID_ERAS`, a const amended when M2's timeline pass fixes the eras — the `VALID_SLOTS` precedent) · `timeline_event.order` (required always; integer; `(era, order)` unique) · `npc.culture` / `location.culture` (optional; resolves to a `cultures/` entry). Unknown keys are **rejected** — the suite checks every key against the base + per-type sets, so `titel:` is a test failure, not silent data loss.

**The body spine (all types except `hub`):** eight `## ` sections, present in this relative order at reviewed+ — *Function · Canon summary · Visible traits · Systems impact · Relationships · Quest hooks · Environmental storytelling · Open questions*. The same spine for everything is what makes retrieval uniform (canon-packet reads sections by name); each type's template reinterprets, not replaces (a timeline event's *Visible traits* are its present-day consequences; a wildlife entry's *Systems impact* is encounters and alchemy). Extra sections are allowed. **Cultures additionally require** *Naming conventions*, *Speech & register*, and *Material culture* sections — the report's naming guide and tone sheet, kept attached to their culture. **Quest hooks must hold ≥3 `- ` bullets at reviewed+ for the four narrative-anchor types** (location, faction, npc, culture); hooks on other types are encouraged, not counted — a counted hook on a mushroom is filler.

### The strict YAML subset — the architectural decision

Godot has no built-in YAML, installing an addon needs sign-off, and full YAML would accept structures no validator here wants. So the vault speaks a **strict subset**, and the parser enforces it with line-numbered errors. *The subset is the schema's first gate*: anything the parser rejects never reaches semantic validation, and every file the parser accepts is trivially machine-readable forever.

Grammar, in full: line 1 is exactly `---`; frontmatter ends at the next line that is exactly `---`; everything after is the body. Between the fences, each non-blank line is one of exactly two forms — `key: value` (a scalar: split on the first `: `, value trimmed, optional surrounding double quotes stripped, no escape processing, empty values rejected) or `key:` alone (opens a string list: zero or more following lines of exactly two spaces + `- ` + non-empty item, trimmed, optional quotes stripped). Keys match `[a-z_][a-z0-9_]*`. Blank lines are ignored. **Rejected, each with the offending line number:** tabs anywhere, duplicate keys, `#` comments, nested maps, inline arrays (`[a, b]`), multiline scalars, list items without an open list, lines matching neither form, a missing closing `---`.

The parser knows grammar only; the canon suite knows the schema (required fields, allow-lists, unknown keys). That split keeps the parser reusable and the schema in one place — the tests.

### Wikilinks & the link graph

`[[id]]` and `[[id|shown text]]` — the exact 005 syntax. *Decision: reuse `DialogueMarkup`, don't copy it.* The regexes would be identical by design; `class_name` scripts are globally visible; and `tests/data/test_dialogue_topics.gd` already consumes `DialogueMarkup` from outside the dialogue layer, so the precedent exists. Two drifting copies of one regex is the real failure mode. The cosmetic misnomer (`extract_topic_ids` returning lore ids) costs a comment; if a third consumer ever appears, promote the class to a neutral home *then*, not now.

Link extraction runs on the body **after stripping fenced code blocks and inline code spans** — naming guides and speech sections will quote example dialogue containing markup, and quoted examples must never create graph edges or failures. Wikilinks are banned inside frontmatter values (scanned; failure). After extraction, any surviving `[[` or `]]` in the stripped body fails the suite — the 005 stray-markup rule, which also deliberately rejects Obsidian's `[[path/note]]` and `[[id#heading]]` forms: links are flat ids, always.

**The namespace rule:** topic ids (`data/dialogue/`) and lore ids (`docs/lore/`) are separate namespaces resolved against separate corpora by separate suites. Giving a player-surfaced lore entry the same id as its dialogue topic (`the_old_barrow` both places) is an encouraged convention that `lore-audit` reports on — never a hard test. A hard cross-corpus link would block dialogue work until lore exists; 005's placeholders predate the bible by design.

**Dangling links hard-fail at every status, and the escape is the stub ritual.** The link graph is the retrieval index — canon-packet walks it — so a dangling link is a silently broken query, not a soft TODO. When writing an entry that needs a not-yet-written neighbor, create the neighbor as a `status: draft` **stub** in the same change (`new-lore-entry --stub`: frontmatter, title, pitch if known, an *Open questions* section holding what's unknown). This is the report's "no silent invention" rule mechanized: a gap becomes a visible, linkable, greppable work item instead of an improvised fact or a broken edge. `grep -rn "status: draft" docs/lore` is the standing work queue.

Deprecation: inbound links from live entries to a `deprecated` entry fail the suite (deprecating an entry forces relinking its neighborhood — that's the point); deprecated→deprecated links are legal (frozen pairs stay frozen); every link still has to resolve to *some* entry regardless of status.

### Status lifecycle & graduated validation — the architectural decision

`draft → reviewed → canon`, plus `deprecated` as the exit. Draft is where agents work freely; reviewed means the director has read it and the full spine holds; **canon is ratified truth — only the director sets it.** Ratification is process, enforced by review: the `canon-keeper-reviewer` flags any diff hunk that adds `status: canon` and demands director ratification evidence from the session; a canon body edited without a status downgrade or a director note is likewise flagged. (Canon *demotion* is caught by review, not tests — an accepted gap; tests can't know intent.)

Validation strictness follows status, so rigor lands where it protects canon and stays out of drafting's way:

| check | draft | reviewed | canon | deprecated |
|---|---|---|---|---|
| parses · filename/id shape · unique id · known keys · type/folder agreement · status/region/kind/era/order valid · title non-empty | ✓ | ✓ | ✓ | ✓ |
| body links resolve · no live→deprecated links · no frontmatter links · no stray markup · `game_ids` resolve | ✓ | ✓ | ✓ | ✓ |
| may be a link target of live entries | ✓ | ✓ | ✓ | ✗ |
| reachable from `bible.md` | ✓ | ✓ | ✓ | exempt |
| `pitch` · `spoiler` · `surface` present · full 8-section spine in order · culture extras · Quest hooks ≥3 (anchor types) | — | ✓ | ✓ | frozen as-was |
| Canon summary 3–7 sentences · hooks concrete and actionable | — | — | canon-keeper checklist, **not** a test (sentence-counting regexes are clever-brittle; taste belongs to the reviewer) | — |

**Reachability replaces `EXPECTED_COUNT`.** *Decision:* the data validators pin counts because game content grows one reviewed file at a time; the vault grows in bulk during passes, and a count pin would tax exactly the workflow this system exists to serve. What the vault needs instead is the guarantee that nothing is orphaned: **every non-deprecated entry must be reachable from `bible.md` by BFS over body wikilinks.** This is 005's every-topic-reachable-by-keyword test transposed — the same invariant (no unreachable content), enforced on a different graph. The report's minimum numbers still appear, as `≥` floors per milestone (below), never `==` pins.

### bible.md — the hub

`type: hub`, the only root-level file, the reachability root, and the master document the report calls the "sample lore-bible section template" — nine `## ` sections, all present from M1 on: **Core promise** (the world fantasy one-liner, emotional palette, ≥3 forbidden clichés) · **Rules of the world** (cosmology / magic / technology / death, travel, communication — one-liners linking into `rules/`) · **Historical spine** (the era list — `VALID_ERAS`' source of truth — with one-liners linking into `timeline/`) · **Regional map index** (the active region, locked stubs, travel methods — the main reachability artery into `regions/`) · **Peoples & powers** (links into `cultures/`, `factions/`, `wildlife/`; religions are culture sections in v1) · **Content grammar** (dialogue-tone defaults, naming meta-rules pointing at per-culture sections, material logic, forbidden tropes, and the markup/style rules for lore text itself) · **Player-facing surfaces** (the `surface` field contract and spoiler policy) · **Aesthetic brief** (6–12 described visual references; the 5 texture / 5 audio / 5 dialogue-tone word lists; the MDA lens note) · **Open questions**.

**The non-duplication rule:** master-plan §1 owns the *product* pillars (Exploration · Guilds & Consequence · Character Building) and keeps them; `bible.md` owns the *world* promise and links to master-plan §1 rather than restating it. The master plan triages features; the bible triages content; neither quotes the other.

**The one-active-region rule:** exactly one `regions/` entry is active — every other region entry carries `tags: [locked]` and exists only as a stub for the Regional map index to point at. The report is emphatic here and the scope budget agrees: one region, built deep, before any breadth. (The floors test enforces exactly-one-active.)

### Parser, entry model, vault — the code

All in `scripts/lore/`, `class_name`, pure RefCounted, zero scene-tree dependencies, no caching — the `CombatMath`/`DialogueMarkup` testability pattern. Every class has a from-string path so unit tests run on fixtures without touching the filesystem.

| class | API |
|---|---|
| `LoreFrontmatter` | `static func parse(source: String) -> LoreFrontmatter` — fields `ok: bool`, `error: String`, `error_line: int`, `scalars: Dictionary[String, String]`, `lists: Dictionary[String, PackedStringArray]`, `body: String`; helpers `get_scalar(key, default)`, `get_list(key)` |
| `LoreEntry` | `static func from_string(path: String, text: String) -> LoreEntry` · `static func load_file(path: String) -> LoreEntry` — fields `id` (filename stem), `path`, `type`, `status`, `frontmatter`, `sections: Dictionary[String, String]` (split on `## ` headings, insertion-ordered), `body_links: Array[StringName]` (fence-stripped, then `DialogueMarkup.extract_topic_ids`) |
| `LoreVault` | `static func load_vault(root: String = "res://docs/lore") -> LoreVault` — `DirAccess` recursion skipping `_`-prefixed directories and non-`.md` files; fields `entries: Dictionary[StringName, LoreEntry]`, `errors: Array[String]` (parse failures, duplicate ids); `func reachable_from(id: StringName) -> Dictionary[StringName, bool]` (BFS over body links) · `func inbound_links_to(id: StringName) -> Array[StringName]` |

`res://docs/lore` reads fine headless and in-editor — `.md` files are plain project files that `FileAccess` opens without import; exported builds simply won't contain them, which is correct (see *Out*). Perf is measured at M0's commit 4: a few hundred small files through `FileAccess` plus one regex is well under a second; if the vault ever proves otherwise, the named fallback is one shared static vault across suite files — not built now.

### The worldbuilding process — the architectural decision

The report's passes become this spec's milestones, run as **director sessions driven by the `worldbuilding-pass` skill**: the agent loads the pass's prompt pack, reads `bible.md` and every prior pass's entries (no pass writes in a vacuum), asks the director the pass's decision questions, offers candidate options (2–3 per open question — e.g. three candidate regional twists), and turns the director's choices into `status: draft` entries via `new-lore-entry`. **The agent generates options and drafts; the director decides. Nothing lands as canon in any pass** — canonization is its own M3 session.

**Blank slate, stated as a ruling:** the world is invented from zero in M1. The existing marsh-village placeholder content (`seld`/`hunald`/`maera`, the village/barrow/bog-hound topics, the creatures) is **not** a seed and nothing about it is assumed to survive; it is retrofitted to whatever canon emerges (see *Placeholders & the retrofit flow*). The report's own demo IP (Marshgate Weir, the Salt Tribunal) is equally not-canon: it lives in `_examples/` as schema reference only. M1 opens with the report's ritual — a five-minute director brain-dump reduced to a one-page brief — and its first decisions are the world's hook, tone, player fantasy, thematic contrasts, forbidden clichés, and the active region's **one defining ecological or metaphysical twist**, traced into food, housing, ritual, travel, monsters, and economy across M2.

Pass order within M2 is the report's, kept because it moves from structural facts to social expression — each pass consumes its predecessors:

| pass | floor (tested, `≥` never `==`) |
|---|---|
| geography | 3 `settlement` · 8 `landmark`+`dungeon` · 2 `route` · 2 `danger_zone` locations in the active region |
| timeline | 12 events across ≥2 eras; `VALID_ERAS` amended from bible's Historical spine; `(era, order)` unique |
| cultures | 2 cultures, each with *Naming conventions* / *Speech & register* / *Material culture* sections |
| factions | 3 faction entries — the future guilds — each with mission, power base, enemies, recruitment verbs in *Function*/*Relationships*, and ≥3 quest hooks by M3 review |
| magic rules | 1 `rules/` entry tagged `magic`: sources, costs, limits, social attitudes, legal status, item implications — **feeds spec 008** |
| economy | 1 `rules/` entry tagged `economy`: key resources, shortages, black markets, sacred goods, travel friction, taxation |

The **canon-safe two-pass rule** governs all generation everywhere (skills enforce it): Pass 1 retrieves only supported facts, each cited to an entry id, and lists gaps; Pass 2 normalizes into the target shape and **introduces no new facts**. Gaps become stubs or director rulings — never improvisation.

The quest/dialogue pass and the environmental-storytelling pass are **deliberately deferred to 006 and 010** — their prompt packs ship in `worldbuilding-pass` now, but surface content written before its surface systems exist rots as those specs land. The report's vertical-slice validation (1 hub, 1 wilderness route, 1 dungeon, 3 factions, 15–30 NPCs, 1 branching quest chain; audits: *can a player infer this world without codex text? do rules create visible consequences? can creators find canon quickly?*) is restated as **010's exit checklist**, not tested here.

### Skills & the canon keeper

Four skills and one reviewer agent carry the report's team roles (canon keeper, narrative lead, producer) and AI guardrails. The spec pins each contract; full SKILL.md text lands at M0.

| skill | contract |
|---|---|
| `new-lore-entry` | Scaffold one entry: check the id is globally free and naming-guide-conformant → copy `_templates/<type>.md` (**templates live in the vault, not the SKILL** — single source) → fill frontmatter (`status: draft`, always) → write title/pitch/*Function*/*Open questions* → **add one inbound `[[link]]` from the parent entry** (region→location, bible→region — this is what keeps reachability green) → run the lore suite. `--stub` mode stops after *Open questions*. May never set status above draft. |
| `canon-packet` | Assemble a cited fact packet before writing **any** player-facing text. Set the spoiler ceiling (player-facing ⇒ exclude `spoiler: high` unless the director overrides) → Pass 1: seed via grep (ids, titles, `game_ids`), follow body links ≤2 hops, prefer canon > reviewed > draft (drafts flagged ▲), extract only facts present in entries, cite each `[entry_id]`, list gaps → Pass 2: emit the packet, no new facts → route gaps to the director (stub or ruling). The packet is an **ephemeral** fenced block — scratchpad or conversation only, never committed; a committed packet is a cache that rots. |
| `lore-audit` | The beyond-GUT sweep, report-only, run at milestone ends and before canonization: canon entries resting on draft links · canon at `surface: none` · topic↔lore id alignment for player-surfaced entries · `game_ids` vs actual `data/` stems · naming-guide conformance of new proper nouns · the report's red-team prompts ("what contradicts this region brief?", "which names violate the naming guide?") · the originality strip-test (proper nouns removed — still identifiable by climate logic, political tensions, religious assumptions, material culture, speech rhythm?). Findings become an Open question, a stub, or a fix — the director chooses; the skill never edits. |
| `worldbuilding-pass` | Drive ONE named pass (`foundation` · `geography` · `timeline` · `cultures` · `factions` · `magic` · `economy` · `schema_stress` · `quests` · `dialogue`) as an interactive director session per the process above. Embeds the report's prompt packs verbatim-adapted (regional generation; culture + naming guide — phoneme patterns, place-name patterns, personal names by class, five idioms, speech registers by rank, signage words, no real-language copies, no apostrophe gibberish; faction quest seeding — 12 seeds: ≥4 noncombat, ≥3 exposing faction hypocrisy, ≥4 traveling to a named landmark, ≥2 changing the environment on completion, each naming an NPC role and a concrete item or document; dialogue — 6 one-liners, 2 informers, 1 life story, 1 decision conversation, every line tagged with the canon fact id it depends on). May never set canon. |

Canon-packet output shape (what 006/010 writing sessions consume — the *Facts/Voice/Names* blocks map straight onto dialogue and journal text, and the citation ids travel into review notes for the canon keeper to check lines against):

```
# Canon packet — <task>
Spoiler ceiling: low        Statuses used: canon, reviewed (▲ = draft)
## Facts
- <one sentence per fact> [entry_id]
## Voice
- <register, markers, idioms for the speaking culture> [culture_id]
## Names & terms
- approved: ... · forbidden: ... [culture_id, bible.md Content grammar]
## Gaps — do not invent
- <question> (→ stub or director ruling)
```

**`canon-keeper-reviewer`** (`.claude/agents/`, the golden-rule-reviewer shape: Read/Grep/Glob/Bash, review-only): start from `git diff` restricted to `docs/lore/` and hunt, severity-ordered, reporting `file:line — what — which entry or rule it violates`: uncited invention (new factual claims contradicting or absent from linked entries) · unratified `status: canon` additions · silent canon edits · naming-guide violations in new proper nouns · spoiler leaks (`spoiler: high` facts surfacing in lower-spoiler entries or player-facing text) · forbidden-trope hits vs `bible.md` Content grammar · the taste checks the tests skip (Canon summary 3–7 sentences; hooks concrete and actionable).

### Placeholders & the retrofit flow

`game_ids` is the bridge: a canon entry lists the game content it backs (`npc:seld`, `topic:the_old_barrow`), each resolving to the matching `.tres` — so the link between canon and playable surfaces is greppable in both directions and validated in one.

M3's retrofit commit is **the one sanctioned ripple into `data/`**, cashing 005's "renames are cheap `.tres` edits" promise: map every placeholder — 3 NPCs, 5 topics, 3 journal entries, 3 creatures, and any flavor items canon claims — to a canon entry; rename ids to canon names **and rewrite the prose to canon voice via canon-packet** (a rename without a voice pass would leave generic-fantasy text under canon names); the director approves every line; the 005 validators plus the lore suite catch every missed reference on both sides. The retrofit floor: after M3, **every file stem in `data/npcs/`, `data/dialogue/`, `data/journal/`, and `data/creatures/` is claimed by exactly one entry's `game_ids`** — all shipped narrative content canon-backed. (`data/items/` is audited by `lore-audit`, not floored: `iron_sword` needs no lore entry.)

### The faction fence

**A `factions/` entry is canon *about* a faction, never a game type.** The lore bible needs factions now — they anchor quest hooks, cultures, and the M2 skeleton — but the 005 ruling stands: `NPCDef` stays id + name + flavor, and no `FactionDef`, rank, reputation, or disposition data exists until the Phase 2 faction spec, which will consume these prose entries as its design input. The decision-log row lands with this spec.

### Why this doesn't rot

The report names the ways lore bibles die; each gets a boring, mechanical counter:

| rot mode | counter |
|---|---|
| canon drift / contradiction | link integrity at every status · canon-keeper diff review · two-pass packets with citations · no silent canon edits |
| silent invention | dangling links hard-fail · the stub ritual · packet *Gaps — do not invent* section · `worldbuilding-pass` never canonizes |
| siloed / orphaned lore | reachability-from-bible in the suite · every pass reads prior passes · one hub |
| lore never reaching play | `surface` field + lore-audit's canon-at-none report · `game_ids` validated both ways · the M3 retrofit proves the loop · quest/env passes bound to the specs that play them |
| bible/index staleness | the bible is the reachability *root* — it cannot go stale without the suite failing |

Named honestly: the spoiler ceiling is policy, not cryptography — acceptable for a solo project; canon demotion is caught by review, not tests; and if the vault's growth ever outpaces the suite, the shared-vault fallback exists.

## Architecture

| file | role |
|---|---|
| `scripts/lore/lore_frontmatter.gd` | `LoreFrontmatter` — the strict-subset parser |
| `scripts/lore/lore_entry.gd` | `LoreEntry` — id/sections/links model over one file |
| `scripts/lore/lore_vault.gd` | `LoreVault` — loader, graph, reachability |
| `docs/lore/bible.md` | the hub (stub at M0; filled by M1) |
| `docs/lore/_templates/` (entry_base + 9 types) | authoring templates — the single source `new-lore-entry` copies |
| `docs/lore/_examples/` (2 files) | the report's demos converted to this schema; quarantined |
| `docs/lore/{rules,timeline,regions,locations,cultures,factions,npcs,wildlife,items}/` | the typed folders (empty at M0 save `.gitkeep`s) |
| `tests/lore/test_lore_frontmatter.gd` | grammar accept/reject fixtures with line numbers |
| `tests/lore/test_lore_entry.gd` | sections, links, pipe form, dedup, fence stripping |
| `tests/lore/test_lore_vault.gd` | graph build, duplicate ids, BFS, quarantine, inbound |
| `tests/lore/test_lore_canon.gd` | the real-vault canon suite — **the Phase 3 quality gate** |
| `tests/lore/test_lore_floors.gd` | milestone `≥` floors (lands at M1, grows per pass) |
| `.claude/skills/new-lore-entry/SKILL.md` | scaffold skill |
| `.claude/skills/canon-packet/SKILL.md` | cited-retrieval skill |
| `.claude/skills/lore-audit/SKILL.md` | drift/silo/surface audit skill |
| `.claude/skills/worldbuilding-pass/SKILL.md` | director-session skill + prompt packs |
| `.claude/agents/canon-keeper-reviewer.md` | lore diff reviewer |

**Modified:** `docs/master-plan.md` (three decision rows, §4 queue row for 011, §5 pipeline path `docs/lore-bible.md` → `docs/lore/`, §9 status — landed with this spec's commit) · `CLAUDE.md` (folder layout: `docs/lore/`, `docs/research/`; new *Lore & canon* section; current focus — same commit) · `.gitignore` (`.obsidian/`, at M0 commit 4).

**Moved:** the research PDF → `docs/research/lore-bible-research.pdf` (landed alongside this spec).

**Deleted:** none.

**`BalanceConfig` additions: none.** The vault holds no tunable numbers — the floors are acceptance criteria, not balance.

## Acceptance criteria (GUT tests — all headless; no scene tests, nothing here touches the scene tree)

1. **Parser accepts (unit, string fixtures):** scalars, quoted scalars, lists, empty lists, blank lines inside frontmatter; the body is preserved byte-for-byte after the closing `---`; `get_scalar` defaults and `get_list` on missing keys behave.
2. **Parser rejects with correct line numbers (unit):** missing opening/closing `---`, tabs, duplicate keys, comments, nested maps, inline arrays, empty scalar values, bad key shapes, list items with no open list, lines matching neither form.
3. **Entry model (unit):** id from filename stem; `## ` section split preserving relative order; link extraction finds plain and `|label` forms, deduplicates in first-appearance order, and ignores links inside fenced code blocks and inline code spans.
4. **Vault (unit, `from_string` fixtures):** graph build; duplicate ids land in `errors`; `_`-prefixed directories and non-`.md` files are skipped (asserted by comparing the walker's file list against a raw recursive listing); BFS reachability; `inbound_links_to`.
5. **Canon suite — files & ids:** every `.md` under the walked vault parses; ids unique vault-wide and `[a-z0-9_]+`; folder matches type; `hub` exactly once and only at root; unknown frontmatter keys fail; status/region/kind/era/order values valid; `(era, order)` unique.
6. **Canon suite — the graduated matrix:** per-status requirements exactly as the lifecycle table — spot-fixtures prove a draft needs no spine while a reviewed entry without all eight sections in order, culture extras, or three anchor-type hooks fails.
7. **Canon suite — links:** every body `[[id]]` resolves; no live→deprecated links; no wikilinks in frontmatter values; no stray `[[`/`]]` after markup stripping; `superseded_by` resolves live.
8. **Canon suite — reachability:** every non-deprecated entry reachable from `bible.md` by BFS; deprecated entries exempt; exactly one active (non-`locked`) region once regions exist.
9. **Canon suite — the bridge:** every `game_ids` item is well-formed `<kind>:<id>` with a known kind and resolves to the matching `data/<folder>/<id>.tres`.
10. **M1 floors:** `bible.md` holds all nine hub sections; ≥3 forbidden-cliché bullets in *Core promise*; ≥5 bullets in each of the three Aesthetic-brief word lists; ≥1 region entry exists and is reachable.
11. **M2 floors:** the pass table's numbers, cumulative — locations by kind, ≥12 events across ≥2 eras with `VALID_ERAS` non-empty, ≥2 cultures with required sections, ≥3 factions, ≥1 `magic`-tagged and ≥1 `economy`-tagged rules entry.
12. **M3 floors:** ≥2 non-deprecated entries per typed folder; `bible.md`, the active region, and ≥1 each of culture/faction/location at `status: canon`; every file stem in `data/npcs/`, `data/dialogue/`, `data/journal/`, `data/creatures/` claimed by exactly one entry's `game_ids`.

*(12 is flagged for what it is: together with 5–9 this suite is the quality gate the Phase 3 bulk pipeline runs against — malformed or orphaned generated lore fails the same way malformed dialogue does.)*

## How to implement

One commit each, full suite green before each. M0 is agent work; M1–M2 are director sessions (the agent asks, offers, drafts — the director decides); M3 mixes both. The amendment ritual applies throughout — deviations amend this spec in the same commit.

**M0 — system bootstrap:**
1. `lore: strict frontmatter parser` — `LoreFrontmatter` + criteria 1–2.
2. `lore: entry model` — `LoreEntry` (fence stripping, `DialogueMarkup` reuse) + criterion 3.
3. `lore: vault loader and link graph` — `LoreVault` + criterion 4.
4. `lore: vault skeleton and canon suite` — the `docs/lore/` tree, `bible.md` stub (`type: hub`, `status: draft`, empty section skeleton), `_templates/`, `_examples/` (the two converted report demos), `test_lore_canon.gd` (criteria 5–9), `.gitignore` + `.obsidian/`; measure suite runtime here.
5. `lore: authoring and packet skills` — `new-lore-entry`, `canon-packet`.
6. `lore: audit and pass skills, canon keeper` — `lore-audit`, `worldbuilding-pass`, `canon-keeper-reviewer`.
7. `docs: lore M0 status` — master-plan §9 + CLAUDE.md current focus tick to "M1 foundation session next".

**M1 — foundation pass:**
8. `lore: foundation pass` — the blank-slate director session (`worldbuilding-pass foundation`): brain-dump → one-page brief → `bible.md` seeded (promise, rules-of-world one-liners, aesthetic brief, content grammar, forbidden clichés), the active region entry drafted and named by the director, its defining twist chosen from offered candidates; `test_lore_floors.gd` lands with criterion 10.

**M2 — regional skeleton, six passes in report order:**
9. `lore: geography pass` — locations per the floor; bible's Regional map index grows.
10. `lore: timeline pass` — eras fixed in *Historical spine*, `VALID_ERAS` amended, ≥12 events.
11. `lore: cultures pass` — ≥2 cultures with naming/speech/material sections.
12. `lore: factions pass` — ≥3 prose factions (the future guilds).
13. `lore: magic rules pass` — the `magic`-tagged rules entry (spec 008's design input).
14. `lore: economy pass` — the `economy`-tagged rules entry.
*(Each commit: drafts + inbound links + the floor test raised. Criterion 11 complete after 14.)*

**M3 — schema stress, first canon, retrofit:**
15. `lore: schema stress` — fill to ≥2 entries per type (the report's two-examples rule: a schema that survives two of everything is real).
16. `lore: first canon batch` — director ratification session; `bible.md`, the active region, and the core spine promoted; canon-keeper reviews the promotion diff.
17. `content: retrofit placeholders to canon` — the sanctioned `data/` ripple per *Placeholders & the retrofit flow*; criterion 12's bridge floor goes green.
18. `docs: lore bible live` — master-plan §9 ("lore bible live: N entries, M canon; 006/010 write from canon packets") + CLAUDE.md focus → spec 006.

**Handoff:** 006 and 010 run the `quests` and `dialogue`/environmental passes with `worldbuilding-pass` + `canon-packet`; the report's vertical-slice audit is 010's exit checklist; a typed `quest_links` field, if 006 wants one, is 006's amendment to make.

**Debug workflow** *(replaces the debug scene — a deliberate substitution: this spec ships no runtime feature, so manual verification is editorial, not playable)*: open `docs/lore/` in Obsidian — links navigate, graph view shows the bible-rooted web, orphans are visually obvious · dry-run `canon-packet` for one NPC's greeting and confirm every fact carries a citation · run `lore-audit` and read the findings · `grep -rn "status: draft" docs/lore` — the standing work queue.
