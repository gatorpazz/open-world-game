extends GutTest
## Pure LockRules pick-chance curve (spec 017, acceptance criterion 1). Loads
## the real balance config; no scene tree, no RNG (the caller rolls).

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func test_parity_is_an_even_chance() -> void:
	assert_almost_eq(LockRules.pick_chance(50, 50, _config), 0.5, 0.001, "skill == difficulty")


func test_chance_is_clamped_to_unit_interval() -> void:
	for skill: int in [0, 25, 50, 75, 100]:
		for difficulty: int in [0, 25, 50, 75, 100]:
			var chance := LockRules.pick_chance(skill, difficulty, _config)
			assert_between(chance, 0.0, 1.0, "chance in [0,1] for %d vs %d" % [skill, difficulty])


func test_endpoints_reach_certainty() -> void:
	# The deterministic endpoints the caller's roll leans on.
	assert_eq(LockRules.pick_chance(100, 0, _config), 1.0, "a full skill lead ⇒ certain")
	assert_eq(LockRules.pick_chance(0, 100, _config), 0.0, "a full difficulty lead ⇒ hopeless")


func test_monotonic_non_decreasing_in_skill() -> void:
	var prev := -1.0
	for skill: int in range(0, 101, 5):
		var chance := LockRules.pick_chance(skill, 60, _config)
		assert_gte(chance, prev, "chance never drops as skill rises (at skill %d)" % skill)
		prev = chance


func test_monotonic_non_increasing_in_difficulty() -> void:
	var prev := 2.0
	for difficulty: int in range(0, 101, 5):
		var chance := LockRules.pick_chance(60, difficulty, _config)
		assert_lte(chance, prev, "chance never rises as difficulty rises (at diff %d)" % difficulty)
		prev = chance
