# CLAUDE.md — open-world-game

Solo-developed open-world RPG inspired by Morrowind's *design* (original IP — no Bethesda names, lore, or assets, ever). Godot 4.x, GDScript. One human director + AI agents. Optimize for small, reviewable, tested changes.

## Commands

```bash
# Run the game (adjust binary name/path to this machine)
godot .

# Run all tests (GUT addon)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Reimport assets after adding files outside the editor
godot --headless --import
```

## The Golden Rule: content is data, code is systems

- All game content — items, skills, NPCs, spells, quests, dialogue, loot tables, balance numbers — lives in custom `Resource` files (`.tres`) under `data/`. Scripts define *behavior*, never *content*.
- No hardcoded game values in scripts. Tunable numbers belong in `data/balance/balance_config.tres`.
- Every new content type gets: a `class_name` Resource definition in `scripts/resources/`, a folder under `data/`, and a validation test in `tests/data/` that loads every file of that type and checks it (unique ids, required fields, valid references).

## Code conventions

- GDScript with **static typing everywhere**: typed vars, typed function signatures, typed arrays (`Array[SkillDef]`). `-> void` on functions that return nothing.
- `class_name` on every reusable script. PascalCase for classes/nodes, snake_case for files, folders, functions, and variables. `StringName` for ids.
- Godot reserves many generic nouns as built-in classes; check for collisions before declaring `class_name`, and prefer domain-prefixed names (`World*`, `Game*`) for generic English words.
- Signals up, calls down: children never reach up the tree; they emit signals. Parents call down.
- Autoloads are a last resort. Ask before adding one. The one sanctioned autoload is `Game` (persistent identity + scene changes): `Game` mutates its own state; everything else receives resource references at spawn or calls `change_scene`. Never read `Game.character_sheet` ambiently from random scripts.
- Prefer composition (small component nodes) over inheritance.
- Pure logic lives in Resources/RefCounted classes so it is testable without a scene tree; Nodes are thin wrappers that own state and emit signals.

## Folder layout

```
scenes/        # .tscn files (scenes/debug/ for test scenes)
scripts/       # systems and components (scripts/resources/ for Resource defs)
data/          # .tres content files (skills/, items/, balance/, ...)
assets/        # models, textures, audio (assets/LICENSES.md is mandatory)
tests/         # GUT tests (tests/data/ for content validators)
docs/specs/    # numbered feature specs — implement these as written
docs/lore/     # canon lore vault — validated markdown entries (spec 011)
docs/research/ # commissioned research docs; not shipped
addons/        # third-party only; never hand-edit
```

## Testing

- Every system gets GUT tests written alongside it, not after. Test pure logic directly; use the debug scenes for manual verification.
- All tests must pass before a commit. Run the test command above and show the output.

## Git

- Small, focused commits. Message format: `area: what changed` (e.g., `stats: add skill xp progression`).
- Never commit `.godot/`. Never force-push.

## Asset licensing

Any asset entering `assets/` gets a line in `assets/LICENSES.md` in the same commit: filename, source URL, license, author. No exceptions — this file is what lets us ship commercially.

## Lore & canon

- World canon lives in `docs/lore/` (spec 011): one markdown entry per fact-bearing thing, strict frontmatter, `[[id]]` wikilinks, validated by `tests/lore/` in the normal test run.
- Statuses: draft → reviewed → canon (→ deprecated). **Only the director ratifies `status: canon`** — agents never promote.
- No silent invention: a fact the vault doesn't hold becomes a stub entry or an Open questions line, never improvised prose.
- Run the `canon-packet` skill before writing any player-facing text (dialogue, journal, quests) and write only from cited facts.
- Factions in `docs/lore/factions/` are prose canon only; faction game-data types stay fenced to a Phase 2 spec.

## Agent guardrails

- Don't install addons, delete files, or refactor code unrelated to the task without asking first.
- If a spec in `docs/specs/` conflicts with something in the code, flag it instead of silently choosing.
- When a task is ambiguous, ask one clarifying question rather than guessing at game design decisions — design authority stays with the human.

## Current focus

Phase 1, spec 008: magic v1 (evocation / mending / warding) — spell content per the Golden Rule, casting on the 001 spine, reusing `HurtBox` and the 004 defense pipeline; the mana bar joins the HUD (004 deferred it here). Spec 007 is complete: save/load — a pure `SaveCodec` (versioned JSON, items by id via `ItemLibrary`, `scene_path` allow-listed to `res://`), `Game.save_game/load_game` over `user://save.json` (scene + exact transform + current pools), F5/F9 quicksave/quickload with HUD notices, and death now loads the last save with the 004 reload as no-save fallback. Any new `Game` field must join the save payload and bump `SAVE_VERSION`. Specs 001–006 and 011 are complete; the vault stands at 56 entries (19 canon).
