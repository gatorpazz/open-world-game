extends GutTest
## Unit tests for CharacterSheet (spec 001, acceptance criteria 1-4 and 6).
## Default balance values assumed by the math below: skill_xp_base 15,
## skill_xp_per_level 3, level_up_threshold 10, attribute_points_per_level 3,
## skill starts 5/25, attribute start 30, caps 100.

const BALANCE_PATH := "res://data/balance/balance_config.tres"
const SKILL_IDS: Array[StringName] = [
	&"blades",
	&"ranged",
	&"block",
	&"heavy_armor",
	&"evocation",
	&"mending",
	&"warding",
	&"alchemy",
	&"sneak",
	&"security",
	&"light_armor",
	&"persuasion",
]
const MAJORS: Array[StringName] = [
	&"blades",
	&"block",
	&"heavy_armor",
	&"evocation",
	&"sneak",
]
const MINOR := &"security"
const MAJOR := &"blades"


func _make_sheet(balance: BalanceConfig = null) -> CharacterSheet:
	if balance == null:
		balance = load(BALANCE_PATH) as BalanceConfig
	var sheet := CharacterSheet.new()
	sheet.setup(SKILL_IDS, MAJORS, balance)
	return sheet


func _level_once(sheet: CharacterSheet, skill_id: StringName) -> void:
	assert_eq(sheet.gain_skill_xp(skill_id, sheet.xp_required(skill_id)), 1)


# --- Setup ---


func test_setup_starting_values() -> void:
	var sheet := _make_sheet()
	for attribute: StringName in CharacterSheet.ATTRIBUTE_NAMES:
		assert_eq(sheet.attributes[attribute], 30, "%s starts at 30" % attribute)
	assert_eq(sheet.skills[MAJOR], 25, "major skills start at 25")
	assert_eq(sheet.skills[MINOR], 5, "minor skills start at 5")
	assert_eq(sheet.level, 1)
	assert_eq(sheet.unspent_attribute_points, 0)


# --- Criterion 1: skill xp, thresholds, multi-level, cap ---


func test_xp_accrues_below_threshold() -> void:
	var sheet := _make_sheet()
	assert_eq(sheet.gain_skill_xp(MINOR, 10), 0)
	assert_eq(sheet.skills[MINOR], 5)
	assert_eq(sheet.skill_xp[MINOR], 10)


func test_crossing_threshold_levels_and_carries_remainder() -> void:
	var sheet := _make_sheet()
	# Level 5 requires 15 + 3 * 5 = 30 xp.
	assert_eq(sheet.gain_skill_xp(MINOR, 35), 1)
	assert_eq(sheet.skills[MINOR], 6)
	assert_eq(sheet.skill_xp[MINOR], 5)


func test_one_large_grant_produces_multiple_levels() -> void:
	var sheet := _make_sheet()
	# From level 5: 30 + 33 + 36 = 99 xp for three levels; 1 xp left over.
	assert_eq(sheet.gain_skill_xp(MINOR, 100), 3)
	assert_eq(sheet.skills[MINOR], 8)
	assert_eq(sheet.skill_xp[MINOR], 1)


func test_skill_caps_at_100_and_discards_overflow() -> void:
	var sheet := _make_sheet()
	sheet.skills[MINOR] = 99
	assert_eq(sheet.gain_skill_xp(MINOR, 100000), 1)
	assert_eq(sheet.skills[MINOR], 100)
	assert_eq(sheet.skill_xp[MINOR], 0, "xp beyond the cap is discarded")
	assert_eq(sheet.gain_skill_xp(MINOR, 50), 0, "capped skill gains nothing")
	assert_eq(sheet.skill_xp[MINOR], 0)


func test_zero_or_negative_xp_changes_nothing() -> void:
	var sheet := _make_sheet()
	assert_eq(sheet.gain_skill_xp(MINOR, 0), 0)
	assert_eq(sheet.gain_skill_xp(MINOR, -5), 0)
	assert_eq(sheet.skill_xp[MINOR], 0)


# --- Criterion 2: major skills drive character level ---


func test_ten_major_level_ups_trigger_one_character_level() -> void:
	var sheet := _make_sheet()
	for i: int in range(9):
		_level_once(sheet, MAJOR)
		assert_eq(sheet.level, 1, "no level-up before the threshold")
	_level_once(sheet, MAJOR)
	assert_eq(sheet.level, 2, "tenth major level-up levels the character")
	assert_eq(sheet.major_level_ups, 0)


func test_non_major_skills_never_advance_the_counter() -> void:
	var sheet := _make_sheet()
	for i: int in range(10):
		_level_once(sheet, MINOR)
	assert_eq(sheet.level, 1)
	assert_eq(sheet.major_level_ups, 0)


func test_major_counter_carries_remainder() -> void:
	var sheet := _make_sheet()
	# From level 25, twelve levels cost sum(15 + 3L, L = 25..36) = 1278 xp.
	assert_eq(sheet.gain_skill_xp(MAJOR, 1278), 12)
	assert_eq(sheet.level, 2)
	assert_eq(sheet.major_level_ups, 2, "remainder carries toward the next level")


# --- Criterion 3: attribute points ---


func _make_leveled_sheet() -> CharacterSheet:
	var sheet := _make_sheet()
	for i: int in range(10):
		_level_once(sheet, MAJOR)
	return sheet


func test_level_up_grants_attribute_points() -> void:
	var sheet := _make_leveled_sheet()
	assert_eq(sheet.unspent_attribute_points, 3)


func test_spend_attribute_point_raises_attribute() -> void:
	var sheet := _make_leveled_sheet()
	assert_true(sheet.spend_attribute_point(&"strength"))
	assert_eq(sheet.attributes[&"strength"], 31)
	assert_eq(sheet.unspent_attribute_points, 2)


func test_spend_refused_when_pool_empty() -> void:
	var sheet := _make_sheet()
	assert_false(sheet.spend_attribute_point(&"strength"))
	assert_eq(sheet.attributes[&"strength"], 30)


func test_spend_refused_when_attribute_capped() -> void:
	var sheet := _make_leveled_sheet()
	sheet.set_attribute(&"agility", 100)
	assert_false(sheet.spend_attribute_point(&"agility"))
	assert_eq(sheet.attributes[&"agility"], 100)
	assert_eq(sheet.unspent_attribute_points, 3, "no point consumed on refusal")


# --- Criterion 4: derived stats ---


func test_derived_stats_at_starting_attributes() -> void:
	var sheet := _make_sheet()
	assert_almost_eq(sheet.get_max_health(), 65.0, 0.001)  # 20 + 30 * 1.5
	assert_almost_eq(sheet.get_max_mana(), 45.0, 0.001)  # 30 * 1.5
	assert_almost_eq(sheet.get_max_stamina(), 60.0, 0.001)  # (30*4) * 0.5
	assert_almost_eq(sheet.get_carry_capacity(), 120.0, 0.001)  # 30 * 4.0


func test_derived_stats_update_with_attributes() -> void:
	var sheet := _make_sheet()
	sheet.set_attribute(&"endurance", 50)
	sheet.set_attribute(&"intellect", 80)
	sheet.set_attribute(&"strength", 10)
	assert_almost_eq(sheet.get_max_health(), 95.0, 0.001)  # 20 + 50 * 1.5
	assert_almost_eq(sheet.get_max_mana(), 120.0, 0.001)  # 80 * 1.5
	assert_almost_eq(sheet.get_max_stamina(), 60.0, 0.001)  # (10+50+30+30) * 0.5
	assert_almost_eq(sheet.get_carry_capacity(), 40.0, 0.001)  # 10 * 4.0


# --- Criterion 6: all constants come from the balance resource ---


func test_behavior_follows_balance_config_values() -> void:
	var altered: BalanceConfig = (load(BALANCE_PATH) as BalanceConfig).duplicate()
	altered.skill_xp_base = 100
	altered.health_base = 50.0
	altered.attribute_points_per_level = 7
	var sheet := _make_sheet(altered)

	# Default config levels a fresh minor skill on 35 xp; base 100 must not.
	assert_eq(sheet.gain_skill_xp(MINOR, 35), 0)
	assert_eq(sheet.xp_required(MINOR), 115)

	assert_almost_eq(sheet.get_max_health(), 95.0, 0.001)  # 50 + 30 * 1.5

	for i: int in range(10):
		_level_once(sheet, MAJOR)
	assert_eq(sheet.unspent_attribute_points, 7)
