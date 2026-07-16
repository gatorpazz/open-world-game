extends GutTest
## Tests for the pure Inventory resource: stacking, weight, equip rules,
## removal edges, gold, and duplicate(true) round-trips (spec 002).

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const RUSTY_CLAYMORE := preload("res://data/items/rusty_claymore.tres")
const LEATHER_CUIRASS := preload("res://data/items/leather_cuirass.tres")
const IRON_HELM := preload("res://data/items/iron_helm.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const PLAIN_RING := preload("res://data/items/plain_ring.tres")
const BONE_AMULET := preload("res://data/items/bone_amulet.tres")
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
	_inventory.add_item(PLAIN_RING, 3)
	assert_true(_inventory.equip(PLAIN_RING))
	assert_eq(_inventory.get_equipped(&"ring_1"), PLAIN_RING)
	assert_true(_inventory.equip(PLAIN_RING))
	assert_eq(_inventory.get_equipped(&"ring_2"), PLAIN_RING)
	assert_eq(_inventory.count_of(PLAIN_RING), 1)
	# Both full: third equip swaps ring_1, count stays consistent.
	assert_true(_inventory.equip(PLAIN_RING))
	assert_eq(_inventory.count_equipped(PLAIN_RING), 2)
	assert_eq(_inventory.count_of(PLAIN_RING), 1)


func test_explicit_ring_slot_request_is_honored() -> void:
	_inventory.add_item(PLAIN_RING)
	assert_true(_inventory.equip(PLAIN_RING, &"ring_2"))
	assert_null(_inventory.get_equipped(&"ring_1"))
	assert_eq(_inventory.get_equipped(&"ring_2"), PLAIN_RING)


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
	_inventory.add_item(BONE_AMULET)
	_inventory.equip(LEATHER_CUIRASS)
	_inventory.equip(IRON_HELM)
	_inventory.equip(WOODEN_SHIELD)
	_inventory.equip(BONE_AMULET)
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
	_inventory.add_item(PLAIN_RING, 2)
	_inventory.equip(RUSTY_CLAYMORE)
	_inventory.equip(PLAIN_RING)
	_inventory.equip(PLAIN_RING)
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
