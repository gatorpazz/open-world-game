extends GutTest
## Unit tests for DialogueMarkup (spec 005, acceptance criterion 1).

const NO_NAMES: Dictionary[StringName, String] = {}

# --- extract_topic_ids ---


func test_extracts_plain_markup() -> void:
	var ids := DialogueMarkup.extract_topic_ids("Ask about [[lastdoor]] sometime.")
	assert_eq(ids, [&"lastdoor"] as Array[StringName])


func test_extracts_labeled_markup() -> void:
	var ids := DialogueMarkup.extract_topic_ids("The [[scar_hounds|hounds]] howl at night.")
	assert_eq(ids, [&"scar_hounds"] as Array[StringName])


func test_extracts_multiple_in_order_deduplicated() -> void:
	var text := "[[lastdoor]] and [[scar_hounds]] and [[lastdoor]] again."
	var ids := DialogueMarkup.extract_topic_ids(text)
	assert_eq(ids, [&"lastdoor", &"scar_hounds"] as Array[StringName])


func test_ignores_non_markup_brackets() -> void:
	assert_eq(DialogueMarkup.extract_topic_ids("plain text").size(), 0)
	assert_eq(DialogueMarkup.extract_topic_ids("a [bracket] and [[Bad Id]] here").size(), 0)
	assert_eq(DialogueMarkup.extract_topic_ids("stray [[unclosed").size(), 0)


# --- to_bbcode ---


func test_renders_display_name_for_plain_markup() -> void:
	var names: Dictionary[StringName, String] = {&"lastdoor": "Lastdoor"}
	var bbcode := DialogueMarkup.to_bbcode("Ask about [[lastdoor]].", names)
	var expected := (
		"Ask about [url=lastdoor][color=%s]Lastdoor[/color][/url]."
		% (DialogueMarkup.KEYWORD_COLOR)
	)
	assert_eq(bbcode, expected)


func test_renders_custom_label_over_display_name() -> void:
	var names: Dictionary[StringName, String] = {&"scar_hounds": "Scar-Hounds"}
	var bbcode := DialogueMarkup.to_bbcode("Those [[scar_hounds|hounds]] again.", names)
	assert_string_contains(bbcode, "[url=scar_hounds]")
	assert_string_contains(bbcode, "]hounds[/color]")
	assert_false(bbcode.contains("Scar-Hounds"))


func test_falls_back_to_raw_id_when_display_name_unknown() -> void:
	var bbcode := DialogueMarkup.to_bbcode("About [[mystery_topic]].", NO_NAMES)
	assert_string_contains(bbcode, "]mystery_topic[/color]")


func test_text_without_markup_passes_through_unchanged() -> void:
	var text := "No keywords here, just [brackets] and words."
	assert_eq(DialogueMarkup.to_bbcode(text, NO_NAMES), text)


func test_renders_multiple_keywords_preserving_surrounding_text() -> void:
	var names: Dictionary[StringName, String] = {&"a_topic": "A Topic", &"b_topic": "B Topic"}
	var bbcode := DialogueMarkup.to_bbcode("First [[a_topic]], then [[b_topic]]!", names)
	assert_string_starts_with(bbcode, "First [url=a_topic]")
	assert_string_contains(bbcode, ", then [url=b_topic]")
	assert_string_ends_with(bbcode, "[/url]!")
