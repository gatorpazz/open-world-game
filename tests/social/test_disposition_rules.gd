extends GutTest
## DispositionRules math (spec 019, acceptance criterion 1): the disposition sum,
## the persuade odds, the move deltas, the bribe cost, and the price factor —
## all pure, driven off the real balance config.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func test_base_of_uses_def_or_default() -> void:
	var with_base := NPCDef.new()
	with_base.base_disposition = 70
	assert_eq(DispositionRules.base_of(with_base, _config), 70, "an explicit base wins")
	var unset := NPCDef.new()
	assert_eq(
		DispositionRules.base_of(unset, _config),
		_config.disposition_base_default,
		"0 falls back to the config default"
	)


func test_disposition_sums_the_terms() -> void:
	# base 40 + rep 20·0.5 (=10) + modifier 5 − no overcast = 55.
	var value := DispositionRules.disposition(40, 20, 5, false, _config)
	assert_eq(value, 55, "base + weighted rep + modifier")


func test_disposition_subtracts_the_overcast_penalty() -> void:
	var clear := DispositionRules.disposition(50, 0, 0, false, _config)
	var overcast := DispositionRules.disposition(50, 0, 0, true, _config)
	assert_eq(clear - overcast, _config.disposition_overcast_penalty, "overcast docks the penalty")


func test_disposition_clamps_to_the_range() -> void:
	assert_eq(DispositionRules.disposition(200, 0, 0, false, _config), _config.disposition_max)
	assert_eq(DispositionRules.disposition(-200, 0, 0, false, _config), _config.disposition_min)


func test_persuade_chance_rises_with_skill() -> void:
	var low := DispositionRules.persuade_chance(DispositionRules.ADMIRE, 10, 50, _config)
	var high := DispositionRules.persuade_chance(DispositionRules.ADMIRE, 90, 50, _config)
	assert_gt(high, low, "more persuasion skill, better odds")


func test_admire_rises_with_disposition_but_intimidate_falls() -> void:
	var admire_cold := DispositionRules.persuade_chance(DispositionRules.ADMIRE, 50, 20, _config)
	var admire_warm := DispositionRules.persuade_chance(DispositionRules.ADMIRE, 50, 80, _config)
	assert_gt(admire_warm, admire_cold, "admire rises with rapport")
	var bully_cold := DispositionRules.persuade_chance(DispositionRules.INTIMIDATE, 50, 20, _config)
	var bully_warm := DispositionRules.persuade_chance(DispositionRules.INTIMIDATE, 50, 80, _config)
	assert_lt(bully_warm, bully_cold, "bullying a friend is harder")


func test_persuade_chance_is_clamped() -> void:
	var floor_chance := DispositionRules.persuade_chance(
		DispositionRules.INTIMIDATE, 0, 100, _config
	)
	var ceil_chance := DispositionRules.persuade_chance(DispositionRules.BRIBE, 100, 100, _config)
	assert_almost_eq(floor_chance, _config.persuade_chance_min, 0.0001, "odds floor")
	assert_almost_eq(ceil_chance, _config.persuade_chance_max, 0.0001, "odds ceiling")


func test_move_delta_gain_on_success() -> void:
	assert_eq(
		DispositionRules.move_delta(DispositionRules.ADMIRE, true, _config),
		_config.persuade_gain_admire,
		"admire gains on success"
	)
	assert_eq(
		DispositionRules.move_delta(DispositionRules.BRIBE, true, _config),
		_config.persuade_gain_bribe
	)


func test_move_delta_failure_admire_zero_intimidate_backfires() -> void:
	assert_eq(
		DispositionRules.move_delta(DispositionRules.ADMIRE, false, _config), 0, "admire is safe"
	)
	assert_eq(
		DispositionRules.move_delta(DispositionRules.BRIBE, false, _config), 0, "bribe is safe"
	)
	assert_eq(
		DispositionRules.move_delta(DispositionRules.INTIMIDATE, false, _config),
		-_config.intimidate_backfire,
		"a failed intimidate backfires"
	)


func test_bribe_cost_rises_with_disposition() -> void:
	var cheap := DispositionRules.bribe_cost(10, _config)
	var dear := DispositionRules.bribe_cost(90, _config)
	assert_gt(dear, cheap, "bribing a friend costs more")
	assert_eq(cheap, _config.bribe_cost_base + roundi(10 * _config.bribe_cost_per_disposition))


func test_price_factor_favors_a_friendly_merchant() -> void:
	var neutral := DispositionRules.price_factor(_config.disposition_neutral, _config)
	assert_almost_eq(neutral, 1.0, 0.0001, "neutral disposition is no change")
	assert_lt(DispositionRules.price_factor(90, _config), 1.0, "a friendly merchant slides cheaper")
	assert_gt(DispositionRules.price_factor(10, _config), 1.0, "a cold one dearer")


func test_price_factor_is_clamped() -> void:
	assert_almost_eq(
		DispositionRules.price_factor(100000, _config), _config.price_factor_min, 0.0001
	)
	assert_almost_eq(
		DispositionRules.price_factor(-100000, _config), _config.price_factor_max, 0.0001
	)
