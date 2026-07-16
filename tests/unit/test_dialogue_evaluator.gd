extends GutTest
## Unit tests for DialogueEvaluator (spec 005, acceptance criteria 3-5).
## Topics are built in code — data files have their own validator.

var _journal: Journal
var _inventory: Inventory
var _pelt: ItemDef


func before_each() -> void:
	_journal = Journal.new()
	_inventory = Inventory.new()
	_pelt = ItemDef.new()
	_pelt.id = &"test_pelt"
	_pelt.display_name = "Test Pelt"


func _response(text: String, npc_id: StringName = &"") -> DialogueResponse:
	var response := DialogueResponse.new()
	response.text = text
	response.npc_id = npc_id
	return response


func _topic(id: StringName, responses: Array[DialogueResponse]) -> DialogueTopicDef:
	var topic := DialogueTopicDef.new()
	topic.id = id
	topic.display_name = String(id).capitalize()
	topic.responses = responses
	return topic


func _stack(item: ItemDef, count: int) -> ItemStack:
	var stack := ItemStack.new()
	stack.item = item
	stack.count = count
	return stack


func _pick(topic: DialogueTopicDef, npc_id: StringName) -> DialogueResponse:
	return DialogueEvaluator.pick_response(topic, npc_id, _journal, _inventory)


# --- pick_response / matches (criterion 3) ---


func test_npc_specific_response_beats_later_fallback() -> void:
	var specific := _response("For your ears only.", &"hunald")
	var fallback := _response("The usual line.")
	var topic := _topic(&"gossip", [specific, fallback])
	assert_same(_pick(topic, &"hunald"), specific)


func test_fallback_serves_other_npcs() -> void:
	var specific := _response("For your ears only.", &"hunald")
	var fallback := _response("The usual line.")
	var topic := _topic(&"gossip", [specific, fallback])
	assert_same(_pick(topic, &"seld"), fallback)


func test_requires_topics_gates_until_known() -> void:
	var gated := _response("Now that you know of it...")
	gated.requires_topics = [&"the_secret"] as Array[StringName]
	var topic := _topic(&"gossip", [gated])
	assert_null(_pick(topic, &"hunald"))
	_journal.learn_topic(&"the_secret")
	assert_same(_pick(topic, &"hunald"), gated)


func test_requires_journal_gates_until_held() -> void:
	var gated := _response("Your journal says so.")
	gated.requires_journal = [&"a_deed"] as Array[StringName]
	var topic := _topic(&"gossip", [gated])
	assert_null(_pick(topic, &"hunald"))
	_journal.add_entry(&"a_deed")
	assert_same(_pick(topic, &"hunald"), gated)


func test_take_items_gates_until_inventory_holds_them() -> void:
	var exchange := _response("Hand it over, then.")
	exchange.take_items = [_stack(_pelt, 2)] as Array[ItemStack]
	var topic := _topic(&"trade", [exchange])
	assert_null(_pick(topic, &"seld"))
	_inventory.add_item(_pelt, 1)
	assert_null(_pick(topic, &"seld"), "one pelt of two required is not enough")
	_inventory.add_item(_pelt, 1)
	assert_same(_pick(topic, &"seld"), exchange)


func test_take_items_counts_equipped_copies() -> void:
	var sword := load("res://data/items/iron_sword.tres") as ItemDef
	var exchange := _response("That blade will do.")
	exchange.take_items = [_stack(sword, 1)] as Array[ItemStack]
	var topic := _topic(&"trade", [exchange])
	_inventory.add_item(sword, 1)
	_inventory.equip(sword)
	assert_eq(_inventory.count_of(sword), 0, "the only copy is equipped, not loose")
	assert_same(_pick(topic, &"seld"), exchange)


func test_null_when_nothing_matches() -> void:
	var topic := _topic(&"gossip", [_response("For your ears only.", &"hunald")])
	assert_null(_pick(topic, &"seld"))


func test_first_match_wins_on_order() -> void:
	var first := _response("First answer.")
	var second := _response("Second answer.")
	var topic := _topic(&"gossip", [first, second])
	assert_same(_pick(topic, &"hunald"), first)


# --- available_topics (criterion 4) ---


func test_available_topics_is_known_and_answerable_in_discovery_order() -> void:
	var topics: Dictionary[StringName, DialogueTopicDef] = {
		&"for_anyone": _topic(&"for_anyone", [_response("Sure.")]),
		&"hunald_only": _topic(&"hunald_only", [_response("Only I know.", &"hunald")]),
		&"unknown": _topic(&"unknown", [_response("Never learned.")]),
	}
	_journal.learn_topic(&"hunald_only")
	_journal.learn_topic(&"for_anyone")
	var for_hunald := DialogueEvaluator.available_topics(topics, &"hunald", _journal, _inventory)
	assert_eq(for_hunald, [topics[&"hunald_only"], topics[&"for_anyone"]])
	var for_seld := DialogueEvaluator.available_topics(topics, &"seld", _journal, _inventory)
	assert_eq(for_seld, [topics[&"for_anyone"]], "seld cannot answer hunald_only")


func test_greeting_is_never_listed() -> void:
	var topics: Dictionary[StringName, DialogueTopicDef] = {
		DialogueTopicDef.GREETING_ID: _topic(DialogueTopicDef.GREETING_ID, [_response("Hello.")]),
	}
	_journal.learn_topic(DialogueTopicDef.GREETING_ID)
	assert_eq(DialogueEvaluator.available_topics(topics, &"hunald", _journal, _inventory).size(), 0)


func test_topic_appears_only_after_its_keyword_was_displayed() -> void:
	var topics: Dictionary[StringName, DialogueTopicDef] = {
		&"rumor": _topic(&"rumor", [_response("Heard about [[rumor]]? Now you have.")]),
	}
	assert_eq(DialogueEvaluator.available_topics(topics, &"seld", _journal, _inventory).size(), 0)
	DialogueEvaluator.apply_effects(topics[&"rumor"].responses[0], _journal)
	var available := DialogueEvaluator.available_topics(topics, &"seld", _journal, _inventory)
	assert_eq(available, [topics[&"rumor"]], "displaying the keyword at one NPC unlocks it at all")


# --- apply_effects (criterion 5) ---


func test_apply_effects_learns_exactly_the_marked_topics() -> void:
	var response := _response("Talk of [[topic_a]] and [[topic_b|that other thing]].")
	var report := DialogueEvaluator.apply_effects(response, _journal)
	assert_eq(_journal.known_topics, [&"topic_a", &"topic_b"] as Array[StringName])
	assert_eq(report.new_topics, [&"topic_a", &"topic_b"] as Array[StringName])


func test_apply_effects_reports_only_new_learns() -> void:
	_journal.learn_topic(&"topic_a")
	var response := _response("About [[topic_a]] and [[topic_b]].")
	var report := DialogueEvaluator.apply_effects(response, _journal)
	assert_eq(report.new_topics, [&"topic_b"] as Array[StringName])
	assert_eq(_journal.known_topics.size(), 2)


func test_apply_effects_adds_journal_entry_once_across_repeats() -> void:
	var response := _response("Something happened.")
	response.journal_entry = &"a_deed"
	var first := DialogueEvaluator.apply_effects(response, _journal)
	assert_eq(first.journal_entry_added, &"a_deed")
	var second := DialogueEvaluator.apply_effects(response, _journal)
	assert_eq(second.journal_entry_added, &"", "repeat adds nothing and reports nothing")
	assert_eq(_journal.entries, [&"a_deed"] as Array[StringName])

# Item effects (take_items/give_items) are deliberately NOT applied by
# DialogueEvaluator — DialoguePanel routes them through InventoryComponent
# so the player-side signals fire. Covered in tests/scenes/test_npc_dialogue.gd.
