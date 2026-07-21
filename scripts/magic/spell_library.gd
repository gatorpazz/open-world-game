class_name SpellLibrary
extends RefCounted
## Cached id -> SpellDef lookup over data/spells/ (spec 008). Loaded lazily
## on first use — the ItemLibrary/QuestLibrary/DialogueLibrary shape, byte
## for byte. The id == filename stem convention is enforced by
## tests/data/test_spell_defs.gd.

const DIR := "res://data/spells"

static var _spells: Dictionary[StringName, SpellDef] = {}


static func get_spells() -> Dictionary[StringName, SpellDef]:
	if _spells.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var spell := load(DIR.path_join(file_name)) as SpellDef
			if spell != null:
				_spells[spell.id] = spell
	return _spells


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_spells.clear()
