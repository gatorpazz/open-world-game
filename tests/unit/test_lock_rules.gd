extends GutTest
## Pure LockRules pick-chance curve (spec 017, acceptance criterion 1). Loads
## the real balance config; no scene tree, no RNG (the caller rolls).

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func test_a_trivial_lock_always_opens() -> void:
	# Difficulty 0 is inside anyone's reach — a certain open, the caller's high
	# deterministic endpoint.
	assert_eq(LockRules.pick_chance(0, 0, _config), 1.0, "difficulty 0 ⇒ certain")
	assert_eq(LockRules.pick_chance(100, 0, _config), 1.0, "a master opens it certainly too")


func test_a_novice_reliably_opens_an_easy_lock() -> void:
	# The rebalance's whole point (2026-07-22 playtest): security 5 vs an easy
	# lock is a strong favourite, not a coin-flip.
	assert_gt(
		LockRules.pick_chance(5, 5, _config), 0.75, "a fresh character reliably picks an easy lock"
	)


func test_a_lock_beyond_reach_is_impossible() -> void:
	# difficulty >= security + base_competence ⇒ 0.0, cannot be forced.
	assert_eq(LockRules.pick_chance(5, 30, _config), 0.0, "diff at reach is hopeless")
	assert_eq(LockRules.pick_chance(0, 100, _config), 0.0, "a novice cannot force a master lock")


func test_chance_is_clamped_to_unit_interval() -> void:
	for skill: int in [0, 25, 50, 75, 100]:
		for difficulty: int in [0, 25, 50, 75, 100]:
			var chance := LockRules.pick_chance(skill, difficulty, _config)
			assert_between(chance, 0.0, 1.0, "chance in [0,1] for %d vs %d" % [skill, difficulty])


func test_skill_lifts_the_odds_against_a_fixed_lock() -> void:
	# The same lock is far more pickable with more skill — the lever crime wants.
	assert_lt(
		LockRules.pick_chance(5, 20, _config),
		LockRules.pick_chance(50, 20, _config),
		"more security ⇒ better odds on the same lock"
	)


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
