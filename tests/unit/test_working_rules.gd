extends GutTest
## Pure WorkingRules — the licensing verdict + costs (spec 018, acceptance
## criterion 2). Loads the real balance config and spell content; no scene tree.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _spells: Dictionary[StringName, SpellDef] = {}


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_spells = SpellLibrary.get_spells()


func test_hearth_charm_is_always_licensed() -> void:
	var minor_bolt := _spells[&"minor_bolt"]  # min_skill 0, no order
	assert_false(WorkingRules.is_unlicensed(minor_bolt, false), "hearth-charm needs no charter")
	assert_false(WorkingRules.is_unlicensed(minor_bolt, true), "and stays licensed with one")


func test_a_chartered_working_is_licensed_only_with_the_charter() -> void:
	var greater_ward := _spells[&"greater_ward"]  # min_skill 25, stone_order
	assert_true(WorkingRules.is_unlicensed(greater_ward, false), "no charter ⇒ unlicensed")
	assert_false(WorkingRules.is_unlicensed(greater_ward, true), "with the charter ⇒ licensed")


func test_an_ordained_working_without_a_charter_is_unlicensed() -> void:
	var greater_bolt := _spells[&"greater_bolt"]  # min_skill 50, flame_order
	assert_true(
		WorkingRules.is_unlicensed(greater_bolt, false), "the outsider's Flamelash is unlicensed"
	)


func test_costs_read_the_config() -> void:
	var greater_bolt := _spells[&"greater_bolt"]
	assert_eq(
		WorkingRules.notice_cost(greater_bolt, _config), _config.notice_per_unlicensed_working
	)
	assert_eq(WorkingRules.working_bounty(greater_bolt, _config), _config.unlicensed_working_fine)
	assert_eq(WorkingRules.reputation_dock(_config), _config.crime_reputation_dock)
