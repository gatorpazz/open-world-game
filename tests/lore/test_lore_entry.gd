extends GutTest
## Entry-model tests for LoreEntry (spec 011, criterion 3): id from stem,
## fence-aware section splitting, link extraction via DialogueMarkup.

const PATH := "res://docs/lore/locations/test_entry.md"

const FRONT := "---\ntitle: Test Entry\ntype: location\nstatus: draft\nregion: world\n---\n"


func _entry(body: String) -> LoreEntry:
	return LoreEntry.from_string(PATH, FRONT + body)


func test_id_from_stem_and_typed_fields() -> void:
	var entry := _entry("## Function\nA place.")
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_eq(entry.id, &"test_entry", "id is the filename stem")
	assert_eq(entry.path, PATH)
	assert_eq(entry.type, &"location")
	assert_eq(entry.status, &"draft")


func test_parse_failure_surfaces_error() -> void:
	var entry := LoreEntry.from_string(PATH, "---\nbad key here\n---\n")
	assert_false(entry.ok, "frontmatter failure fails the entry")
	assert_true(entry.error.begins_with("line 2:"), "error carries the line: %s" % entry.error)
	assert_eq(entry.id, &"test_entry", "id still derived for error reporting")


func test_load_file_missing_reports_not_found() -> void:
	var entry := LoreEntry.load_file("res://docs/lore/locations/does_not_exist.md")
	assert_false(entry.ok, "missing file fails")
	assert_true(entry.error.contains("file not found"), "error names the cause: %s" % entry.error)


func test_sections_split_in_document_order_with_preamble() -> void:
	var entry := _entry(
		(
			"Some preamble text.\n\n## Function\nWhy it exists.\n\n"
			+ "## Canon summary\nThe facts.\n\n## Open questions\n- one\n"
		)
	)
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_eq(entry.preamble, "Some preamble text.")
	assert_eq(
		entry.sections.keys(),
		["Function", "Canon summary", "Open questions"],
		"keys keep document order"
	)
	assert_eq(entry.sections["Function"], "Why it exists.")
	assert_eq(entry.sections["Canon summary"], "The facts.")
	assert_eq(entry.sections["Open questions"], "- one")


func test_fenced_heading_does_not_split_sections() -> void:
	var entry := _entry(
		"## Speech & register\nSigns read:\n```\n## Trap\nnot a heading\n```\nAfter."
	)
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_false(entry.sections.has("Trap"), "fenced ## line is content, not a heading")
	assert_true(
		entry.sections["Speech & register"].contains("not a heading"),
		"fence content stays in its owning section"
	)
	assert_true(entry.sections["Speech & register"].contains("After."))


func test_empty_heading_is_content_not_a_section_break() -> void:
	var entry := _entry("## Function\ntext before\n## \ntext after")
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_eq(entry.sections.keys(), ["Function"], "no empty-string section key")
	assert_true(
		entry.sections["Function"].contains("text after"),
		"lines after a malformed heading stay in the current section"
	)


func test_links_plain_pipe_dedup_in_first_appearance_order() -> void:
	var entry := _entry(
		(
			"## Canon summary\nSee [[salt_tribunal]] and "
			+ "[[second_drowning|the Second Drowning]], then [[salt_tribunal]] again."
		)
	)
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_eq(
		entry.body_links,
		[&"salt_tribunal", &"second_drowning"] as Array[StringName],
		"plain + pipe forms, deduplicated, in first-appearance order"
	)


func test_links_ignore_fences_and_inline_code() -> void:
	var entry := _entry(
		(
			"## Canon summary\nReal link: [[real_place]].\n```\nquoted dialogue "
			+ "with [[fenced_id]]\n```\nInline `[[coded_id]]` stays code."
		)
	)
	assert_true(entry.ok, "parses: %s" % entry.error)
	assert_eq(entry.body_links, [&"real_place"] as Array[StringName])
	assert_false(entry.stripped_body.contains("fenced_id"), "fence content stripped")
	assert_false(entry.stripped_body.contains("coded_id"), "inline code stripped")
	assert_true(entry.stripped_body.contains("[[real_place]]"), "real markup survives stripping")
