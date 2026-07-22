extends GutTest
## FactionRules pure logic (spec 015, criterion 3): reconcile, can_advance,
## is_chartered_under, blocks_joining — read against the real faction library.

var _standing: FactionStanding
var _library: Dictionary[StringName, FactionDef] = {}


func before_each() -> void:
	_standing = FactionStanding.new()
	_library = FactionLibrary.get_factions()


func test_reconcile_seeds_only_held_join_entries() -> void:
	var entries: Array[StringName] = [&"joined_the_wardens"]
	FactionRules.reconcile(_standing, entries, _library)
	assert_true(_standing.is_member(&"wardens"), "held join entry seeds membership")
	assert_false(_standing.is_member(&"reciters"), "unheld faction not seeded")
	assert_eq(_standing.get_rank(&"wardens"), 0, "seeded at rank 0")


func test_reconcile_is_idempotent_and_preserves_progress() -> void:
	var entries: Array[StringName] = [&"joined_the_wardens"]
	FactionRules.reconcile(_standing, entries, _library)
	_standing.rank[&"wardens"] = 2
	_standing.reputation[&"wardens"] = 30
	FactionRules.reconcile(_standing, entries, _library)
	assert_eq(_standing.get_rank(&"wardens"), 2, "rank-up survives a second reconcile")
	assert_eq(_standing.get_reputation(&"wardens"), 30, "reputation survives a second reconcile")


func test_can_advance_requires_reputation_and_skill() -> void:
	var wardens := _library[&"wardens"]
	var entries: Array[StringName] = [&"joined_the_wardens"]
	FactionRules.reconcile(_standing, entries, _library)
	# rank 0 -> rank 1 needs reputation_min 10 and security 25.
	var qualified := _sheet_with_skill(&"security", 25)
	assert_false(
		FactionRules.can_advance(wardens, _standing, qualified), "blocked by low reputation"
	)
	_standing.reputation[&"wardens"] = 10
	assert_true(
		FactionRules.can_advance(wardens, _standing, qualified), "reputation + skill both met"
	)
	var under_skilled := _sheet_with_skill(&"security", 10)
	assert_false(
		FactionRules.can_advance(wardens, _standing, under_skilled), "blocked by low skill"
	)


func test_can_advance_false_at_top_rank() -> void:
	var wardens := _library[&"wardens"]
	var entries: Array[StringName] = [&"joined_the_wardens"]
	FactionRules.reconcile(_standing, entries, _library)
	_standing.rank[&"wardens"] = wardens.ranks.size() - 1
	_standing.reputation[&"wardens"] = 999
	var maxed := _sheet_with_skill(&"security", 100)
	assert_false(FactionRules.can_advance(wardens, _standing, maxed), "no rank beyond the top")


func test_can_advance_false_for_non_member() -> void:
	var wardens := _library[&"wardens"]
	var sheet := _sheet_with_skill(&"security", 100)
	assert_false(FactionRules.can_advance(wardens, _standing, sheet), "non-member cannot advance")


func test_charter_is_derived_from_rank() -> void:
	var entries: Array[StringName] = [&"joined_the_wardens"]
	FactionRules.reconcile(_standing, entries, _library)
	# Wardens charter at rank 1; a fresh rank-0 member is not yet chartered.
	assert_false(
		FactionRules.is_chartered_under(&"wardens", _standing, _library), "rank 0 is not chartered"
	)
	_standing.rank[&"wardens"] = 1
	assert_true(
		FactionRules.is_chartered_under(&"wardens", _standing, _library), "rank 1 is chartered"
	)


func test_non_chartering_faction_never_charters() -> void:
	var entries: Array[StringName] = [&"joined_the_reciters"]
	FactionRules.reconcile(_standing, entries, _library)
	_standing.rank[&"reciters"] = 99
	assert_false(
		FactionRules.is_chartered_under(&"reciters", _standing, _library),
		"charter_rank -1 never charters"
	)


func test_charter_false_for_non_member() -> void:
	assert_false(
		FactionRules.is_chartered_under(&"wardens", _standing, _library),
		"non-member is not chartered"
	)


func test_blocks_joining_against_a_rival() -> void:
	var faction_a := FactionDef.new()
	faction_a.id = &"faction_a"
	faction_a.rivals = [&"faction_b"]
	_standing.seed_if_absent(&"faction_b", 0, 0)
	assert_true(
		FactionRules.blocks_joining(faction_a, _standing), "rival membership blocks joining"
	)


func test_shipped_factions_never_block() -> void:
	var entries: Array[StringName] = [
		&"joined_the_wardens", &"joined_the_licensed_crews", &"joined_the_reciters"
	]
	FactionRules.reconcile(_standing, entries, _library)
	for faction_id: StringName in _library:
		assert_false(
			FactionRules.blocks_joining(_library[faction_id], _standing),
			"%s never blocks (independence ruling)" % faction_id
		)


func _sheet_with_skill(skill_id: StringName, level: int) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	if skill_id != &"":
		sheet.skills[skill_id] = level
	return sheet
