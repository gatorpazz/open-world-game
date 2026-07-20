extends GutTest
## Unit tests for the Journal resource (spec 005, acceptance criterion 2).

var _journal: Journal


func before_each() -> void:
	_journal = Journal.new()


# --- entries ---


func test_entries_preserve_insertion_order() -> void:
	_journal.add_entry(&"second_thing")
	_journal.add_entry(&"first_thing")
	assert_eq(_journal.entries, [&"second_thing", &"first_thing"] as Array[StringName])


func test_add_entry_is_idempotent() -> void:
	assert_true(_journal.add_entry(&"a_thing"))
	assert_false(_journal.add_entry(&"a_thing"), "duplicate add returns false")
	assert_eq(_journal.entries.size(), 1, "duplicate add does not mutate")


func test_has_entry() -> void:
	assert_false(_journal.has_entry(&"a_thing"))
	_journal.add_entry(&"a_thing")
	assert_true(_journal.has_entry(&"a_thing"))


# --- known topics ---


func test_known_topics_preserve_discovery_order() -> void:
	_journal.learn_topic(&"scar_hounds")
	_journal.learn_topic(&"lastdoor")
	assert_eq(_journal.known_topics, [&"scar_hounds", &"lastdoor"] as Array[StringName])


func test_learn_topic_is_idempotent() -> void:
	assert_true(_journal.learn_topic(&"lastdoor"))
	assert_false(_journal.learn_topic(&"lastdoor"), "duplicate learn returns false")
	assert_eq(_journal.known_topics.size(), 1, "duplicate learn does not mutate")


func test_knows_topic() -> void:
	assert_false(_journal.knows_topic(&"lastdoor"))
	_journal.learn_topic(&"lastdoor")
	assert_true(_journal.knows_topic(&"lastdoor"))


# --- serialization readiness (guards spec 007, the Inventory pattern) ---


func test_duplicate_round_trips_state() -> void:
	_journal.add_entry(&"a_thing")
	_journal.learn_topic(&"lastdoor")
	var copy := _journal.duplicate(true) as Journal
	assert_eq(copy.entries, _journal.entries)
	assert_eq(copy.known_topics, _journal.known_topics)
	copy.add_entry(&"another_thing")
	assert_false(_journal.has_entry(&"another_thing"), "the copy is independent")
