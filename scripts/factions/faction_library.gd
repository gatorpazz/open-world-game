class_name FactionLibrary
extends RefCounted
## Cached id -> FactionDef lookup over data/factions/ (spec 015). Loaded lazily
## on first use — the ItemLibrary/QuestLibrary shape, byte for byte. Save
## decoding and reconcile resolve faction ids through this; the id == filename
## stem convention is enforced by tests/data/test_faction_defs.gd.

const DIR := "res://data/factions"

static var _factions: Dictionary[StringName, FactionDef] = {}


static func get_factions() -> Dictionary[StringName, FactionDef]:
	if _factions.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var faction := load(DIR.path_join(file_name)) as FactionDef
			if faction != null:
				_factions[faction.id] = faction
	return _factions


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_factions.clear()
