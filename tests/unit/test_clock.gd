extends GutTest
## The WorldClock pure helpers (spec 020, acceptance criterion 1): bell→day rollover,
## multi-day carry, and the 9-day circuit position. Loads the real config.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func test_advance_within_a_day_moves_the_bell() -> void:
	var clock := WorldClock.new()  # day 1, bell START_BELL (3.0)
	clock.advance(2.0, _config)
	assert_eq(clock.day, 1, "same day")
	assert_almost_eq(clock.bell, WorldClock.START_BELL + 2.0, 0.001, "the bell moved")


func test_bell_rolls_over_into_the_next_day() -> void:
	var clock := WorldClock.new()
	clock.advance(_config.bells_per_day, _config)  # a full day
	assert_eq(clock.day, 2, "rolled into the next day")
	assert_almost_eq(clock.bell, WorldClock.START_BELL, 0.001, "the bell wraps by a day's worth")


func test_a_long_advance_carries_multiple_days() -> void:
	var clock := WorldClock.new()
	clock.advance(_config.bells_per_day * 2 + 1, _config)
	assert_eq(clock.day, 3, "two whole days carried")
	assert_almost_eq(clock.bell, WorldClock.START_BELL + 1.0, 0.001, "plus the remainder bell")


func test_circuit_day_wraps_at_the_circuit_length() -> void:
	var clock := WorldClock.new()
	clock.day = 1
	assert_eq(clock.circuit_day(_config), 1, "first day of the circuit")
	clock.day = _config.circuit_length
	assert_eq(clock.circuit_day(_config), _config.circuit_length, "the last day")
	clock.day = _config.circuit_length + 1
	assert_eq(clock.circuit_day(_config), 1, "the next circuit starts over")
