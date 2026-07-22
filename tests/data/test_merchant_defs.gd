extends GutTest
## Validates every MerchantDef resource in data/merchants/ (spec 016,
## acceptance criterion 1).

const DIR := "res://data/merchants"
const NPC_DIR := "res://data/npcs"
const EXPECTED_COUNT := 2

var _defs: Array[MerchantDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: MerchantDef = load(DIR.path_join(file_name)) as MerchantDef
		assert_not_null(def, "%s should load as a MerchantDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding merchants")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: MerchantDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_are_non_empty() -> void:
	for def: MerchantDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)


func test_npc_id_resolves_to_an_npc() -> void:
	for def: MerchantDef in _defs:
		assert_ne(def.npc_id, &"", "%s names an npc_id" % def.id)
		var path := NPC_DIR.path_join("%s.tres" % def.npc_id)
		assert_true(
			ResourceLoader.exists(path),
			"%s npc_id '%s' resolves to %s" % [def.id, def.npc_id, path]
		)


func test_stock_items_resolve_and_have_positive_counts() -> void:
	var items := ItemLibrary.get_items()
	for def: MerchantDef in _defs:
		for stack: ItemStack in def.stock:
			assert_not_null(stack.item, "%s has a non-null stock item" % def.id)
			if stack.item != null:
				assert_true(
					items.has(stack.item.id),
					"%s stock item '%s' resolves in ItemLibrary" % [def.id, stack.item.id]
				)
			assert_gt(stack.count, 0, "%s stock counts are positive" % def.id)


func test_buys_entries_are_known_categories() -> void:
	for def: MerchantDef in _defs:
		for category: StringName in def.buys:
			assert_true(
				MerchantDef.CATEGORIES.has(category),
				"%s buys category '%s' is a known category" % [def.id, category]
			)


func test_merchant_gold_is_non_negative() -> void:
	for def: MerchantDef in _defs:
		assert_gte(def.merchant_gold, 0, "%s merchant_gold is non-negative" % def.id)


func test_price_multiplier_is_positive() -> void:
	for def: MerchantDef in _defs:
		assert_gt(def.price_multiplier, 0.0, "%s price_multiplier is positive" % def.id)
