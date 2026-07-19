---
name: worldbuilding-pass
description: Drive ONE named worldbuilding pass (foundation | geography | timeline | cultures | factions | magic | economy | schema_stress | quests | dialogue) as an interactive director session that produces draft lore entries via new-lore-entry. The agent asks, offers candidates, and drafts; the director decides. Never sets canon. Spec 011's process engine.
---

# Worldbuilding Pass

Run one pass as a director session. Design authority stays with the human:
**the agent asks the pass's decision questions, offers 2–3 candidate options
per open question, and turns the director's choices into `status: draft`
entries** (via `new-lore-entry`). Facts come from prior entries or the
director's answers — never from improvisation; gaps become stubs or Open
questions. **This skill never sets `status: canon`** — canonization is its
own director session (M3).

## Session protocol (every pass)

1. Name the pass; load its block below (questions, prompt pack, floors).
2. Read `docs/lore/bible.md` and every prior pass's entries — no pass
   writes in a vacuum; later passes must consume earlier ones.
3. Ask the decision questions one cluster at a time (AskUserQuestion where
   it fits); offer 2–3 concrete candidates per question, each with one line
   on its downstream consequences. The director picks, edits, or rejects.
4. Draft entries with `new-lore-entry`; add inbound links from parents;
   quote example dialogue only inside code fences.
5. Run the suite; the pass's floors (below, all `≥`) must hold when its
   commit lands (`tests/lore/test_lore_floors.gd` grows one milestone at a
   time — raise it with the pass).
6. End with a digest: what was decided, what was drafted, the open
   questions created, and what the next pass needs from the director.

**Every entry must justify itself in play** — if a draft would change no
naming, clothing, architecture, law, attitude, price, or quest, say so and
ask whether it belongs at all.

## foundation (M1 — blank slate)

The world is invented from zero here. Nothing existing (marsh placeholders,
report demos) is assumed to survive.

- **Open:** a five-minute director brain-dump (freeform), reduced together
  into a one-page brief.
- **Decision questions:** the player fantasy in one sentence · emotional
  palette (3–5 words) · thematic contrasts (2–3 tensions) · **≥3 forbidden
  clichés** · the active region's **one defining ecological or metaphysical
  twist** (offer 3 candidates; for each, trace consequences into food,
  housing, ritual, travel, monsters, economy) · the region's working name ·
  aesthetic brief (6–12 described visual references; 5 texture words, 5
  audio words, 5 dialogue-tone words) · the MDA lens note (target feelings
  → likely dynamics → required mechanics).
- **Outputs:** bible.md sections seeded (Core promise, Rules-of-world
  one-liners, Content grammar, Player-facing surfaces, Aesthetic brief);
  the active region entry drafted (its Function = why the story starts
  here; Systems impact = traversal loop and travel constraints); bible's
  Regional map index links it.
- **Floors (M1):** all 9 bible sections non-placeholder · ≥3 forbidden-cliché
  bullets · 5/5/5 aesthetic word lists · ≥1 region entry reachable.

## geography (M2)

- **Prompt pack:** one annotated regional sketch in prose — landmarks,
  settlements, trade routes, danger zones. Every landmark gets a rumor, a
  material identity, a quest hook, and an environmental story beat. Ask:
  what geographical feature forces the locals to build differently from
  their neighbors? Where does travel hurt?
- **Floors:** in the active region — ≥3 `kind: settlement` · ≥8
  `landmark`+`dungeon` · ≥2 `route` · ≥2 `danger_zone`.

## timeline (M2)

- **Prompt pack:** fix the eras in bible's Historical spine first (director
  decision), then 12–20 events grouped into eras with explicit present-day
  consequences. Ask: which events changed the present? who remembers each
  differently? what law exists only because a disaster once happened?
- **Amend `VALID_ERAS`** in `tests/lore/test_lore_canon.gd` in the same
  commit (the allow-list precedent).
- **Floors:** ≥12 events across ≥2 eras; `(era, order)` unique.

## cultures (M2)

- **Prompt pack (naming + speech guide, per culture):** phoneme patterns ·
  place-name patterns · personal names by class and custom · five idioms ·
  speech registers for commoner, priest, official, criminal · words that
  appear on signage, contracts, shrine plaques, insults. Do NOT copy real
  languages; no apostrophe gibberish; names must be visually consistent
  with the culture's material identity. Ask: what do people value, fear,
  celebrate, forbid, trade? what profession is prestigious here but low
  elsewhere? what do poor and rich meals look like?
- **Floors:** ≥2 cultures, each with Naming conventions / Speech & register
  / Material culture sections filled.

## factions (M2)

- **Prompt pack:** overlapping factions with conflicting values and
  different entry verbs (scholarship, piety, smuggling, soldiery, civic
  service). Per faction: mission · power base · public creed vs private
  truth · internal subgroups · enemies · recruitment verbs · quest
  utility. Write goals and grievances for each side before any dialogue.
  Ask: what does this faction call justice, and what will it sacrifice for
  it? Prose canon only — **no faction game types (the fence)**.
- **Floors:** ≥3 faction entries — the future guilds.

## magic (M2)

- **Prompt pack:** one `rules/` entry, `tags: magic` — sources, costs,
  limits, social attitudes, professions, legal status, item implications.
  Ask: what creature thrives because of one magical rule? what building is
  impossible here, and why? who is licensed, who is feared? **Feeds spec
  008** — write it as the magic spec's design input.
- **Floors:** ≥1 rules entry tagged `magic`.

## economy (M2)

- **Prompt pack:** one `rules/` entry, `tags: economy` — key resources,
  shortages, black markets, sacred goods, travel friction, taxation or
  tribute. Ask: what moves, what is scarce, who taxes or hoards, what is
  smuggled? if travel stopped for a month, who profits?
- **Floors:** ≥1 rules entry tagged `economy`.

## schema_stress (M3)

- Fill to **≥2 entries per active type** (the report's two-examples rule: a
  schema that survives two of everything is real). Where filling exposes a
  weak template or missing field, flag it — schema fixes amend spec 011 in
  the same commit (the amendment ritual).

## quests (runs during spec 006, not before)

- **Prompt pack (per faction, 12 seeds):** ≥4 noncombat-forward · ≥3
  exposing faction hypocrisy or internal conflict · ≥4 requiring travel to
  a named landmark · ≥2 changing the environment after completion · every
  seed names an NPC role and a concrete item or document. Output schema per
  seed: title · premise · initiating NPC · location · decision point ·
  consequence if completed · consequence if ignored · reusable lore
  surfaced. Seeds land in entries' **Quest hooks** sections — there is no
  quest folder until 006 decides quest representation.

## dialogue (runs during specs 006/010, not before)

- **Prompt pack (per NPC, from a canon packet):** 6 one-liners · 2 informer
  conversations · 1 life-story conversation · 1 decision conversation.
  Cut small talk; embed setting through the NPC's priorities, not
  exposition dumps; distinguish social register, class, and faction
  affiliation; **mark every line with the canon fact id it depends on**;
  flag missing canon instead of improvising (gaps → stubs). Run
  `canon-packet` first, always.
