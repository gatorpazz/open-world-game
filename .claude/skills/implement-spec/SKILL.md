---
name: implement-spec
description: Implement a numbered feature spec from docs/specs/ following the project workflow — small reviewable commits, tests alongside systems, full GUT suite green before each commit, and the spec-amendment ritual for any deviation.
disable-model-invocation: true
---

# Implement Spec

Implement the spec given as the argument (e.g. `/implement-spec 003` or a path).
If no argument, use the "Current focus" spec named in CLAUDE.md.

## Workflow

1. **Read the spec end to end** (`docs/specs/NNN-*.md`) before touching code. List
   its acceptance criteria explicitly — they are the definition of done.
2. **Survey what exists.** Check `scripts/`, `data/`, and `tests/` for systems the
   spec builds on. If the spec conflicts with something already in the code, **stop
   and flag it** — do not silently pick a side.
3. **Plan a sequence of small, independently reviewable commits**, each one a
   coherent slice (a resource type, a component, a system + its tests). Present the
   plan before starting if the spec is large.
4. **For each slice:**
   - New content types go through the full ritual: Resource def in
     `scripts/resources/`, folder under `data/`, validator in `tests/data/`
     (the `new-content-type` skill has the templates).
   - Pure logic lives in Resources/RefCounted classes; Nodes are thin wrappers.
     Signals up, calls down. Tunable numbers go in `data/balance/balance_config.tres`.
   - Write GUT tests alongside the system, not after.
   - Run the full suite and show the output — it must be green before committing:
     ```bash
     godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
     ```
   - Commit as `area: what changed`.
5. **Spec-amendment ritual:** any deviation from the spec as written gets the spec
   file amended **in the same commit** as the deviating code. Generalizable lessons
   also go into CLAUDE.md.
6. **Wrap up:** walk the acceptance criteria one by one and state pass/fail for
   each. Add or update a debug scene under `scenes/debug/` if the spec's feature
   needs manual in-game verification, and say what to check by hand.

Game-design decisions (balance feel, UX choices, naming of player-facing things)
stay with the human — ask one clarifying question rather than guessing.
