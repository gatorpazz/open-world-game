---
name: new-lore-entry
description: Scaffold a lore entry in docs/lore/ per spec 011 — correct typed folder, strict frontmatter, the universal body spine, an inbound link from its parent, lore suite green. Use for every new lore entry, including `--stub` entries created to satisfy a dangling [[link]] (the stub ritual).
---

# New Lore Entry

Scaffold one entry in the canon vault. Ask for `type`, `id`, and `region` if
not given (e.g. `/new-lore-entry location marshgate_weir fen_coast`, or
`--stub` after the type for a dangling-link stub). **This skill never sets
`status` above `draft` — only the director ratifies canon.**

## 1. Check the id

- snake_case, `[a-z0-9_]+`, and globally unique across the vault: search
  existing stems and links (`grep -rn "<id>" docs/lore` and check no file
  `*/<id>.md` exists).
- Proper nouns must conform to the owning culture's **Naming conventions**
  section (`docs/lore/cultures/`). If no culture guide covers it yet, flag
  the name as provisional in Open questions rather than guessing.

## 2. Copy the template

Copy `docs/lore/_templates/<type>.md` (templates live in the vault — they
are the single source; do not reproduce them here) into the typed folder:

| type | folder | extra frontmatter |
|---|---|---|
| world_rule | `docs/lore/rules/` | — (`tags: magic` / `economy` have defined meanings) |
| timeline_event | `docs/lore/timeline/` | `era` (from bible's Historical spine), `order` (int) |
| region | `docs/lore/regions/` | non-active regions carry `tags: locked` |
| location | `docs/lore/locations/` | `kind` (settlement·landmark·dungeon·route·danger_zone), optional `culture` |
| culture | `docs/lore/cultures/` | 3 extra required sections (in the template) |
| faction | `docs/lore/factions/` | prose canon only — never game data (the faction fence) |
| npc | `docs/lore/npcs/` | optional `culture` |
| wildlife | `docs/lore/wildlife/` | — |
| item | `docs/lore/items/` | — |

Filename = `<id>.md` — the stem IS the id; there is no id field.

## 3. Fill the frontmatter

`title`, `type`, `status: draft` (always), `region` (`world` or a region
id). `pitch`/`spoiler`/`surface` are required only at `reviewed`+ but fill
them now if known. Strict grammar: flat `key: value` scalars and `key:` +
`  - item` lists only — no nesting, no inline arrays, no comments, no tabs;
double-quote values containing structural characters. No `[[links]]` in
frontmatter values.

## 4. Write the body

Full mode: fill at least **Function** and **Open questions** honestly; leave
other spine sections as headings with what is actually known. Facts must
come from linked entries or the director — **no silent invention**; every
unknown becomes an Open questions bullet.

`--stub` mode: title + pitch (if known) + an **Open questions** section
holding what the stub is waiting on. Stop there. A stub exists to make a
dangling `[[link]]` resolve and to be a visible work item
(`grep -rn "status: draft" docs/lore` is the queue).

## 5. Add the inbound link

Add one `[[<id>]]` link from the parent entry — region → location,
bible.md's Regional map index → region, culture → its people, and so on.
**Without an inbound path from `bible.md` the reachability test fails.**

## 6. Verify

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

The lore suite must be green. Commit as `lore: <what was added>` unless the
entry is part of a larger pass commit.
