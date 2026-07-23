class_name BoundWorkingLibrary
extends RefCounted
## Cached id -> BoundWorkingDef lookup over data/bound_workings/ (spec 023).
## Loaded lazily on first use — the SpellLibrary shape, byte for byte. The
## id == filename stem convention is enforced by tests/data/test_bound_working_defs.gd.

const DIR := "res://data/bound_workings"

static var _workings: Dictionary[StringName, BoundWorkingDef] = {}


static func get_workings() -> Dictionary[StringName, BoundWorkingDef]:
	if _workings.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var working := load(DIR.path_join(file_name)) as BoundWorkingDef
			if working != null:
				_workings[working.id] = working
	return _workings


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_workings.clear()
