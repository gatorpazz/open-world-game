extends GutTest
## Validates every RecipeDef in data/recipes/ (spec 022, acceptance criterion 1):
## ids, resolvable inputs, an existing ConsumableDef output, and sane counts.

const DIR := "res://data/recipes"
const EXPECTED_COUNT := 2
## The licensing tiers (spec 001) — recipes gate on these alchemy levels.
const VALID_MIN_SKILLS: Array[int] = [0, 25, 50]

var _defs: Array[RecipeDef] = []
var _items: Dictionary[StringName, ItemDef] = {}


func before_all() -> void:
	_items = ItemLibrary.get_items()
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: RecipeDef = load(DIR.path_join(file_name)) as RecipeDef
		assert_not_null(def, "%s should load as a RecipeDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding recipes")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: RecipeDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		assert_eq(
			String(def.id), def.resource_path.get_file().get_basename(), "id matches filename"
		)


func test_display_names_are_non_empty() -> void:
	for def: RecipeDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)


func test_inputs_resolve_with_positive_counts() -> void:
	for def: RecipeDef in _defs:
		assert_gt(def.inputs.size(), 0, "%s has at least one input" % def.id)
		for stack: ItemStack in def.inputs:
			assert_not_null(stack.item, "%s input is an item" % def.id)
			if stack.item != null:
				assert_true(
					_items.has(stack.item.id), "%s input %s resolves" % [def.id, stack.item.id]
				)
			assert_gt(stack.count, 0, "%s input count is positive" % def.id)


func test_output_is_an_existing_consumable() -> void:
	for def: RecipeDef in _defs:
		assert_true(_items.has(def.output_id), "%s output %s resolves" % [def.id, def.output_id])
		if _items.has(def.output_id):
			assert_true(
				_items[def.output_id] is ConsumableDef,
				"%s output %s is a ConsumableDef (no dynamic items)" % [def.id, def.output_id]
			)
		assert_gt(def.output_count, 0, "%s output_count is positive" % def.id)


func test_min_skill_is_a_licensing_tier() -> void:
	for def: RecipeDef in _defs:
		assert_has(VALID_MIN_SKILLS, def.min_skill, "%s min_skill is a tier" % def.id)
