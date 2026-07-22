# Spec 013 — Dialogue Choice Prompts (stub)

**Status:** stub — queued, Phase 2 Wave 1; the full spec is drafted before implementation begins
**Depends on:** 005 (`DialogueResponse` / `DialogueEvaluator` / `DialoguePanel` — the models this spec amends), 010 (the two shipped decision points that get retrofitted)
**Consumed by:** 015 (advancement/promotion beats read best as choice prompts), 016 (the barter entry point from dialogue), 019 (persuasion attempts render as choice prompts: admire / intimidate / bribe)

## Scope (sketch — the draft firms this up)

**In:** a choice-prompt mechanism on `DialogueResponse` — player-voiced decision replies rendered as buttons in `DialoguePanel`, so decision points resolve by an explicit player line instead of a topic click (the 010 playthrough ruling) · retrofit of the two existing decision points (the refusal at the square; expose-vs-absolve) · `tests/data/test_dialogue_topics.gd` validator coverage for the new field(s) · reply text canon-packet authored under the plain-meaning anchor rule.

**Out (later specs / backlog):** persuasion, disposition, and skill-checked replies (019) · barter entry (016) · any new dialogue content beyond the two retrofits.

## Notes for the draft

- The Decision Log ruling (spec 010 playthrough): "the real fix is a choice-prompt mechanism on `DialogueResponse` (player replies rendered as buttons) … the model change belongs to a spec that amends 005 coherently — not to a content fix."
- Code seams: `scripts/resources/dialogue_response.gd` (conditions and effects already live here), `scripts/dialogue/dialogue_evaluator.gd` (static pick/apply — choice resolution should stay in pure logic), `scripts/ui/dialogue_panel.gd` (topic list + keyword clicks today).
- The decision-conversation shape already exists as data (`the_three_versions` and the guild branch topics) — those are the retrofit targets.
- No save impact; no new content type (extends the `DialogueResponse` sub-resource — the Golden Rule scaffold is untouched).
- Amendment discipline: 005 receives inline amendment parentheticals; this spec's **Modified:** list forward-declares them.
