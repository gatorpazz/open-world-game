extends GutTest
## Validates every JournalEntryDef resource in data/journal/ (spec 005,
## acceptance criterion 11).

const DIR := "res://data/journal"
const EXPECTED_COUNT := 4

var _defs: Array[JournalEntryDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: JournalEntryDef = load(DIR.path_join(file_name)) as JournalEntryDef
		assert_not_null(def, "%s should load as a JournalEntryDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding entries")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: JournalEntryDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_texts_are_non_empty() -> void:
	for def: JournalEntryDef in _defs:
		assert_ne(def.text, "", "%s has text" % def.id)
