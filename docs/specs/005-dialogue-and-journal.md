# Spec 005 — Dialogue (Topic-Based) & Journal

**Status:** ready to implement
**Depends on:** 002 (ItemDef/ItemStack/Inventory for give-take effects), 003 (Interactable wiring, `Game` autoload + identity injection, CanvasLayer panel pattern, the TalkStub replacement contract)
**Consumed by:** 006 (quest stages reference `JournalEntryDef` ids; quest triggers ride response effects), 007 (save/load serializes the `Journal` resource `Game` holds), 010 (village NPC content), Phase 2 (persuasion/disposition/barter extend the dialogue panel), Phase 3 (bulk LLM generation targets these schemas; the validators are the quality gate)

## Scope

**In:** `NPCDef` content type + a generic def-driven `Npc` scene replacing TalkStub · `DialogueTopicDef` with ordered, condition-filtered responses (shared topics; per-NPC or fallback answers) · keyword unlocking via validated inline `[[topic_id]]` markup rendered as clickable highlights · greetings as a reserved `greeting` topic · response effects: add journal entry, unlock topics (via markup), give/take items · a `Journal` resource (chronological entries + known topics) owned by `Game`, injected at spawn · dialogue panel UI · journal panel + `journal` (J) input action · starter content (3 NPCs, 5 topics, 3 journal entries) · three data validators · debug scene · tests.

**Out (later specs / backlog):** persuasion checks, disposition, bribes (Phase 2 — the `persuasion` skill from 001 exists and **stays inert**; no dialogue reads it in v1) · barter and gold in dialogue (gold is not an ItemDef; give/take is items only — note in code) · quest stages and journal grouping (006) · voiced dialogue (**rejected permanently** — text-first pillar) · NPC schedules/movement (NPCs are stationary talkers) · random barks/idle lines · a topics-index tab in the journal UI · day-stamped journal entries (no in-game clock exists; entries are sequence-ordered until a clock spec) · dialogue choices / player-authored lines (this is a topic system, not a branching-tree system) *(Amendment, spec 013: superseded — decision points now resolve by choice prompts on responses; the topic system stays primary)* · keyword markup inside journal entry text (journal renders plain text in v1) · a silent `unlocks_topics` field (one unlock mechanism only; see below).

## Design

### Content model — the architectural decision

Four new Resource classes: two content types with data folders, one sub-resource (the `ItemStack` pattern), one runtime-state resource. All ids follow the id-by-convention rule: `id` equals the filename stem, and `StringName` references resolve to `res://data/<type>/<id>.tres`, checked by validators — the loose coupling the Phase 3 bulk-generation pipeline needs.

**`NPCDef`** (`scripts/resources/npc_def.gd`, `data/npcs/` — new content type per the Golden Rule):

| field | type | meaning |
|---|---|---|
| `id` | StringName | unique, == filename stem |
| `display_name` | String | prompt/panel name ("Talk Hunald") |
| `description` | String (multiline) | flavor; unused by systems in v1 |

Deliberately minimal — no faction, no disposition, no stats. Creatures got the "not characters" ruling in 004; NPCs get the mirror ruling: **an NPCDef is a dialogue anchor with a name.** Anything more (factions, schedules, NPCs that fight) is a future spec's decision — don't grow this silently.

**`DialogueTopicDef`** (`scripts/resources/dialogue_topic_def.gd`, `data/dialogue/`):

| field | type | meaning |
|---|---|---|
| `id` | StringName | unique, == filename stem; the id used by `[[markup]]` |
| `display_name` | String | topic-list label AND default rendered keyword text |
| `lore_sources` | Array[StringName] | *(Amendment, spec 006:)* lore entry ids the topic's text derives from — ≥1 required (`greeting` exempt), vault-validated |
| `responses` | Array[DialogueResponse] | ordered; **first match wins** |

**`DialogueResponse`** (`scripts/resources/dialogue_response.gd`) — a sub-resource inside the topic `.tres`, no data folder of its own, exactly like `CreatureDef.loot`'s ItemStacks. *Decision: sub-resources, not separate files* — a topic is one reviewable file, the LLM pipeline generates one topic per file against one schema, responses have no independent identity, and the validator walks the nested array the same way `test_creature_defs.gd` walks loot. Fields are flat — no nested condition trees — so validators and generators stay simple:

| field | type | role | meaning |
|---|---|---|---|
| `npc_id` | StringName = `&""` | condition | empty = any NPC (fallback); else only that NPC |
| `requires_topics` | Array[StringName] | condition | all must be known to the player |
| `requires_journal` | Array[StringName] | condition | all entries must be in the journal |
| `blocked_by_journal` | Array[StringName] | condition | *(Amendment, spec 006:)* none of the entries may be in the journal — the negative gate for cross-NPC branch exclusion; counted by `is_unconditional()` |
| `take_items` | Array[ItemStack] | effect **and implicit condition** | see *Give/take semantics* |
| `choice_gated` | bool = false | condition | *(Amendment, spec 013:)* eligible only when navigation came from a choice press (`from_choice = true`); invisible to topic/keyword clicks and `available_topics`; counted by `is_unconditional()` |
| `text` | String (multiline) | effect | the spoken line, with `[[markup]]` |
| `journal_entry` | StringName = `&""` | effect | JournalEntryDef id to add (idempotent) |
| `give_items` | Array[ItemStack] | effect | added to the player inventory |
| `choices` | Array[DialogueChoice] | effect / presentation | *(Amendment, spec 013:)* player-voiced replies offered after this response is spoken, rendered as buttons; a `DialogueChoice` (sub-resource, the ItemStack pattern) is `text` (plain, no markup) + `topic` (answered with `from_choice = true`; empty = dismissal, the prompt lapses) |

Conditions AND together; a response with every condition empty is an unconditional fallback. *(Amendment, spec 013: `choice_gated = true` counts as a condition, so a gated commit ordered before later responses is legal.)* Authoring convention: specific responses first, fallback last — enforced by the validator (no response may follow a fully-unconditional one; unreachable content fails the suite).

**`JournalEntryDef`** (`scripts/resources/journal_entry_def.gd`, `data/journal/`): `id: StringName`, `text: String` (multiline). *(Amendment, spec 006: plus `lore_sources: Array[StringName]` — ≥1 cited lore entry id, vault-validated.)* *Decision: entries are defs with ids, not free text in the effect.* Content-as-data; 006 will gate quest stages on entry ids and `requires_journal` already needs ids to point at; free text in effects would be unreferenceable and duplicated. No date field — order is runtime state (see *Journal* below).

### Keyword unlocking — the architectural decision

**Inline markup IS the unlock mechanism.** Syntax: `[[topic_id]]` renders the topic's `display_name`; `[[topic_id|shown text]]` renders custom text (grammar/case). When a response is **displayed**, every marked topic in its text is learned — no click required. Clicking a highlighted keyword is *navigation*: if the current NPC has a response for that topic, the panel jumps to it. *(Amendment, playtest: if the NPC has no response, the panel appends a dim "(X has nothing to say about that.)" notice — a highlighted keyword that silently no-ops reads as broken.)*

Rejected alternatives: auto-scanning response text for topic display names (Morrowind-authentic but magic — invisible to validators, breaks on substrings, localization-hostile) and a bare `unlocks_topics` array (validatable but invisible to the player — keywords you can't see defeat the discovery loop). Markup is simultaneously the visual highlight, the unlock, and a validator target: **every `[[id]]` in every response must resolve to an existing topic file or the data suite fails** — exactly the malformed-content rejection Phase 3 needs.

Rendering: `DialogueMarkup.to_bbcode()` converts `[[id]]` / `[[id|label]]` to `[url=id][color=...]label[/color][/url]` for a RichTextLabel with `meta_clicked`. Parse regex: `\[\[([a-z0-9_]+)(?:\|([^\]\|]+))?\]\]`. Unparseable bracket text passes through literally at runtime (and the validator rejects it in data files).

### Greetings & topic seeding

**A reserved topic id `&"greeting"`** (`data/dialogue/greeting.tres`) — a Morrowind-style conditioned greeting list reusing the exact same response-selection machinery, instead of a parallel per-NPC greeting field. Rules: it is evaluated and displayed automatically when the panel opens; it never appears in the visible topic list; the validator requires it to exist and to resolve to a non-null response for *every* NPC in `data/npcs/`.

**The player starts knowing zero topics.** Every known topic was unlocked by a keyword in some displayed response — usually a greeting. No hardcoded seed list in code (Golden Rule), no special "starting topics" state for 007 to serialize. The greeting *is* the seed.

### Journal — runtime state and the sanctioned `Game` addition

**`Journal extends Resource`** (`scripts/resources/journal.gd`) — pure data + pure logic, no signals, no node refs, mirroring `Inventory`:

```gdscript
@export var entries: Array[StringName] = []        # chronological; order IS the date
@export var known_topics: Array[StringName] = []   # discovery order

func add_entry(id: StringName) -> bool      # false + no mutation if already present
func has_entry(id: StringName) -> bool
func learn_topic(id: StringName) -> bool    # idempotent, same contract
func knows_topic(id: StringName) -> bool
```

*One resource, not two:* known topics are conceptually part of the journal (the inspiration's journal literally had a topic index), and it keeps the sanctioned `Game` growth to a single field. *Date decision:* no in-game clock exists; array order is chronology and the UI shows "Entry N". Day stamps are backlog behind a clock spec.

**Explicit `Game` sanction (per 003's "no other global state goes into `Game` without a spec saying so"):** `Game` gains `journal: Journal`, created in `_ready()` alongside `character_sheet` / `inventory`, injected at spawn via the extended signature `player.setup_identity(sheet, inventory, journal)` (before `add_child`, as today). The player exposes `journal`; nothing ever reads `Game.journal` ambiently. 007 inherits it for free — "serialize what Game holds."

### Pure-logic core

All in `scripts/dialogue/`, static, RefCounted, zero scene-tree dependencies — the `CombatMath` testability pattern. Fully deterministic (no RNG), so unit tests need no injection hooks.

| class | API |
|---|---|
| `DialogueMarkup` | `static func extract_topic_ids(text: String) -> Array[StringName]` · `static func to_bbcode(text: String, display_names: Dictionary) -> String` |
| `DialogueEvaluator` | `static func matches(response, npc_id, journal, inventory, from_choice := false) -> bool` — npc matches, `requires_topics` known, `requires_journal` held, no `blocked_by_journal` entry held *(Amendment, spec 006)*, not `choice_gated` unless `from_choice` *(Amendment, spec 013)*, all `take_items` held (`Inventory.count_of` + `count_equipped`) · `static func pick_response(topic, npc_id, journal, inventory, from_choice := false) -> DialogueResponse` — first match in array order, else null · `static func available_topics(topics: Dictionary, npc_id, journal, inventory) -> Array[DialogueTopicDef]` — topics the player knows (discovery order) with a non-null pick, `greeting` excluded · `static func apply_effects(response, journal) -> EffectReport` — learns every `extract_topic_ids(text)` id and adds `journal_entry`. *(Amendment: item effects moved out of `apply_effects` — the panel applies `take_items`/`give_items` through `InventoryComponent` so the player-side signals fire, matching the ContainerPanel precedent; a raw `Inventory` mutation would skip `item_added`/`item_removed`/`encumbrance_changed`.)* |
| `DialogueLibrary` | `static func get_topics() -> Dictionary` — id → DialogueTopicDef, loading `data/dialogue/` via `ResourceLoader.list_directory` (the validator idiom), cached in a static var · `static func reset()` for tests |

`EffectReport` (inner class of `DialogueEvaluator`): `new_topics: Array[StringName]` (only *newly* learned), `journal_entry_added: StringName` (empty if none/duplicate) — so the UI can print "(New topic: X)" / "(Your journal has been updated.)" notices without signals.

### NPC scene — replacing TalkStub

`scenes/world/npc.tscn` + `scripts/world/npc.gd`: `Npc extends StaticBody3D`, `@export var def: NPCDef` — one scene, many defs, exactly like `creature.tscn` (content is data). Placeholder capsule mesh. Children: CollisionShape3D + `Interactable` (verb `&"talk"`); `_enter_tree` copies `def.display_name` into the Interactable (the WorldContainer/TalkStub idiom); `_ready` asserts `def != null` in debug builds. On `interacted(by)`: cast `by` to Player, instantiate `dialogue_panel.tscn`, `add_child`, `panel.open(def, player.journal, player.inventory_component)`, guard re-entry while open with a `_panel` ref — byte-for-byte the `world_container.gd` pattern.

**Interpretation of 003's "replaces the guts, not the wiring" — stated so it isn't a silent choice:** the *wiring* kept is the Interactable child, the "talk" verb, the HUD prompt, and the detector→interact path. Replaced: `talk_stub.gd`, `talk_stub.tscn`, and `tests/scenes/test_talk_stub.gd` are **deleted**; `npc_name: String` yields to `def: NPCDef` (content is data); and the `talk_requested` signal is **dropped** — it has no runtime consumer anywhere in the repo, and `WorldContainer` already established that a world object owns and opens its own panel with the player passed as `by`. Keeping a consumer-less signal to honor 003's letter would be dead API. **This is a formal amendment to 003's world-objects table** (TalkStub row → superseded by `Npc`, spec 005), applied in the same commit per the amendment ritual. The Hunald instance in `scenes/debug/interaction_debug.tscn` migrates to `npc.tscn` + `data/npcs/hunald.tres`.

### Dialogue panel

`scenes/ui/dialogue_panel.tscn`, `DialoguePanel extends CanvasLayer` — ContainerPanel lifecycle: parent instantiates and `add_child`s, calls `open(...)` with injected data, mouse made visible; `close()` restores capture, emits `closed`, `queue_free()`s itself.

- Layout (ugly-but-functional): title = NPC name; left, a scrollable `RichTextLabel` (`bbcode_enabled`) holding a running **transcript** of the conversation (responses appended; cleared per conversation); right, an `ItemList` of available topics; a Goodbye button.
- `open(def, journal, inventory_component)`: evaluate `greeting` for this NPC → render via `DialogueMarkup.to_bbcode` → `apply_effects` → build the topic list. Selecting a topic — or clicking a keyword link (`meta_clicked`) the current NPC can answer — does the same for that topic. **The topic list rebuilds after every response**, so keywords you just read appear immediately: the discovery loop.
- Effect notices appended in a dim style from the `EffectReport`: "(Your journal has been updated.)", "(New topic: bog hounds)", give/take item lines.
- *(Amendment, spec 013:)* a response with `choices` presents them as buttons in a `Choices` container after the topic-list rebuild; pressing one appends the player's line to the transcript in a distinct player-voice style, then navigates to `choice.topic` with `from_choice = true` (empty topic = dismissal). Prompts are **non-modal**: topics, keywords, and Goodbye stay live; navigating away lapses the prompt, which re-presents on re-ask since nothing mutated.
- **Decision — dialogue pauses the game** (`get_tree().paused = true`, panel `process_mode = ALWAYS`, the DeathOverlay precedent): reading long text while a bog hound chews on you is hostile to a text-rich pillar. This deliberately diverges from ContainerPanel (which doesn't pause); JournalPanel behaves the same. `close()` unpauses before freeing.

### Give/take semantics

**`take_items` is an implicit condition:** `DialogueEvaluator.matches` requires the player to hold every `take_items` stack (loose or equipped — `Inventory.remove_item` already drains loose stacks then unequips), so a response that takes what you don't have is simply never shown, and once shown its effects can never fail. No separate `requires_items` field to pair or forget — nothing to misconfigure. Effects therefore apply unconditionally and atomically: take, give, journal, unlocks. A possession check *without* taking is out of scope (add `requires_items` when a spec needs it). `give_items` always succeeds (`add_item` is never weight-blocked, per 002).

### Journal panel & input

New input action `journal`, default **J** (free key), added in project settings like `interact`/`attack`. Handled in the player's `_unhandled_input`: instantiate `scenes/ui/journal_panel.tscn` (`JournalPanel extends CanvasLayer`), `open(journal)`; pauses like the dialogue panel. Content: one scrollable RichTextLabel, entries in chronological order, each rendered "Entry N — <text>" with ids resolved by convention to `res://data/journal/<id>.tres`, auto-scrolled to the latest. Scroll, no pagination. Close button or J again closes; plain text, no keyword markup in v1.

### Starter content

3 NPCs (`data/npcs/`): `hunald` (a hunter — the existing debug NPC), `seld` (a ferryman), `maera` (an herbalist). 3 journal entries (`data/journal/`): `heard_of_the_barrow`, `hounds_in_the_bog`, `selds_ferry_favor`. 5 topics (`data/dialogue/`), chosen so every mechanic is exercised *by data*:

| id | demonstrates |
|---|---|
| `greeting` | per-NPC responses (hunald, seld) + unconditional fallback (maera); texts carry the seed keywords `[[the_village]]`, `[[bog_hounds]]` |
| `the_village` | shared topic: hunald-specific response + fallback for everyone else; unlocks `[[the_old_barrow]]` |
| `bog_hounds` | adds journal entry `hounds_in_the_bog` |
| `the_old_barrow` | first response gated on `requires_journal = [heard_of_the_barrow]` (the richer answer); unconditional fallback second (vague answer, adds `heard_of_the_barrow`) — proves first-match-wins and journal gating across two conversations |
| `a_small_favor` | seld-only; `take_items` rat_pelt ×1, `give_items` healing_draught ×1, adds `selds_ferry_favor` — proves the implicit take-condition. *(Amendment, playtest: a second seld-only "come back with a pelt" nudge response follows the exchange, so the topic stays listed and answerable once learned — first-match-wins picks the exchange whenever a pelt is held. A learned topic that vanishes from the list read as a bug.)* *(Amendment, spec 006: a third response — a completed-state acknowledgment gated `requires_journal` on the favor entry — sits between exchange and nudge, so the completed-and-peltless player gets an answer and the nudge's offer entry can never post-date completion in the Chronicle.)* |

Names are placeholders pending the lore bible; renames are cheap `.tres` edits.

## Architecture

| file | role |
|---|---|
| `scripts/resources/npc_def.gd` | `NPCDef extends Resource` |
| `scripts/resources/dialogue_topic_def.gd` | `DialogueTopicDef extends Resource` |
| `scripts/resources/dialogue_response.gd` | `DialogueResponse extends Resource` — sub-resource only |
| `scripts/resources/journal_entry_def.gd` | `JournalEntryDef extends Resource` |
| `scripts/resources/journal.gd` | `Journal extends Resource` — entries + known topics, pure |
| `scripts/dialogue/dialogue_markup.gd` | `[[markup]]` extraction + BBCode rendering, static + pure |
| `scripts/dialogue/dialogue_evaluator.gd` | response selection, availability, effects; `EffectReport` |
| `scripts/dialogue/dialogue_library.gd` | cached loader for `data/dialogue/` |
| `scripts/world/npc.gd` + `scenes/world/npc.tscn` | def-driven NPC; replaces TalkStub |
| `scripts/ui/dialogue_panel.gd` + `scenes/ui/dialogue_panel.tscn` | conversation UI |
| `scripts/ui/journal_panel.gd` + `scenes/ui/journal_panel.tscn` | journal UI |
| `data/npcs/*.tres` ×3 · `data/dialogue/*.tres` ×5 · `data/journal/*.tres` ×3 | starter content |
| `tests/data/test_npc_defs.gd`, `test_dialogue_topics.gd`, `test_journal_entry_defs.gd` | validators |
| `scenes/debug/dialogue_debug.tscn` + `scripts/debug/dialogue_debug.gd` | debug scene below |

**Modified:** `scripts/systems/game.gd` (sanctioned `journal` field + injection) · `scripts/player.gd` / `scenes/player.tscn` (3-arg `setup_identity`, `journal` var, J-key handling) · `project.godot` (`journal` action) · `scenes/debug/interaction_debug.tscn` (Hunald → `npc.tscn`) · `docs/specs/003-interaction-system.md` (TalkStub amendment note).

**Deleted:** `scripts/world/talk_stub.gd`, `scenes/world/talk_stub.tscn`, `tests/scenes/test_talk_stub.gd`.

**`BalanceConfig` additions: none.** Dialogue v1 has no tunable numbers — no costs, no formulas, persuasion inert; the keyword highlight color is UI styling, not balance. First spec with an empty table, and that's fine.

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Markup (unit):** `extract_topic_ids` finds plain and `|label` forms and ignores non-markup brackets; `to_bbcode` wraps ids in `[url=id]` with the display_name or custom label; text without markup passes through unchanged.
2. **Journal (unit):** `add_entry`/`learn_topic` preserve insertion order and return false without mutating on duplicates; `has_entry`/`knows_topic` correct.
3. **Response selection (unit):** an npc-specific response wins over a later fallback; the fallback serves other NPCs; `requires_topics` and `requires_journal` gate correctly; a response with `take_items` is not matched until the inventory holds them (including equipped copies); null when nothing matches; first-match-wins on order.
4. **Topic availability (unit):** `available_topics` = known ∩ answerable, in discovery order; `greeting` never listed; a topic becomes available on NPC B only after its keyword was displayed anywhere (e.g. at NPC A).
5. **Effects (unit):** applying a response learns exactly the marked ids (idempotently), adds the journal entry once across repeats, removes `take_items` and adds `give_items` on the same `Inventory` instance; `EffectReport` lists only *newly* learned topics and a newly added entry.
6. **NPC scene (scene):** prompt reads "Talk <def.display_name>"; interacting opens the panel showing this NPC's greeting; the panel operates on the player's own `Journal`/`Inventory` instances; re-interacting while open doesn't stack panels.
7. **Dialogue panel (scene):** greeting renders on open with keywords highlighted; the topic list matches evaluator output and grows immediately after a response unlocks a keyword; clicking a keyword the NPC can answer navigates to it; the tree is paused while open; close unpauses, recaptures the mouse, emits `closed`, frees.
8. **Journal panel (scene):** J opens it paused with entries in chronological order and text resolved from defs; close (button or J) restores mouse and unpauses.
9. **Persistence (scene):** after a `Game.change_scene` transition, the player's `Journal` is the *same resource instance* — topics learned and entries gained in scene A intact in scene B (mirrors 003 criterion 5).
10. **Data validation — NPCs:** every `data/npcs/*.tres` loads as NPCDef; EXPECTED_COUNT 3; ids unique and == filename stems; non-empty display_name.
11. **Data validation — journal entries:** every `data/journal/*.tres` loads; EXPECTED_COUNT 3; ids unique == stems; non-empty text.
12. **Data validation — dialogue (the Phase 3 gate):** every `data/dialogue/*.tres` loads; EXPECTED_COUNT 5; ids unique == stems; non-empty display_name; ≥1 response per topic; per response: non-empty text, `npc_id` empty or resolving to `data/npcs/<id>.tres`, every `requires_topics`/`requires_journal`/`journal_entry` id resolving by convention, give/take stacks with non-null items and count > 0; every `[[id]]` in every text resolves to an existing topic and parses cleanly (no stray `[[`/`]]`); no response follows a fully-unconditional one in the same topic (unreachable content fails); `greeting` exists and `pick_response` on it is non-null for every NPC from a fresh state; every non-greeting topic appears as a `[[keyword]]` in at least one response somewhere (no unreachable topics).

## How to implement

One commit each, full suite green before each:

1. `DialogueMarkup` + unit tests.
2. `Journal` resource + unit tests; `setup_identity` extended to 3 args; sanctioned `Game.journal` + injection; scene persistence test (criterion 9).
3. `NPCDef` + `data/npcs/` + validator; `JournalEntryDef` + `data/journal/` + validator.
4. `DialogueTopicDef`/`DialogueResponse` + `data/dialogue/` starter topics + the full dialogue validator (uses `DialogueMarkup`).
5. `DialogueEvaluator` + `DialogueLibrary` + unit tests (criteria 3–5).
6. `DialoguePanel` + `Npc` scene; delete the TalkStub trio; migrate `interaction_debug.tscn`; 003 amendment note; scene tests (criteria 6–7).
7. `journal` input action + `JournalPanel` + player wiring + scene tests (criterion 8).
8. `dialogue_debug` scene + docs housekeeping (master-plan status, CLAUDE.md focus).

**Debug scene** (`scenes/debug/dialogue_debug.tscn`): a room with a `default` spawn; all three NPCs spaced out; a `WorldItem` rat_pelt on the floor (talk to seld before and after picking it up to watch `a_small_favor` appear); a TransitionDoor pair into a small interior and back (manual journal-persistence check); a live label dumping the known-topic and journal-entry lists with counts, in discovery order. *(Amendment: the label shows the ordered lists rather than "the last `EffectReport`" — the report is panel-internal, and the list tails are the latest effects.)* Proves: per-NPC vs fallback greetings, keyword unlocking growing the topic list mid-conversation, the journal-gated response variants on `the_old_barrow` across two talks, the take/give exchange, J-panel reading, and pause behavior.
