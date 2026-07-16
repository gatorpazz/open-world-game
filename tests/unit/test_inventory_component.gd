extends GutTest
## Tests for InventoryComponent signals, encumbrance, and consumable use
## (spec 002, criteria 2 and 4). Default sheet: strength 30 -> capacity
## 120; max health 65, max mana 45.

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const RUSTY_CLAYMORE := preload("res://data/items/rusty_claymore.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")
const SACK_OF_ORE := preload("res://data/items/sack_of_ore.tres")

var _stats: StatsComponent
var _component: InventoryComponent


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_component = InventoryComponent.new()
	_component.stats = _stats
	add_child_autofree(_component)
	watch_signals(_component)


func test_item_added_signal_payload() -> void:
	_component.add_item(HEALING_DRAUGHT, 3)
	assert_signal_emitted_with_parameters(_component, "item_added", [HEALING_DRAUGHT, 3])


func test_item_removed_signal_payload() -> void:
	_component.add_item(HEALING_DRAUGHT, 3)
	assert_true(_component.remove_item(HEALING_DRAUGHT, 2))
	assert_signal_emitted_with_parameters(_component, "item_removed", [HEALING_DRAUGHT, 2])


func test_failed_remove_emits_nothing() -> void:
	assert_false(_component.remove_item(HEALING_DRAUGHT))
	assert_signal_not_emitted(_component, "item_removed")


func test_equipment_changed_on_equip_and_unequip() -> void:
	_component.add_item(IRON_SWORD)
	assert_true(_component.equip(IRON_SWORD))
	assert_signal_emitted_with_parameters(
		_component, "equipment_changed", [&"main_hand", IRON_SWORD]
	)
	assert_true(_component.unequip(&"main_hand"))
	assert_signal_emitted_with_parameters(_component, "equipment_changed", [&"main_hand", null])


func test_two_handed_equip_emits_for_both_hand_slots() -> void:
	_component.add_item(WOODEN_SHIELD)
	_component.add_item(RUSTY_CLAYMORE)
	_component.equip(WOODEN_SHIELD)  # emission 0: off_hand = shield
	_component.equip(RUSTY_CLAYMORE)
	assert_signal_emitted_with_parameters(
		_component, "equipment_changed", [&"main_hand", RUSTY_CLAYMORE], 1
	)
	assert_signal_emitted_with_parameters(_component, "equipment_changed", [&"off_hand", null], 2)


func test_encumbrance_signal_when_exceeding_capacity() -> void:
	_component.add_item(SACK_OF_ORE, 5)  # 150 > 120
	assert_signal_emitted_with_parameters(_component, "encumbrance_changed", [150.0, 120.0, true])
	assert_signal_emit_count(_component, "encumbrance_changed", 1)
	assert_true(_component.is_encumbered())


func test_encumbrance_signal_on_relief() -> void:
	_component.add_item(SACK_OF_ORE, 5)
	_component.remove_item(SACK_OF_ORE)
	assert_signal_emitted_with_parameters(_component, "encumbrance_changed", [120.0, 120.0, false])
	assert_signal_emit_count(_component, "encumbrance_changed", 2)
	assert_false(_component.is_encumbered())


func test_exactly_at_capacity_is_not_encumbered() -> void:
	_component.add_item(SACK_OF_ORE, 4)  # exactly 120
	assert_signal_not_emitted(_component, "encumbrance_changed")
	assert_false(_component.is_encumbered())


func test_speed_multiplier_sourced_from_balance_config() -> void:
	assert_almost_eq(_component.get_speed_multiplier(), 1.0, 0.001)
	_component.add_item(SACK_OF_ORE, 5)
	assert_almost_eq(
		_component.get_speed_multiplier(), _stats.sheet.config.encumbered_speed_multiplier, 0.001
	)
	# Prove the value tracks the config rather than a hardcoded constant.
	_stats.sheet.config = _stats.sheet.config.duplicate()
	_stats.sheet.config.encumbered_speed_multiplier = 0.5
	assert_almost_eq(_component.get_speed_multiplier(), 0.5, 0.001)


func test_use_consumable_restores_health_and_decrements_stack() -> void:
	_component.add_item(HEALING_DRAUGHT, 2)
	_stats.set_current_health(10.0)
	watch_signals(_stats)
	assert_true(_component.use_consumable(HEALING_DRAUGHT))
	assert_almost_eq(_stats.current_health, 35.0, 0.001)
	assert_signal_emitted_with_parameters(_stats, "health_changed", [35.0, 65.0])
	assert_signal_not_emitted(_stats, "mana_changed", "zero delta stays silent")
	assert_signal_emitted_with_parameters(_component, "item_removed", [HEALING_DRAUGHT, 1])
	assert_eq(_component.inventory.count_of(HEALING_DRAUGHT), 1)


func test_use_consumable_clamps_at_max_health() -> void:
	_component.add_item(HEALING_DRAUGHT)
	_stats.set_current_health(60.0)
	_component.use_consumable(HEALING_DRAUGHT)
	assert_almost_eq(_stats.current_health, 65.0, 0.001)


func test_using_last_consumable_removes_stack_then_next_use_fails() -> void:
	_component.add_item(HEALING_DRAUGHT)
	_stats.set_current_health(10.0)
	assert_true(_component.use_consumable(HEALING_DRAUGHT))
	assert_true(_component.inventory.stacks.is_empty())
	assert_false(_component.use_consumable(HEALING_DRAUGHT))
	assert_almost_eq(_stats.current_health, 35.0, 0.001, "no restore on failed use")
	assert_signal_emit_count(_component, "item_removed", 1)


func test_gold_signal_and_overspend_refusal() -> void:
	_component.add_gold(100)
	assert_signal_emitted_with_parameters(_component, "gold_changed", [100])
	assert_false(_component.spend_gold(150))
	assert_signal_emit_count(_component, "gold_changed", 1)
	assert_true(_component.spend_gold(40))
	assert_signal_emitted_with_parameters(_component, "gold_changed", [60])
