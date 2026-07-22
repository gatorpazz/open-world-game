extends GutTest
## The lock gate (spec 017, acceptance criterion 5): a held key opens a lock for
## free, a pick attempt spends one lockpick, and the deterministic odds
## endpoints (skill far above / below difficulty) decide success.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LOCKPICK := preload("res://data/items/lockpick.tres")
const ROPE_RING := preload("res://data/items/rope_ring.tres")  # stands in as a key

var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func _picks_held() -> int:
	return _player.inventory_component.inventory.count_of(LOCKPICK)


func _set_security(level: int) -> void:
	_player.stats.sheet.skills[&"security"] = level


func test_unlocked_target_opens_freely() -> void:
	_player.inventory_component.add_item(LOCKPICK, 1)
	assert_true(Lockpicking.try_open(false, 0, &"", _player), "an unlocked target just opens")
	assert_eq(_picks_held(), 1, "no pick spent on an unlocked target")


func test_locked_with_no_pick_and_no_key_stays_shut() -> void:
	assert_false(Lockpicking.try_open(true, 50, &"", _player), "no pick, no entry")


func test_a_held_key_opens_without_spending_a_pick() -> void:
	_player.inventory_component.add_item(LOCKPICK, 1)
	_player.inventory_component.add_item(ROPE_RING, 1)
	assert_true(Lockpicking.try_open(true, 90, &"rope_ring", _player), "the key opens it")
	assert_eq(_picks_held(), 1, "a key spends no pick")


func test_a_trivial_lock_opens_and_consumes_one_pick() -> void:
	_set_security(100)
	_player.inventory_component.add_item(LOCKPICK, 1)
	assert_true(Lockpicking.try_open(true, 0, &"", _player), "skill far above difficulty ⇒ opens")
	assert_eq(_picks_held(), 0, "the attempt spent the pick")


func test_an_impossible_lock_holds_but_still_costs_the_pick() -> void:
	_set_security(100)
	_player.inventory_component.add_item(LOCKPICK, 1)
	assert_false(
		Lockpicking.try_open(true, 10000, &"", _player), "difficulty far above skill ⇒ holds"
	)
	assert_eq(_picks_held(), 0, "a failed attempt still spends the pick")
