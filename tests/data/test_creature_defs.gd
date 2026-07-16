extends GutTest
## Validates every CreatureDef resource in data/creatures/ (spec 004,
## acceptance criterion 9).

const DIR := "res://data/creatures"

var _defs: Array[CreatureDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: CreatureDef = load(DIR.path_join(file_name)) as CreatureDef
		assert_not_null(def, "%s should load as a CreatureDef" % file_name)
		if def != null:
			_defs.append(def)


func test_at_least_one_creature_exists() -> void:
	assert_gt(_defs.size(), 0)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: CreatureDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_are_non_empty() -> void:
	for def: CreatureDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)


func test_numeric_fields_are_in_sane_ranges() -> void:
	for def: CreatureDef in _defs:
		assert_gt(def.max_health, 0.0, "%s max_health" % def.id)
		assert_gt(def.damage, 0, "%s damage" % def.id)
		assert_gte(def.armor, 0, "%s armor" % def.id)
		assert_gt(def.attack_reach, 0.0, "%s attack_reach" % def.id)
		assert_gt(def.attack_cooldown, 0.0, "%s attack_cooldown" % def.id)
		assert_gt(def.move_speed, 0.0, "%s move_speed" % def.id)
		assert_gt(def.detect_radius, 0.0, "%s detect_radius" % def.id)


func test_leash_radius_at_least_detect_radius() -> void:
	for def: CreatureDef in _defs:
		assert_gte(def.leash_radius, def.detect_radius, "%s leash >= detect" % def.id)


func test_loot_entries_reference_valid_items_with_positive_counts() -> void:
	for def: CreatureDef in _defs:
		for stack: ItemStack in def.loot:
			assert_not_null(stack, "%s loot entry is an ItemStack" % def.id)
			if stack == null:
				continue
			assert_not_null(stack.item, "%s loot entry has an item" % def.id)
			assert_gt(stack.count, 0, "%s loot count is positive" % def.id)
