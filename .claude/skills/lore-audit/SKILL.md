---
name: lore-audit
description: Run the drift, silo, and surface audits over docs/lore/ that go beyond what the GUT canon suite enforces — red-team prompts, originality strip-test, canon/game alignment. Report-only. Use at milestone ends, before canonization batches, and whenever the vault feels stale.
---

# Lore Audit

The beyond-GUT sweep. **Report-only: this skill never edits.** Every finding
becomes an Open questions line, a stub, or a fix — the director chooses.

## 1. Mechanical baseline

Run the suite first; a red suite outranks everything below:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## 2. Drift checks (canon resting on sand)

- **Canon on draft links:** for every `status: canon` entry, list its
  `[[links]]` that point at `draft` entries — settled truth citing unsettled
  truth. (`grep -l "status: canon" docs/lore -r` then walk links.)
- **Silent divergence:** re-read each canon entry against the entries it
  links; flag contradictions in facts, dates (era/order), names, or tone.
- **Rename drift:** every `game_ids` value vs the actual `data/` file stems,
  and every `data/npcs|dialogue|journal|creatures` stem vs the vault —
  report unclaimed game content and unclaimed canon.

## 3. Silo and surface checks (lore not reaching play)

- **Canon at `surface: none`:** canon that admits it never reaches the
  player — list it with a suggested surface.
- **Topic alignment:** for entries surfacing `dialogue`, compare ids with
  `data/dialogue/*.tres` stems; same-string alignment is the convention
  (never a hard rule — spec 011 namespace ruling). Report mismatches.
- **Hookless anchors:** anchor-type entries whose Quest hooks are filler
  (vague, unactionable, no named person/place/object).

## 4. Red-team prompts (from the research report)

Ask and answer each against the current vault, citing entries:

- What contradicts the active region's brief?
- Which proper nouns violate their culture's Naming conventions?
- What mechanic or item breaks a rules/ entry's stated limits?
- Which rumor or hook is false in-world — and who benefits from that
  falsehood? (If no one benefits, it's noise.)
- What would a player infer about this world with every codex removed —
  and is that what we intend?

## 5. The originality strip-test

Strip every proper noun from the active region's canon summary set. Is the
world still identifiable by its climate logic, political tensions,
religious assumptions, material culture, and speech rhythm? If it reads as
generic fantasy — or as the inspiration with the serial numbers filed off —
say so plainly and name the weakest layer.

## 6. Report

Findings ordered by severity: `entry_id — finding — suggested disposition
(fix | stub | open question | director ruling)`. End with the draft-queue
count (`grep -rn "status: draft" docs/lore | wc -l`) and what the next
canonization batch should contain.
