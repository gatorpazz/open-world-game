extends GutTest
## Unit tests for CombatMath (spec 004, acceptance criteria 1-2; spec 008,
## criterion 1).
## Default balance values assumed by the math below: damage skill mult
## 0.5..1.5, strength mult 0.5 + 0.01/point, stamina cost 5 + 0.5/weight,
## exhausted and block multipliers 0.5, armor scale 50, block chance
## 0.1 + 0.003/skill.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _cfg: BalanceConfig


func before_all() -> void:
	_cfg = load(BALANCE_PATH) as BalanceConfig


# --- attack_damage ---


func test_attack_damage_matches_formula_at_skill_endpoints() -> void:
	# Skill 0, strength 0: 10 * 0.5 * 0.5 = 2.5. Skill 100: 10 * 1.5 * 0.5.
	assert_almost_eq(CombatMath.attack_damage(10, 0, 0, false, _cfg), 2.5, 0.001)
	assert_almost_eq(CombatMath.attack_damage(10, 100, 0, false, _cfg), 7.5, 0.001)


func test_attack_damage_starting_character_with_iron_sword() -> void:
	# Blades 25 (major start), strength 30: 8 * 0.75 * 0.8 = 4.8.
	assert_almost_eq(CombatMath.attack_damage(8, 25, 30, false, _cfg), 4.8, 0.001)


func test_attack_damage_scales_with_strength() -> void:
	# Strength 100: 8 * 0.75 * 1.5 = 9.0.
	assert_almost_eq(CombatMath.attack_damage(8, 25, 100, false, _cfg), 9.0, 0.001)


func test_exhausted_multiplier_applies() -> void:
	var fresh := CombatMath.attack_damage(8, 25, 30, false, _cfg)
	var exhausted := CombatMath.attack_damage(8, 25, 30, true, _cfg)
	assert_almost_eq(exhausted, fresh * _cfg.exhausted_damage_multiplier, 0.001)


func test_damage_constants_come_from_config_not_code() -> void:
	var tweaked := _cfg.duplicate() as BalanceConfig
	tweaked.damage_skill_min = 1.0
	tweaked.damage_skill_max = 1.0
	tweaked.damage_strength_base = 1.0
	tweaked.damage_per_strength = 0.0
	assert_almost_eq(CombatMath.attack_damage(8, 25, 30, false, tweaked), 8.0, 0.001)


# --- stamina_cost ---


func test_stamina_cost_matches_formula() -> void:
	# Iron sword weight 8: 5 + 8 * 0.5 = 9. Weightless: base only.
	assert_almost_eq(CombatMath.stamina_cost(8.0, _cfg), 9.0, 0.001)
	assert_almost_eq(CombatMath.stamina_cost(0.0, _cfg), _cfg.attack_stamina_base, 0.001)


# --- block_chance ---


func test_block_chance_matches_formula() -> void:
	assert_almost_eq(CombatMath.block_chance(0, _cfg), 0.1, 0.001)
	assert_almost_eq(CombatMath.block_chance(25, _cfg), 0.175, 0.001)
	assert_almost_eq(CombatMath.block_chance(100, _cfg), 0.4, 0.001)


func test_block_chance_clamps_to_unit_range() -> void:
	assert_eq(CombatMath.block_chance(100000, _cfg), 1.0)
	var tweaked := _cfg.duplicate() as BalanceConfig
	tweaked.block_chance_base = 0.0
	tweaked.block_chance_per_skill = 0.0
	assert_eq(CombatMath.block_chance(0, tweaked), 0.0)


# --- armor_mitigation ---


func test_armor_curve_endpoints() -> void:
	assert_almost_eq(CombatMath.armor_mitigation(10.0, 0, _cfg), 10.0, 0.001)
	var scale_ar := int(_cfg.armor_mitigation_scale)
	assert_almost_eq(CombatMath.armor_mitigation(10.0, scale_ar, _cfg), 5.0, 0.001)


func test_armor_never_reduces_below_zero() -> void:
	assert_gt(CombatMath.armor_mitigation(10.0, 100000, _cfg), 0.0)


# --- spell_power ---


func test_spell_power_matches_lerp_at_skill_points() -> void:
	# Magnitude 10: skill 0 -> 5.0, 25 -> 7.5, 50 -> 10.0, 100 -> 15.0.
	assert_almost_eq(CombatMath.spell_power(10.0, 0, _cfg), 5.0, 0.001)
	assert_almost_eq(CombatMath.spell_power(10.0, 25, _cfg), 7.5, 0.001)
	assert_almost_eq(CombatMath.spell_power(10.0, 50, _cfg), 10.0, 0.001)
	assert_almost_eq(CombatMath.spell_power(10.0, 100, _cfg), 15.0, 0.001)


func test_spell_power_starting_character_with_minor_bolt() -> void:
	# Evocation 25 (major start): 8 * 0.75 = 6.0.
	assert_almost_eq(CombatMath.spell_power(8.0, 25, _cfg), 6.0, 0.001)


func test_spell_power_constants_come_from_config_not_code() -> void:
	var tweaked := _cfg.duplicate() as BalanceConfig
	tweaked.magic_skill_min = 2.0
	tweaked.magic_skill_max = 2.0
	assert_almost_eq(CombatMath.spell_power(8.0, 25, tweaked), 16.0, 0.001)


# --- ward_absorb ---


func test_ward_absorb_returns_min_of_damage_and_ward() -> void:
	assert_almost_eq(CombatMath.ward_absorb(4.0, 10.0), 4.0, 0.001)
	assert_almost_eq(CombatMath.ward_absorb(10.0, 4.0), 4.0, 0.001)
	assert_almost_eq(CombatMath.ward_absorb(10.0, 0.0), 0.0, 0.001)
	assert_almost_eq(CombatMath.ward_absorb(0.0, 10.0), 0.0, 0.001)


# --- resolve_defense ---


func test_roll_below_chance_with_shield_blocks_then_armors() -> void:
	# Block 25 -> chance 0.175; roll 0.1 blocks. 10 * 0.5 = 5, then AR 50 halves.
	var result := CombatMath.resolve_defense(10.0, 50, true, 25, 0.1, _cfg)
	assert_true(result.blocked)
	assert_almost_eq(result.final_damage, 2.5, 0.001)


func test_roll_above_chance_only_armors() -> void:
	var result := CombatMath.resolve_defense(10.0, 50, true, 25, 0.9, _cfg)
	assert_false(result.blocked)
	assert_almost_eq(result.final_damage, 5.0, 0.001)


func test_no_shield_never_blocks_even_on_roll_zero() -> void:
	var result := CombatMath.resolve_defense(10.0, 0, false, 100, 0.0, _cfg)
	assert_false(result.blocked)
	assert_almost_eq(result.final_damage, 10.0, 0.001)


func test_unarmored_unshielded_takes_raw_damage() -> void:
	var result := CombatMath.resolve_defense(7.7, 0, true, 25, 0.9, _cfg)
	assert_false(result.blocked)
	assert_almost_eq(result.final_damage, 7.7, 0.001)
