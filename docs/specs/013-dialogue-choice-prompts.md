# Spec 013 — Dialogue Choice Prompts

**Status:** ready to implement
**Depends on:** 005 (`DialogueResponse` / `DialogueEvaluator` / `DialoguePanel` — the models this spec amends), 010 (the two shipped decision points that get retrofitted)
**Consumed by:** 015 (advancement/promotion beats and the guild join commits read best as choice prompts — the join retrofit is 015's work), 016 (the barter entry point from dialogue), 019 (persuasion attempts render as choice prompts — admire / intimidate / bribe — and per-choice condition fields land there)

## Scope

**In:** a choice-prompt mechanism on `DialogueResponse` — player-voiced replies rendered as buttons in `DialoguePanel`, so a decision resolves by an explicit player line instead of a topic click (the 010 playthrough ruling) · a `DialogueChoice` sub-resource (the `ItemStack` pattern — no data folder, not a content type) · a `choice_gated` condition so commit responses are unreachable by topic/keyword click · retrofit of the two shipped decision points (the refusal at the square; expose-vs-absolve) · validator coverage in `tests/data/test_dialogue_topics.gd` · reply text canon-packet authored under the plain-meaning anchor rule · a choice-prompt scene test.

**Out (later specs / backlog):** persuasion, disposition, and skill-checked replies (019 — **per-choice condition fields are 019's extension point**; choices in 013 are gated only at the response level) · barter entry from a choice (016) · the guild join commits (`take_the_cord`, `the_roofed_cache`) as choice prompts — their topic names are plain-meaning actions today; 015 retrofits them alongside advancement beats — **done (spec 015): all three guild joins present a choice prompt (`the_reading` retrofitted by director ruling too); advancement conversations deferred to a later content spec** · any new dialogue content beyond the two retrofits · single-reply "confirm" prompts (**director ruling:** a prompt offers ≥ 2 replies; a choice of one is a continue button — relax the validator if a future beat ever needs it) · modal prompts (**director ruling:** prompts are non-modal; see *Panel*).

## Design

### The problem (ground truth from the shipped data)

Two decisions currently commit on a single click:

1. **The refusal.** Torrum's ask/reminder in `for_the_tallies` carry `[[refuse_the_square|refuse]]` markup; clicking the keyword fires `refuse_the_square` → `resp_torrum_refuse`, which writes `refused_the_square` — a terminal quest stage — in one click.
2. **Expose-vs-absolve.** Ollun's `resp_choice` in `the_extra_name` frames the decision, but the commits live behind ordinary topics: `the_kept_name` → `resp_expose` (writes `the_name_restored`) and `tablet_law` → `resp_absolve` (writes `the_gap_kept`). Worst case: asking Kellom about *tablet law* — an innocent lore topic marked in a greeting — while holding the waxed staff instantly seals the irreversible absolve ending.

Not decision points (no retrofit): `the_three_versions` and the guild-side trio are informational — the stub cited them only as the *shape* of a decision conversation.

### Content model — the architectural decision

**`DialogueChoice`** (`scripts/resources/dialogue_choice.gd`) — a sub-resource inside a `DialogueResponse`, never a standalone file, exactly like `ItemStack` inside `take_items`. Not a content type: no data folder, no Golden Rule scaffold.

| field | type | meaning |
|---|---|---|
| `text` | String (multiline) | the player's spoken line, rendered as a button; **plain text — no `[[markup]]`** (player lines never unlock topics; one unlock mechanism, per 005 — validator-enforced) |
| `topic` | StringName = `&""` | topic the NPC answers next, evaluated with `from_choice = true`; **empty = a dismissal line** — the prompt lapses with no state change |

A choice carries **no effects and no conditions**. Effects stay on responses (one effect location — choosing a reply speaks the line and navigates; the consequences are entirely the target response's existing effects, applied through the existing path). Per-choice conditions are deliberately absent: the two retrofits need only response-level gates, and per-choice checks (persuasion) are exactly the surface 019 adds.

*Rejected alternative:* flat parallel arrays (`choice_texts` + `choice_topics`) on `DialogueResponse` — index-alignment is validator-hostile (misaligned arrays are exactly the malformed content the Phase 3 pipeline must reject) and gives 019 nowhere to put per-choice fields. **Director ruling:** the sub-resource.

**`DialogueResponse` additions** (both flat, per 005's flat-fields rule):

| field | type | role | meaning |
|---|---|---|---|
| `choice_gated` | bool = false | condition | eligible **only** when navigation came from a choice press (`from_choice = true`); invisible to topic clicks, keyword clicks, and `available_topics` |
| `choices` | Array[DialogueChoice] | effect / presentation | player replies offered after this response is spoken; non-empty makes the response a **prompt**; the decision resolves only by pressing one |

`is_unconditional()` counts `choice_gated` as a condition (a gated response is by definition conditional), so a gated commit ordered before later responses does not trip the unconditional-last validator rule. `choices` is an effect and does not affect unconditionality — a fully-unconditional final fallback carrying choices stays legal.

**A choice group is the `choices` array on the prompting response — not sibling responses.** First-match-wins is untouched. Different game states present different choice sets by state-forking the prompt response itself with the existing `requires_journal` / `blocked_by_journal` idiom.

**One-shot / commit behavior is the existing journal idiom, unchanged.** The commit response (now `choice_gated`) writes its decision entry exactly as today; post-state responses ordered earlier in the topic win every later ask; prompts re-present on re-ask until a commit lands, because merely showing or dismissing a prompt mutates nothing. Decisions are therefore deferrable and re-promptable for free. Quests read the same entries — zero quest-side change, zero save impact.

**Ordering convention (same-topic commits):** a `choice_gated` commit sits immediately *before* the prompt that targets it when they share a topic — `from_choice` navigation picks the commit; normal clicks fall through to the prompt. This is what lets the `tablet_law` retrofit keep its topic and journal entries unchanged.

### Evaluator

`DialogueEvaluator.matches` and `pick_response` each gain a trailing `from_choice: bool = false` parameter — backward compatible with every existing call site. `matches` gains one leading check: a `choice_gated` response fails unless `from_choice`. `available_topics` is untouched and inherits the default — a topic whose only answer for this NPC is choice-gated is correctly not listed. `apply_effects` is untouched (choices have no effects). Choice resolution stays pure: "which response answers this reply" is `pick_response(topics[choice.topic], npc_id, journal, inventory, true)`.

### Panel

**Director ruling — non-modal.** The topic list, keyword links, and Goodbye stay live while a prompt is pending. Navigating anywhere (or leaving) lapses the prompt; it re-presents next time the prompting response is picked, since nothing mutated. Non-modal cannot soft-lock, matches the topic-browser feel, and walking away from a demand is itself in character. (A modal ruling would have required every prompt to carry a dismissal line as a validator rule — recorded here so the road not taken is findable.)

- `scenes/ui/dialogue_panel.tscn` gains one node: `Choices` (VBoxContainer) under `Dim/Panel/Layout`, between `Body` and `Buttons`, hidden by default. Buttons are created dynamically — no fixed choice cap; ugly-but-functional.
- `show_topic(topic_id, from_choice := false)` clears any pending choice buttons first (the lapse), threads `from_choice` into `pick_response`, and presents the picked response's `choices` after the topic-list rebuild.
- Pressing a choice: buttons clear → the player's line is appended to the transcript in a distinct player-voice style (italic, tinted, quoted — visually unmistakable from NPC prose) → empty `topic` returns (dismissal); otherwise `show_topic(choice.topic, true)`.

`Npc`, `DialogueLibrary`, `DialogueMarkup`, `Journal`, and the pause/lifecycle contract are untouched.

### Content retrofit (canon-packet authored, plain-meaning anchor)

Player reply lines are authored via the `canon-packet` skill before the `.tres` edits; a button says exactly what it commits.

1. **`for_the_tallies`** — `resp_torrum_ask` and `resp_torrum_reminder`: the `[[refuse_the_square|…]]` markup spans are stripped (prose keeps the sense, unmarked); each gains `choices`: a refusal line (`topic = &"refuse_the_square"`) and a defer line (`topic = &""`). **Director ruling:** two replies — standing stays a world act at the blind in the square, as shipped.
2. **`refuse_the_square`** — `resp_torrum_refuse` gets `choice_gated = true`. The post-state responses stay (they also serve pre-013 saves that already know the topic).
3. **`the_extra_name`** — `resp_choice` gains `choices`: an expose line (`topic = &"the_kept_name"`) and a take-it-to-Kellom line (`topic = &""` — the absolve physically resolves at Kellom). Its `[[the_kept_name|…]]` / `[[tablet_law|…]]` markup stays — both remain legitimate lore topics; the commits behind them are now gated.
4. **`the_kept_name`** — `resp_expose` gets `choice_gated = true`. *Noted, not silently added:* in the decision state a plain topic click at Ollun now falls to `resp_fallback`, whose text reads post-absolve; an optional decision-state nudge response pointing back to *the extra name* is a content-polish call for the director.
5. **`tablet_law`** — `resp_absolve` gets `choice_gated = true`; a new **prompt** response is inserted directly after it carrying `resp_absolve`'s gates (Kellom acknowledges what the player carries and asks the question), with `choices`: a seal line (`topic = &"tablet_law"` — the same-topic ordering convention above) and a not-yet line (`topic = &""`). Final order: `resp_sealed`, `resp_restored`, `resp_absolve` (gated), the prompt, `resp_law`, `resp_fallback`.

No new topics, journal entries, NPCs, or quest changes. `EXPECTED_COUNT` stays 21.

## Architecture

| file | role |
|---|---|
| `scripts/resources/dialogue_choice.gd` | `DialogueChoice extends Resource` — sub-resource only |
| `tests/scenes/test_choice_prompts.gd` | choice-prompt scene test against the retrofitted data |

**Modified:** `scripts/resources/dialogue_response.gd` (two fields + `is_unconditional` clause) · `scripts/dialogue/dialogue_evaluator.gd` (`from_choice` on `matches`/`pick_response`) · `scripts/ui/dialogue_panel.gd` + `scenes/ui/dialogue_panel.tscn` (Choices container + present/clear/press) · `tests/data/test_dialogue_topics.gd` (choice rules + reachability amendment) · `tests/unit/test_dialogue_evaluator.gd` · `tests/scenes/test_lastdoor_chain.gd` (`_pick`/`_say` gain `from_choice`; the refusal turn models a button press) · `data/dialogue/{for_the_tallies,refuse_the_square,the_extra_name,the_kept_name,tablet_law}.tres` · `docs/specs/005-dialogue-and-journal.md` (inline amendment parentheticals) · `docs/master-plan.md` · `CLAUDE.md`.

**`BalanceConfig` additions: none.** The player-voice tint is UI styling, not balance.

## Acceptance criteria (GUT tests)

1. **Evaluator (unit):** `matches` rejects a `choice_gated` response with `from_choice = false` and accepts it with `true` (other conditions still AND in); `pick_response` skips gated responses on normal picks and falls through to the next match; with `from_choice = true` a gated response wins in array order (a synthetic commit-then-prompt topic pins the same-topic convention); `available_topics` excludes a topic whose only answer for the NPC is gated; `is_unconditional()` is false when only `choice_gated` is set.
2. **Panel (scene, retrofitted data):** Torrum's ask presents exactly two buttons with the authored labels, topic list and Goodbye still enabled (pins the non-modal ruling); pressing refuse appends the player line then Torrum's entered-refusal reply and writes `refused_the_square`; pressing defer clears the buttons and changes no state, and re-asking re-presents the prompt; showing another topic while a prompt is pending clears the buttons; direct `show_topic(&"refuse_the_square")` does **not** fire the gated commit; the Kellom flow — staff held, `the_kept_name` known — presents the seal prompt on *tablet law*, the seal press fires `resp_absolve` and writes `the_gap_kept`, and re-ask picks `resp_sealed`.
3. **Data validation (the amended Phase 3 gate):** per choice on every response — non-null, non-empty `text`, no `[[` / `]]` and no extractable topic ids in `text`, `topic` empty or resolving to `data/dialogue/<id>.tres` · a response with `choices` has ≥ 2 of them · for a prompting response with a non-empty `npc_id`, every non-empty choice target contains ≥ 1 response whose `npc_id` is empty or equal · every topic containing a `choice_gated` response is some choice's target somewhere (no unreachable commits) · the topic-reachability rule becomes: every non-greeting topic appears as a `[[keyword]]` **or** as a choice target somewhere.
4. **Chain (scene):** the Lastdoor chain test's refusal turn passes `from_choice = true` and stays green end-to-end.

Not validated, by design: the plain-meaning anchor on button text is human canon-packet review, not machine-checkable.

## How to implement

One commit each, full suite green before each:

1. This spec + the 005 inline amendments + master-plan status.
2. `DialogueChoice` + the two `DialogueResponse` fields + `is_unconditional` clause + unit coverage.
3. Evaluator `from_choice` + unit tests (criterion 1).
4. Validator rules + the reachability amendment (criterion 3) — green on the unchanged 21 topics.
5. Panel: Choices container + present/clear/press + `show_topic` param (inert until data uses it).
6. Canon-packet pass for the reply lines → the five `.tres` retrofits → `tests/scenes/test_choice_prompts.gd` (criterion 2) → `test_lastdoor_chain.gd` update (criterion 4).
7. Docs housekeeping (master-plan status → complete, CLAUDE.md focus).
