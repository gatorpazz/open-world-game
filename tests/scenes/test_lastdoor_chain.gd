extends GutTest
## The slice chain end-to-end on shipped data (spec 010, criteria 4-5):
## for_the_tallies walks both branches through real dialogue picks, the
## free-order courtship closes on the third reading heard, refusal
## defers (the make-good re-join works), the cache chain completes, and
## the three guild joins never block each other.

const TALLIES_PATH := "res://data/quests/for_the_tallies.tres"
const CACHE_PATH := "res://data/quests/the_roofed_cache.tres"

var _tallies: QuestDef
var _cache: QuestDef
var _journal: Journal
var _inventory: Inventory


func before_each() -> void:
	DialogueLibrary.reset()
	_tallies = load(TALLIES_PATH) as QuestDef
	_cache = load(CACHE_PATH) as QuestDef
	_journal = Journal.new()
	_inventory = Inventory.new()


func after_all() -> void:
	DialogueLibrary.reset()


func _pick(topic_id: StringName, npc_id: StringName, from_choice: bool = false) -> DialogueResponse:
	var topics := DialogueLibrary.get_topics()
	return DialogueEvaluator.pick_response(
		topics[topic_id], npc_id, _journal, _inventory, from_choice
	)


## Picks and applies the first matching response — a real dialogue turn.
## from_choice models a choice-button press (spec 013).
func _say(topic_id: StringName, npc_id: StringName, from_choice: bool = false) -> DialogueResponse:
	var response := _pick(topic_id, npc_id, from_choice)
	assert_not_null(response, "%s / %s has a matching response" % [topic_id, npc_id])
	if response != null:
		DialogueEvaluator.apply_effects(response, _journal)
	return response


func _status() -> QuestEvaluator.Status:
	return QuestEvaluator.status(_tallies, _journal)


# --- Derivation & branch A (criterion 4) ---


func test_chain_derives_not_started_then_active() -> void:
	assert_eq(_status(), QuestEvaluator.Status.NOT_STARTED)
	_journal.add_entry(&"woke_in_the_bait_square")
	assert_eq(_status(), QuestEvaluator.Status.ACTIVE)


func test_branch_a_stand_and_take_the_cord() -> void:
	_journal.add_entry(&"woke_in_the_bait_square")
	_say(&"for_the_tallies", &"torrum")
	assert_true(_journal.has_entry(&"the_captains_request"))
	_say(&"the_crews_side", &"wester")
	_say(&"the_orders_side", &"dossun")
	_say(&"the_wardens_side", &"bryony")
	assert_true(_journal.has_entry(&"the_town_takes_sides"))
	_journal.add_entry(&"the_two_tally_logs")  # the gated WorldItem
	_journal.add_entry(&"the_moth_test")  # the cage trigger
	_journal.add_entry(&"stood_for_the_tallies")  # the retest trigger
	_say(&"take_the_cord", &"torrum", true)  # the join is a choice press now (spec 015)
	assert_true(_journal.has_entry(&"joined_the_wardens"))
	assert_eq(_status(), QuestEvaluator.Status.COMPLETED)


func test_courtship_closes_only_on_the_third_reading() -> void:
	_journal.add_entry(&"woke_in_the_bait_square")
	_say(&"for_the_tallies", &"torrum")
	_say(&"the_wardens_side", &"bryony")
	assert_true(_journal.has_entry(&"heard_the_retest_side"))
	assert_false(_journal.has_entry(&"the_town_takes_sides"), "one reading is not the town")
	_say(&"the_orders_side", &"dossun")
	assert_false(_journal.has_entry(&"the_town_takes_sides"), "two readings are not the town")
	_say(&"the_crews_side", &"wester")
	assert_true(_journal.has_entry(&"the_town_takes_sides"), "the third reading closes it")


func test_branch_b_refusal_defers_and_the_make_good_rejoins() -> void:
	_journal.add_entry(&"woke_in_the_bait_square")
	_say(&"for_the_tallies", &"torrum")
	_say(&"refuse_the_square", &"torrum", true)  # the refusal is a choice press now (spec 013)
	assert_true(_journal.has_entry(&"refused_the_square"))
	assert_eq(_status(), QuestEvaluator.Status.COMPLETED, "refusal is a terminal stage")
	var early := _pick(&"take_the_cord", &"torrum")
	assert_eq(early.journal_entry, &"", "no join before the make-good")
	_journal.add_entry(&"the_moth_test")  # the make-good: standing for the cage
	_say(&"take_the_cord", &"torrum", true)  # the make-good join is a choice press (spec 015)
	assert_true(_journal.has_entry(&"joined_the_wardens"), "the deferred join lands")


# --- The cache chain ---


func test_cache_chain_completes_through_wester() -> void:
	assert_eq(QuestEvaluator.status(_cache, _journal), QuestEvaluator.Status.NOT_STARTED)
	_say(&"the_roofed_cache", &"wester")
	assert_true(_journal.has_entry(&"the_cache_rumor"))
	assert_eq(QuestEvaluator.status(_cache, _journal), QuestEvaluator.Status.ACTIVE)
	_journal.add_entry(&"found_the_roofed_cache")  # the route trigger
	_say(&"the_roofed_cache", &"wester", true)  # the share-line join is a choice press (spec 015)
	assert_true(_journal.has_entry(&"joined_the_licensed_crews"))
	assert_eq(QuestEvaluator.status(_cache, _journal), QuestEvaluator.Status.COMPLETED)


# --- Guild independence (criterion 5) ---


func test_each_join_still_offered_while_holding_the_other_two() -> void:
	# Wardens: holding the other two joins must not block the cord.
	_journal.add_entry(&"joined_the_reciters")
	_journal.add_entry(&"joined_the_licensed_crews")
	_journal.add_entry(&"stood_for_the_tallies")
	var cord := _pick(&"take_the_cord", &"torrum", true)  # the join commit (choice press, spec 015)
	assert_not_null(cord)
	assert_eq(cord.journal_entry, &"joined_the_wardens", "the wardens still take you")
	# Crews: holding reciters + wardens must not block the share.
	var crews_journal := Journal.new()
	crews_journal.add_entry(&"joined_the_reciters")
	crews_journal.add_entry(&"joined_the_wardens")
	crews_journal.add_entry(&"the_cache_rumor")
	crews_journal.add_entry(&"found_the_roofed_cache")
	var topics := DialogueLibrary.get_topics()
	var share := DialogueEvaluator.pick_response(
		topics[&"the_roofed_cache"], &"wester", crews_journal, _inventory, true
	)
	assert_not_null(share)
	assert_eq(share.journal_entry, &"joined_the_licensed_crews", "the crews still count you")


func test_no_response_blocks_on_another_guilds_join() -> void:
	# Data sweep: a response may gate on its OWN guild's join (freshness
	# variants) but never lists two different joins in blocked_by_journal.
	var joins: Array[StringName] = [
		&"joined_the_reciters", &"joined_the_wardens", &"joined_the_licensed_crews"
	]
	for topic_id: StringName in DialogueLibrary.get_topics():
		var topic: DialogueTopicDef = DialogueLibrary.get_topics()[topic_id]
		for response: DialogueResponse in topic.responses:
			var blocked_joins := 0
			for join: StringName in joins:
				if response.blocked_by_journal.has(join):
					blocked_joins += 1
			assert_lte(blocked_joins, 1, "%s blocks at most its own guild's join" % topic_id)
