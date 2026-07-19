---
name: canon-packet
description: Assemble a cited canon packet from docs/lore/ before writing ANY player-facing text (dialogue, journal entries, quest text, item descriptions) or lore-derived content. The two-pass canon-safe protocol from spec 011 — retrieve only supported facts with citations, list gaps, never invent.
---

# Canon Packet

Retrieval before generation. Run this before any writing session that will
produce player-facing text or new lore-derived content; write only from the
packet's cited facts.

## 1. Frame the task and set the spoiler ceiling

Restate what is being written and for whom. Player-facing text ⇒ exclude
`spoiler: high` entries unless the director explicitly overrides for this
task. Note the ceiling in the packet header.

## 2. Pass 1 — retrieve, with citations

- **Seed:** grep `docs/lore/` for the task's ids, titles, and `game_ids`
  (e.g. an NPC's `npc:<id>`); open the seed entries.
- **Walk:** follow body `[[links]]` up to 2 hops from the seeds; prefer
  `canon` > `reviewed` > `draft` and mark every draft-sourced fact with ▲.
- **Extract:** only facts actually present in entry text, one sentence per
  fact, each cited `[entry_id]`. Pull voice from the speaking culture's
  **Speech & register** and **Naming conventions** sections, and world-level
  rules from `bible.md` **Content grammar**.
- **Gaps:** every question the task needs answered that no entry answers
  goes in the Gaps list. Do not fill them.

## 3. Pass 2 — normalize, no new facts

Emit the packet in exactly this shape. Pass 2 may reorganize, compress, and
clarify Pass 1 material — it may not add a single new fact.

```
# Canon packet — <task>
Spoiler ceiling: <none|low|high>   Statuses used: canon, reviewed (▲ = draft)

## Facts
- <one sentence per fact> [entry_id]

## Voice
- <register, markers, idioms for the speaker/culture> [culture_id]

## Names & terms
- approved: <names/terms fit for this text> [culture_id]
- forbidden: <tropes/terms bible.md Content grammar bans>

## Gaps — do not invent
- <question> (→ stub via new-lore-entry, or director ruling)
```

## 4. Route the gaps

Hand the Gaps list to the director: each becomes either a `--stub` entry
(`new-lore-entry`) or an explicit director ruling recorded into the relevant
entry. Only then write. If writing must proceed first, mark placeholders in
the produced text and say so out loud.

## Rules

- The packet is **ephemeral** — conversation or scratchpad only, never
  committed (a committed packet is a cache that rots; the vault is the
  source of truth).
- Carry the citation ids into the session's review notes — the
  canon-keeper-reviewer checks produced lines against them.
- Writing that contradicts a cited entry is a bug in the writing, not the
  entry; stop and surface it.
