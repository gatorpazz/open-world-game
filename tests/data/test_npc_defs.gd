extends GutTest
## Validates every NPCDef resource in data/npcs/ (spec 005, acceptance
## criterion 10).

const DIR := "res://data/npcs"
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const EXPECTED_COUNT := 11

var _defs: Array[NPCDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: NPCDef = load(DIR.path_join(file_name)) as NPCDef
		assert_not_null(def, "%s should load as an NPCDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding NPCs")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: NPCDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_are_non_empty() -> void:
	for def: NPCDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)


## A scheduled NPC's present-window (spec 020) must sit within the day's bells;
## a zero-width window (always present) is allowed. Out-of-range bells would
## make the NPC vanish forever or never.
func test_schedules_are_within_the_day() -> void:
	var config := load(BALANCE_PATH) as BalanceConfig
	for def: NPCDef in _defs:
		if def.schedule == null:
			continue
		var from := def.schedule.present_from_bell
		var to := def.schedule.present_to_bell
		assert_between(from, 0, config.bells_per_day - 1, "%s schedule from-bell in range" % def.id)
		assert_between(to, 0, config.bells_per_day, "%s schedule to-bell in range" % def.id)
