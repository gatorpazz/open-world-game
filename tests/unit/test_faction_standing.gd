extends GutTest
## FactionStanding pure state + the idempotent seed (spec 015, criterion 2).
## Serialization round-trip is proven in tests/unit/test_save_codec.gd.

var _standing: FactionStanding


func before_each() -> void:
	_standing = FactionStanding.new()


func test_fresh_standing_has_no_members() -> void:
	assert_false(_standing.is_member(&"wardens"), "no membership before seeding")
	assert_eq(_standing.get_reputation(&"wardens"), 0, "unknown faction reads 0 reputation")
	assert_eq(_standing.get_rank(&"wardens"), 0, "unknown faction reads rank 0")


func test_seed_if_absent_creates_a_record() -> void:
	_standing.seed_if_absent(&"wardens", 0, 5)
	assert_true(_standing.is_member(&"wardens"), "seeded faction is a member")
	assert_eq(_standing.get_rank(&"wardens"), 0, "seeded at rank 0")
	assert_eq(_standing.get_reputation(&"wardens"), 5, "seeded reputation")


func test_seed_if_absent_is_a_noop_on_existing_record() -> void:
	_standing.seed_if_absent(&"wardens", 0, 5)
	_standing.rank[&"wardens"] = 2
	_standing.reputation[&"wardens"] = 40
	_standing.seed_if_absent(&"wardens", 0, 5)
	assert_eq(_standing.get_rank(&"wardens"), 2, "existing rank preserved")
	assert_eq(_standing.get_reputation(&"wardens"), 40, "existing reputation preserved")


func test_adjust_reputation_moves_up_and_down() -> void:
	_standing.seed_if_absent(&"wardens", 0, 10)
	_standing.adjust_reputation(&"wardens", 5)
	assert_eq(_standing.get_reputation(&"wardens"), 15, "reputation rises")
	_standing.adjust_reputation(&"wardens", -20)
	assert_eq(_standing.get_reputation(&"wardens"), -5, "reputation can go negative")


func test_adjust_reputation_is_a_noop_for_non_members() -> void:
	_standing.adjust_reputation(&"wardens", 5)
	assert_false(_standing.is_member(&"wardens"), "adjust does not create membership")
	assert_eq(_standing.get_reputation(&"wardens"), 0, "non-member reputation unchanged")
