extends GutTest
## Unit tests for DialogueMarkup (spec 005, acceptance criterion 1).

# --- extract_topic_ids ---


func test_extracts_plain_markup() -> void:
	var ids := DialogueMarkup.extract_topic_ids("Ask about [[the_village]] sometime.")
	assert_eq(ids, [&"the_village"] as Array[StringName])


func test_extracts_labeled_markup() -> void:
	var ids := DialogueMarkup.extract_topic_ids("The [[bog_hounds|hounds]] howl at night.")
	assert_eq(ids, [&"bog_hounds"] as Array[StringName])


func test_extracts_multiple_in_order_deduplicated() -> void:
	var text := "[[the_village]] and [[bog_hounds]] and [[the_village]] again."
	var ids := DialogueMarkup.extract_topic_ids(text)
	assert_eq(ids, [&"the_village", &"bog_hounds"] as Array[StringName])


func test_ignores_non_markup_brackets() -> void:
	assert_eq(DialogueMarkup.extract_topic_ids("plain text").size(), 0)
	assert_eq(DialogueMarkup.extract_topic_ids("a [bracket] and [[Bad Id]] here").size(), 0)
	assert_eq(DialogueMarkup.extract_topic_ids("stray [[unclosed").size(), 0)


# --- to_bbcode ---


func test_renders_display_name_for_plain_markup() -> void:
	var names := {&"the_village": "The Village"}
	var bbcode := DialogueMarkup.to_bbcode("Ask about [[the_village]].", names)
	var expected := (
		"Ask about [url=the_village][color=%s]The Village[/color][/url]."
		% (DialogueMarkup.KEYWORD_COLOR)
	)
	assert_eq(bbcode, expected)


func test_renders_custom_label_over_display_name() -> void:
	var names := {&"bog_hounds": "Bog Hounds"}
	var bbcode := DialogueMarkup.to_bbcode("Those [[bog_hounds|hounds]] again.", names)
	assert_string_contains(bbcode, "[url=bog_hounds]")
	assert_string_contains(bbcode, "]hounds[/color]")
	assert_false(bbcode.contains("Bog Hounds"))


func test_falls_back_to_raw_id_when_display_name_unknown() -> void:
	var bbcode := DialogueMarkup.to_bbcode("About [[mystery_topic]].", {})
	assert_string_contains(bbcode, "]mystery_topic[/color]")


func test_text_without_markup_passes_through_unchanged() -> void:
	var text := "No keywords here, just [brackets] and words."
	assert_eq(DialogueMarkup.to_bbcode(text, {}), text)


func test_renders_multiple_keywords_preserving_surrounding_text() -> void:
	var names := {&"a_topic": "A Topic", &"b_topic": "B Topic"}
	var bbcode := DialogueMarkup.to_bbcode("First [[a_topic]], then [[b_topic]]!", names)
	assert_string_starts_with(bbcode, "First [url=a_topic]")
	assert_string_contains(bbcode, ", then [url=b_topic]")
	assert_string_ends_with(bbcode, "[/url]!")
