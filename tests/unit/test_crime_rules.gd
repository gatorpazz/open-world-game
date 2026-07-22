extends GutTest
## Pure CrimeRules economics + the acquisition verdict (spec 017, acceptance
## criterion 3). Loads the real balance config and item content; no scene tree.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _items: Dictionary[StringName, ItemDef] = {}


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_items = ItemLibrary.get_items()


func test_theft_bounty_scales_base_value() -> void:
	var sword := _items[&"iron_sword"]  # base_value 50
	assert_eq(
		CrimeRules.theft_bounty(sword, _config),
		ceili(50 * _config.theft_bounty_multiplier),
		"bounty = base_value * multiplier"
	)


func test_theft_bounty_clamps_to_at_least_one() -> void:
	var freebie := _items[&"tally_log_copy"]  # base_value 0
	assert_eq(CrimeRules.theft_bounty(freebie, _config), 1, "even a worthless item carries weight")


func test_fine_scales_the_raw_bounty() -> void:
	assert_eq(
		CrimeRules.fine_owed(120, _config),
		ceili(120 * _config.fine_multiplier),
		"fine = bounty * mult"
	)
	assert_eq(CrimeRules.fine_owed(0, _config), 0, "no bounty, no fine")


func test_reputation_dock_reads_the_config() -> void:
	assert_eq(CrimeRules.reputation_dock(_config), _config.crime_reputation_dock)


func test_marks_stolen_on_any_owner() -> void:
	assert_false(CrimeRules.marks_stolen(&""), "an unowned source is free to take")
	assert_true(CrimeRules.marks_stolen(&"wardens"), "an owned source yields stolen goods")


func test_bounty_accrues_only_when_owned_and_witnessed() -> void:
	assert_true(CrimeRules.accrues_bounty(&"wardens", true), "owned + seen = bounty")
	assert_false(
		CrimeRules.accrues_bounty(&"wardens", false), "owned + unseen = no bounty (still stolen)"
	)
	assert_false(CrimeRules.accrues_bounty(&"", true), "unowned = never a crime, even seen")
