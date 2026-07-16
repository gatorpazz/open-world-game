---
name: new-content-type
description: Scaffold a new game content type per the Golden Rule — a class_name Resource definition in scripts/resources/, a data/ folder with a first example .tres, and a validation test in tests/data/. Use whenever adding a new kind of content (NPCs, spells, quests, dialogue, loot tables, factions, ...).
---

# New Content Type

Scaffold everything CLAUDE.md requires for a new content type. Ask for the type
name and its fields if not given (e.g. `/new-content-type SpellDef: id, display_name,
school, magicka_cost, description`).

Godot reserves many generic nouns as built-in classes. Before anything else, check
the chosen `class_name` for collisions (`ClassDB.class_exists` or just search Godot
docs) and prefer domain-prefixed names (`World*`, `Game*`) for generic English words.

## 1. Resource definition — `scripts/resources/<snake_name>.gd`

```gdscript
class_name SpellDef
extends Resource
## Definition of a single spell. Content lives in data/spells/*.tres;
## this script only defines the shape.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
```

Rules: static typing on every export, `StringName` for ids and enum-like fields,
`@export_multiline` for long text, no behavior beyond pure helper functions, and
**no default values that are really balance numbers** — those go in
`data/balance/balance_config.tres`.

## 2. Content folder — `data/<plural_snake_name>/`

Create the folder and at least one example `.tres` so the validator has something
to chew on. The file stem must equal the resource's `id` (validators assert this).
Author `.tres` files by hand following an existing one in `data/skills/` as a
reference for the format, or via the editor.

## 3. Validation test — `tests/data/test_<snake_name>s.gd`

Follow the established pattern (see `tests/data/test_skill_defs.gd`):

```gdscript
extends GutTest
## Validates every SpellDef resource in data/spells/.

const DIR := "res://data/spells"

var _defs: Array[SpellDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: SpellDef = load(DIR.path_join(file_name)) as SpellDef
		assert_not_null(def, "%s should load as a SpellDef" % file_name)
		if def != null:
			_defs.append(def)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: SpellDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_are_non_empty() -> void:
	for def: SpellDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)
```

Add a test per validation rule: required fields non-empty, enum-like `StringName`
fields drawn from a `VALID_*` const list, cross-references (e.g. an item id) resolve
to a real resource, numeric fields in sane ranges.

## 4. Verify

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

All tests must pass. Commit as one focused change: `data: add <type> content type`.
