extends GutTest
## Validates data/balance/balance_config.tres (spec 003 adds interact_range,
## spec 004 adds the Combat and Creatures groups).

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func test_loads_as_balance_config() -> void:
	assert_not_null(_config)


func test_every_tunable_is_positive() -> void:
	for prop: Dictionary in _config.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = _config.get(prop.name)
		if value is int:
			assert_gt(value, 0, "%s must be positive" % prop.name)
		elif value is float:
			assert_gt(value, 0.0, "%s must be positive" % prop.name)


func test_interact_range_present() -> void:
	assert_gt(_config.interact_range, 0.0)


func test_combat_constants_are_coherent() -> void:
	assert_lt(_config.damage_skill_min, _config.damage_skill_max)
	assert_lte(_config.block_chance_base, 1.0)
	assert_lte(_config.exhausted_damage_multiplier, 1.0)
	assert_lte(_config.block_damage_multiplier, 1.0)
	assert_lte(_config.creature_idle_time_min, _config.creature_idle_time_max)
