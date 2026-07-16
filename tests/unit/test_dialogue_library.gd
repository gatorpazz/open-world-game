extends GutTest
## Unit tests for DialogueLibrary (spec 005).


func before_each() -> void:
	DialogueLibrary.reset()


func after_all() -> void:
	DialogueLibrary.reset()


func test_loads_every_topic_keyed_by_id() -> void:
	var topics := DialogueLibrary.get_topics()
	var file_count := 0
	for file_name: String in ResourceLoader.list_directory(DialogueLibrary.DIR):
		if file_name.ends_with(".tres"):
			file_count += 1
	assert_eq(topics.size(), file_count, "one entry per data file")
	assert_true(topics.has(DialogueTopicDef.GREETING_ID), "the greeting topic is loaded")
	for topic_id: StringName in topics:
		assert_eq(topics[topic_id].id, topic_id, "keyed by the topic's own id")


func test_caches_between_calls_and_reset_clears() -> void:
	var first := DialogueLibrary.get_topics()
	assert_same(first, DialogueLibrary.get_topics(), "second call returns the cache")
	DialogueLibrary.reset()
	assert_eq(first.size(), 0, "reset clears the shared dictionary")
