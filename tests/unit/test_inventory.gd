extends GutTest
## Tests for the pure Inventory resource: stacking, weight, equip rules,
## removal edges, gold, and duplicate(true) round-trips (spec 002).

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const RUSTY_CLAYMORE := preload("res://data/items/rusty_claymore.tres")
const LEATHER_CUIRASS := preload("res://data/items/leather_cuirass.tres")
const IRON_HELM := preload("res://data/items/iron_helm.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const ROPE_RING := preload("res://data/items/rope_ring.tres")
const SCRIMSHAW_TOKEN := preload("res://data/items/scrimshaw_token.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")
const FLAWED_GEM := preload("res://data/items/flawed_gem.tres")

var _inventory: Inventory


func before_each() -> void:
	_inventory = Inventory.new()


# --- Stacking (criterion 1) ---


func test_fifteen_draughts_split_into_ten_plus_five() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 15)
	assert_eq(_inventory.stacks.size(), 2)
	assert_eq(_inventory.stacks[0].count, 10)
	assert_eq(_inventory.stacks[1].count, 5)
	assert_eq(_inventory.count_of(HEALING_DRAUGHT), 15)


func test_add_merges_into_partial_stack_before_starting_new_one() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 7)
	_inventory.add_item(HEALING_DRAUGHT, 5)
	assert_eq(_inventory.stacks.size(), 2)
	assert_eq(_inventory.stacks[0].count, 10)
	assert_eq(_inventory.stacks[1].count, 2)


func test_non_stackables_never_merge() -> void:
	_inventory.add_item(IRON_SWORD, 2)
	assert_eq(_inventory.stacks.size(), 2)
	assert_eq(_inventory.stacks[0].count, 1)
	assert_eq(_inventory.stacks[1].count, 1)


# --- Stolen provenance (spec 017) ---


func test_stolen_and_clean_stacks_do_not_merge() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 3)
	_inventory.add_item(HEALING_DRAUGHT, 3, true)
	assert_eq(_inventory.stacks.size(), 2, "stolen batch stays a distinct stack")
	assert_false(_inventory.stacks[0].stolen, "the first batch is clean")
	assert_true(_inventory.stacks[1].stolen, "the second batch is stolen")
	assert_eq(_inventory.count_of(HEALING_DRAUGHT), 6, "count_of sums both")


func test_stolen_batches_merge_with_each_other() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 4, true)
	_inventory.add_item(HEALING_DRAUGHT, 3, true)
	assert_eq(_inventory.stacks.size(), 1, "two stolen batches coalesce")
	assert_eq(_inventory.stacks[0].count, 7)
	assert_true(_inventory.stacks[0].stolen)


func test_add_defaults_to_clean() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 1)
	assert_false(_inventory.stacks[0].stolen, "add_item defaults stolen false")


# --- Weight ---


func test_total_weight_sums_weight_times_count() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 4)  # 4 x 0.5
	_inventory.add_item(IRON_SWORD)  # 8.0
	assert_almost_eq(_inventory.get_total_weight(), 10.0, 0.001)


func test_total_weight_includes_equipped_items() -> void:
	_inventory.add_item(IRON_SWORD)
	_inventory.equip(IRON_SWORD)
	assert_almost_eq(_inventory.get_total_weight(), 8.0, 0.001)


# --- Equip rules (criterion 3) ---


func test_weapon_equips_to_main_hand_and_leaves_stacks() -> void:
	_inventory.add_item(IRON_SWORD)
	assert_true(_inventory.equip(IRON_SWORD))
	assert_eq(_inventory.get_equipped(&"main_hand"), IRON_SWORD)
	assert_eq(_inventory.get_equipped_weapon(), IRON_SWORD)
	assert_eq(_inventory.count_of(IRON_SWORD), 0)


func test_armor_equips_to_declared_slot() -> void:
	_inventory.add_item(LEATHER_CUIRASS)
	assert_true(_inventory.equip(LEATHER_CUIRASS))
	assert_eq(_inventory.get_equipped(&"chest"), LEATHER_CUIRASS)


func test_armor_rejected_from_wrong_slot() -> void:
	_inventory.add_item(IRON_HELM)
	assert_false(_inventory.equip(IRON_HELM, &"chest"))
	assert_eq(_inventory.count_of(IRON_HELM), 1, "no mutation on refusal")
	assert_true(_inventory.equipment.is_empty())


func _sole_stack() -> ItemStack:
	return _inventory.stacks[0]


func test_equipping_a_stolen_item_then_unequipping_keeps_it_stolen() -> void:
	# The launder-your-loot exploit (spec 017 fix): equipment stores the shared
	# ItemDef, so a stolen helm must not come back clean from the slot.
	_inventory.add_item(IRON_HELM, 1, true)  # stolen
	assert_true(_inventory.equip(IRON_HELM))
	assert_true(_inventory.equipment_stolen.get(&"head", false), "the worn slot is flagged stolen")

	assert_true(_inventory.unequip(&"head"))
	assert_true(_sole_stack().stolen, "the helm returns to the stack still stolen")
	assert_true(_inventory.equipment_stolen.is_empty(), "the slot flag is cleared")


func test_equip_prefers_a_clean_copy_when_both_are_held() -> void:
	# A clean copy should be worn (and stay unflagged) while the stolen copy waits.
	_inventory.add_item(IRON_HELM, 1, false)  # clean
	_inventory.add_item(IRON_HELM, 1, true)  # stolen
	assert_true(_inventory.equip(IRON_HELM))

	assert_false(_inventory.equipment_stolen.has(&"head"), "the clean copy was worn")
	assert_true(_sole_stack().stolen, "the stolen copy stays in the stacks")


func test_equip_requires_a_loose_copy() -> void:
	assert_false(_inventory.equip(IRON_SWORD))


func test_misc_and_consumables_refuse_to_equip() -> void:
	_inventory.add_item(FLAWED_GEM)
	_inventory.add_item(HEALING_DRAUGHT)
	assert_false(_inventory.equip(FLAWED_GEM))
	assert_false(_inventory.equip(HEALING_DRAUGHT))


func test_two_handed_weapon_clears_off_hand_returning_shield() -> void:
	_inventory.add_item(WOODEN_SHIELD)
	_inventory.add_item(RUSTY_CLAYMORE)
	_inventory.equip(WOODEN_SHIELD)
	assert_true(_inventory.equip(RUSTY_CLAYMORE))
	assert_null(_inventory.get_equipped(&"off_hand"))
	assert_eq(_inventory.count_of(WOODEN_SHIELD), 1, "shield returned to stacks")


func test_shield_refused_while_two_handed_weapon_held() -> void:
	_inventory.add_item(RUSTY_CLAYMORE)
	_inventory.add_item(WOODEN_SHIELD)
	_inventory.equip(RUSTY_CLAYMORE)
	assert_false(_inventory.equip(WOODEN_SHIELD))
	assert_eq(_inventory.get_equipped(&"main_hand"), RUSTY_CLAYMORE)
	assert_eq(_inventory.count_of(WOODEN_SHIELD), 1, "no mutation on refusal")


func test_second_ring_fills_ring_2_and_third_swaps_ring_1() -> void:
	_inventory.add_item(ROPE_RING, 3)
	assert_true(_inventory.equip(ROPE_RING))
	assert_eq(_inventory.get_equipped(&"ring_1"), ROPE_RING)
	assert_true(_inventory.equip(ROPE_RING))
	assert_eq(_inventory.get_equipped(&"ring_2"), ROPE_RING)
	assert_eq(_inventory.count_of(ROPE_RING), 1)
	# Both full: third equip swaps ring_1, count stays consistent.
	assert_true(_inventory.equip(ROPE_RING))
	assert_eq(_inventory.count_equipped(ROPE_RING), 2)
	assert_eq(_inventory.count_of(ROPE_RING), 1)


func test_explicit_ring_slot_request_is_honored() -> void:
	_inventory.add_item(ROPE_RING)
	assert_true(_inventory.equip(ROPE_RING, &"ring_2"))
	assert_null(_inventory.get_equipped(&"ring_1"))
	assert_eq(_inventory.get_equipped(&"ring_2"), ROPE_RING)


func test_equipping_into_occupied_slot_returns_old_item() -> void:
	_inventory.add_item(IRON_SWORD)
	_inventory.add_item(RUSTY_CLAYMORE)
	_inventory.equip(IRON_SWORD)
	assert_true(_inventory.equip(RUSTY_CLAYMORE))
	assert_eq(_inventory.get_equipped(&"main_hand"), RUSTY_CLAYMORE)
	assert_eq(_inventory.count_of(IRON_SWORD), 1, "old weapon back in stacks")


func test_total_armor_rating_sums_equipped_pieces_only() -> void:
	_inventory.add_item(LEATHER_CUIRASS)
	_inventory.add_item(IRON_HELM)
	_inventory.add_item(WOODEN_SHIELD)
	_inventory.add_item(SCRIMSHAW_TOKEN)
	_inventory.equip(LEATHER_CUIRASS)
	_inventory.equip(IRON_HELM)
	_inventory.equip(WOODEN_SHIELD)
	_inventory.equip(SCRIMSHAW_TOKEN)
	assert_eq(_inventory.get_total_armor_rating(), 15)
	_inventory.unequip(&"off_hand")
	assert_eq(_inventory.get_total_armor_rating(), 10, "loose shield does not count")


func test_unequip_moves_item_back_and_clears_slot() -> void:
	_inventory.add_item(IRON_HELM)
	_inventory.equip(IRON_HELM)
	assert_true(_inventory.unequip(&"head"))
	assert_null(_inventory.get_equipped(&"head"))
	assert_eq(_inventory.count_of(IRON_HELM), 1)


func test_unequip_empty_slot_returns_false() -> void:
	assert_false(_inventory.unequip(&"head"))


func test_get_equipped_weapon_null_when_unarmed() -> void:
	assert_null(_inventory.get_equipped_weapon())


# --- Removal edges (criterion 5) ---


func test_remove_more_than_present_fails_without_mutation() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 3)
	assert_false(_inventory.remove_item(HEALING_DRAUGHT, 4))
	assert_eq(_inventory.count_of(HEALING_DRAUGHT), 3)


func test_remove_equipped_item_unequips_it_first() -> void:
	_inventory.add_item(IRON_SWORD)
	_inventory.equip(IRON_SWORD)
	assert_true(_inventory.remove_item(IRON_SWORD))
	assert_null(_inventory.get_equipped(&"main_hand"))
	assert_eq(_inventory.count_of(IRON_SWORD), 0)


func test_remove_prefers_loose_copies_over_equipped() -> void:
	_inventory.add_item(IRON_SWORD, 2)
	_inventory.equip(IRON_SWORD)
	assert_true(_inventory.remove_item(IRON_SWORD))
	assert_eq(_inventory.get_equipped(&"main_hand"), IRON_SWORD, "equipped copy kept")
	assert_eq(_inventory.count_of(IRON_SWORD), 0)


func test_removing_stack_to_zero_deletes_the_stack() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 2)
	assert_true(_inventory.remove_item(HEALING_DRAUGHT, 2))
	assert_true(_inventory.stacks.is_empty())


func test_gold_never_goes_negative() -> void:
	_inventory.add_gold(50)
	assert_false(_inventory.spend_gold(60))
	assert_eq(_inventory.gold, 50)
	assert_true(_inventory.spend_gold(50))
	assert_eq(_inventory.gold, 0)


# --- Serialization readiness (criterion 7) ---


func test_duplicate_true_round_trips_stacks_gold_and_equipment() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 12)
	_inventory.add_item(IRON_SWORD)
	_inventory.add_gold(250)
	_inventory.add_item(RUSTY_CLAYMORE)
	_inventory.add_item(ROPE_RING, 2)
	_inventory.equip(RUSTY_CLAYMORE)
	_inventory.equip(ROPE_RING)
	_inventory.equip(ROPE_RING)
	var copy := _inventory.duplicate(true) as Inventory
	assert_eq(copy.gold, 250)
	assert_eq(copy.stacks.size(), _inventory.stacks.size())
	for i: int in _inventory.stacks.size():
		# duplicate(true) deep-copies the ItemDefs too, so compare by id.
		assert_eq(copy.stacks[i].item.id, _inventory.stacks[i].item.id)
		assert_eq(copy.stacks[i].count, _inventory.stacks[i].count)
	assert_eq(copy.equipment.size(), _inventory.equipment.size())
	for slot: StringName in _inventory.equipment:
		assert_eq(copy.equipment[slot].id, _inventory.equipment[slot].id)


func test_duplicate_is_independent_of_the_original() -> void:
	_inventory.add_item(HEALING_DRAUGHT, 5)
	_inventory.add_gold(100)
	_inventory.add_item(IRON_SWORD)
	_inventory.equip(IRON_SWORD)
	var copy := _inventory.duplicate(true) as Inventory
	_inventory.remove_item(HEALING_DRAUGHT, 5)
	_inventory.spend_gold(100)
	_inventory.unequip(&"main_hand")
	assert_eq(copy.count_of(copy.stacks[0].item), 5)
	assert_eq(copy.gold, 100)
	assert_eq(copy.equipment.size(), 1)


# --- Combat equipment helpers (spec 004 amendment) ---


func test_equipped_shield_is_null_when_off_hand_empty() -> void:
	assert_null(_inventory.get_equipped_shield())


func test_equipped_shield_returns_off_hand_armor() -> void:
	_inventory.add_item(WOODEN_SHIELD)
	_inventory.equip(WOODEN_SHIELD)
	assert_eq(_inventory.get_equipped_shield(), WOODEN_SHIELD)


func test_armor_skill_ids_empty_with_nothing_equipped() -> void:
	assert_eq(_inventory.get_equipped_armor_skill_ids(), [] as Array[StringName])


func test_armor_skill_ids_collects_distinct_skills() -> void:
	_inventory.add_item(LEATHER_CUIRASS)
	_inventory.add_item(IRON_HELM)
	_inventory.add_item(WOODEN_SHIELD)  # heavy_armor, same as helm
	_inventory.equip(LEATHER_CUIRASS)
	_inventory.equip(IRON_HELM)
	_inventory.equip(WOODEN_SHIELD)
	var ids := _inventory.get_equipped_armor_skill_ids()
	assert_eq(ids.size(), 2)
	assert_has(ids, &"light_armor")
	assert_has(ids, &"heavy_armor")


func test_armor_skill_ids_excludes_jewelry_and_weapons() -> void:
	_inventory.add_item(ROPE_RING)
	_inventory.add_item(SCRIMSHAW_TOKEN)
	_inventory.add_item(IRON_SWORD)
	_inventory.equip(ROPE_RING)
	_inventory.equip(SCRIMSHAW_TOKEN)
	_inventory.equip(IRON_SWORD)
	assert_eq(_inventory.get_equipped_armor_skill_ids(), [] as Array[StringName])
