extends GutTest
## Validates every ItemDef resource in data/items/ (spec 002, criterion 6).

const ITEMS_DIR := "res://data/items"
const SKILLS_DIR := "res://data/skills"
const EXPECTED_ITEM_COUNT := 21  # 17 through spec 017 + 3 ingredients + 1 brewing kit (022)
const VALID_ARMOR_SKILLS: Array[StringName] = [&"heavy_armor", &"light_armor"]
const JEWELRY_SLOTS: Array[StringName] = [&"ring", &"amulet"]

var _items: Array[ItemDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(ITEMS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var item: ItemDef = load(ITEMS_DIR.path_join(file_name)) as ItemDef
		assert_not_null(item, "%s should load as an ItemDef" % file_name)
		if item != null:
			_items.append(item)


func test_exactly_twelve_items() -> void:
	assert_eq(_items.size(), EXPECTED_ITEM_COUNT)


func test_ingredient_effects_are_known_tags() -> void:
	# Spec 022: every IngredientDef effect is in the closed alchemy vocabulary.
	for item: ItemDef in _items:
		if item is IngredientDef:
			for effect: StringName in (item as IngredientDef).effects:
				assert_has(
					AlchemyRules.EFFECTS, effect, "%s effect %s is a known tag" % [item.id, effect]
				)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for item: ItemDef in _items:
		assert_ne(item.id, &"", "%s has an id" % item.resource_path)
		assert_false(seen.has(item.id), "id %s is unique" % item.id)
		seen[item.id] = true
		var file_stem := item.resource_path.get_file().get_basename()
		assert_eq(String(item.id), file_stem, "id matches filename for %s" % item.resource_path)


func test_display_names_are_non_empty() -> void:
	for item: ItemDef in _items:
		assert_ne(item.display_name, "", "%s has a display name" % item.id)


func test_weights_and_values_are_non_negative() -> void:
	for item: ItemDef in _items:
		assert_gte(item.weight, 0.0, "%s weight is non-negative" % item.id)
		assert_gte(item.base_value, 0, "%s base_value is non-negative" % item.id)


func test_stack_fields_are_consistent() -> void:
	for item: ItemDef in _items:
		if item.stackable:
			assert_gt(item.max_stack, 1, "%s stackable max_stack > 1" % item.id)
		else:
			assert_eq(item.max_stack, 1, "%s non-stackable max_stack is 1" % item.id)


func test_weapons_and_armor_are_never_stackable() -> void:
	for item: ItemDef in _items:
		if item is WeaponDef or item is ArmorDef:
			assert_false(item.stackable, "%s is not stackable" % item.id)


func test_weapon_skill_ids_are_combat_skills() -> void:
	for item: ItemDef in _items:
		var weapon := item as WeaponDef
		if weapon == null:
			continue
		var skill := load(SKILLS_DIR.path_join("%s.tres" % weapon.skill_id)) as SkillDef
		assert_not_null(skill, "%s skill_id %s exists" % [weapon.id, weapon.skill_id])
		if skill != null:
			assert_eq(
				skill.archetype,
				&"combat",
				"%s skill %s is a combat skill" % [weapon.id, weapon.skill_id]
			)


func test_armor_skill_ids_are_armor_skills_or_empty_for_jewelry() -> void:
	for item: ItemDef in _items:
		var armor := item as ArmorDef
		if armor == null:
			continue
		if armor.slot in JEWELRY_SLOTS and armor.skill_id == &"":
			continue
		assert_has(VALID_ARMOR_SKILLS, armor.skill_id, "%s skill_id is an armor skill" % armor.id)
		assert_not_null(
			load(SKILLS_DIR.path_join("%s.tres" % armor.skill_id)) as SkillDef,
			"%s skill_id %s exists" % [armor.id, armor.skill_id]
		)


func test_weapon_swing_time_and_reach_are_positive() -> void:
	for item: ItemDef in _items:
		var weapon := item as WeaponDef
		if weapon == null:
			continue
		assert_gt(weapon.swing_time, 0.0, "%s swing_time is positive" % weapon.id)
		assert_gt(weapon.reach, 0.0, "%s reach is positive" % weapon.id)


## Melee reach must not exceed interact range, or you could hit things
## you cannot yet interact with (spec 004).
func test_weapon_reach_within_interact_range() -> void:
	var config := load("res://data/balance/balance_config.tres") as BalanceConfig
	for item: ItemDef in _items:
		var weapon := item as WeaponDef
		if weapon == null:
			continue
		assert_lte(weapon.reach, config.interact_range, "%s reach <= interact_range" % weapon.id)


func test_armor_slots_are_valid() -> void:
	for item: ItemDef in _items:
		var armor := item as ArmorDef
		if armor == null:
			continue
		assert_has(ArmorDef.VALID_SLOTS, armor.slot, "%s slot is valid" % armor.id)


func test_consumable_restores_are_non_negative() -> void:
	for item: ItemDef in _items:
		var consumable := item as ConsumableDef
		if consumable == null:
			continue
		assert_gte(consumable.health_restore, 0.0, "%s health_restore" % consumable.id)
		assert_gte(consumable.mana_restore, 0.0, "%s mana_restore" % consumable.id)
		assert_gte(consumable.stamina_restore, 0.0, "%s stamina_restore" % consumable.id)
