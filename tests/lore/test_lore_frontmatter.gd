extends GutTest
## Grammar accept/reject tests for LoreFrontmatter (spec 011, criteria 1-2).
## All fixtures are inline strings — no filesystem involved.


func _src(front_lines: Array[String], body: String = "") -> String:
	var lines: Array[String] = ["---"]
	lines.append_array(front_lines)
	lines.append("---")
	var text := "\n".join(lines)
	if not body.is_empty():
		text += "\n" + body
	return text


func _assert_rejects(source: String, expected_line: int, context: String) -> void:
	var fm := LoreFrontmatter.parse(source)
	assert_false(fm.ok, "%s: is rejected" % context)
	assert_eq(fm.error_line, expected_line, "%s: error line" % context)
	assert_true(
		fm.error.begins_with("line %d:" % expected_line),
		"%s: error text carries the line number (%s)" % [context, fm.error]
	)


func test_accepts_scalars_lists_blanks_and_quotes() -> void:
	var fm := (
		LoreFrontmatter
		. parse(
			_src(
				[
					"title: The Sunken Weir",
					"",
					"type: location",
					'pitch: "A levee-town: quoted, [with] punctuation."',
					"tags:",
					"  - example",
					'  - "quoted item"',
					"surface:",
				],
				"## Function\nBody text."
			)
		)
	)
	assert_true(fm.ok, "parses: %s" % fm.error)
	assert_eq(fm.get_scalar("title"), "The Sunken Weir")
	assert_eq(fm.get_scalar("type"), "location")
	assert_eq(fm.get_scalar("pitch"), "A levee-town: quoted, [with] punctuation.")
	assert_eq(fm.get_list("tags"), PackedStringArray(["example", "quoted item"]))
	assert_eq(fm.get_list("surface"), PackedStringArray(), "empty list is legal")
	assert_eq(fm.body, "## Function\nBody text.")


func test_scalar_value_may_contain_colons_and_hashes() -> void:
	var fm := LoreFrontmatter.parse(_src(["title: one: two # not a comment"]))
	assert_true(fm.ok, "parses: %s" % fm.error)
	assert_eq(fm.get_scalar("title"), "one: two # not a comment")


func test_body_preserved_byte_for_byte() -> void:
	var body := "para one\n\n---\n\na later --- is body, not a fence\n"
	var fm := LoreFrontmatter.parse("---\ntitle: x\n---\n" + body)
	assert_true(fm.ok, "parses: %s" % fm.error)
	assert_eq(fm.body, body)


func test_empty_body_and_getter_defaults() -> void:
	var fm := LoreFrontmatter.parse("---\ntitle: x\n---")
	assert_true(fm.ok, "parses: %s" % fm.error)
	assert_eq(fm.body, "")
	assert_eq(fm.get_scalar("missing"), "")
	assert_eq(fm.get_scalar("missing", "fallback"), "fallback")
	assert_eq(fm.get_list("missing"), PackedStringArray())


func test_rejects_missing_fences() -> void:
	_assert_rejects("title: x\n---", 1, "no opening fence")
	_assert_rejects("", 1, "empty source")
	_assert_rejects("---\ntitle: x", 2, "missing closing fence")
	_assert_rejects("---", 1, "fence only")


func test_rejects_tabs() -> void:
	_assert_rejects("---\n\ttitle: x\n---", 2, "leading tab")
	_assert_rejects("---\ntitle:\tx\n---", 2, "embedded tab")


func test_rejects_duplicate_keys() -> void:
	_assert_rejects(_src(["title: a", "title: b"]), 3, "scalar then scalar")
	_assert_rejects(_src(["tags:", "  - a", "tags: b"]), 4, "list then scalar")
	_assert_rejects(_src(["title: a", "title:"]), 3, "scalar then list opener")


func test_rejects_comments() -> void:
	_assert_rejects(_src(["# a comment"]), 2, "full-line comment")
	_assert_rejects(_src(["tags:", "  # indented comment"]), 3, "indented comment")


func test_rejects_nesting_and_stray_indentation() -> void:
	_assert_rejects(_src(["parent:", "  child: x"]), 3, "nested map")
	_assert_rejects(_src(["tags:", "    - deep item"]), 3, "over-indented list item")
	_assert_rejects(_src([" title: x"]), 2, "leading space on a scalar")


func test_rejects_inline_collections_and_multiline_scalars() -> void:
	_assert_rejects(_src(["tags: [a, b]"]), 2, "inline array")
	_assert_rejects(_src(["extra: {a: 1}"]), 2, "inline map")
	_assert_rejects(_src(["text: |"]), 2, "literal block scalar")
	_assert_rejects(_src(["text: >"]), 2, "folded block scalar")


func test_rejects_empty_and_unterminated_values() -> void:
	_assert_rejects(_src(["title:  "]), 2, "empty scalar value")
	_assert_rejects(_src(['title: ""']), 2, "empty quoted scalar")
	_assert_rejects(_src(['title: "unterminated']), 2, "unterminated quote")
	_assert_rejects(_src(["tags:", '  - "unterminated']), 3, "unterminated quoted list item")
	_assert_rejects(_src(["tags:", "  - "]), 3, "empty list item")
	_assert_rejects(_src(["tags:", '  - ""']), 3, "empty quoted list item")


func test_rejects_bad_keys() -> void:
	_assert_rejects(_src(["Title: x"]), 2, "uppercase key")
	_assert_rejects(_src(["9lives: x"]), 2, "leading digit")
	_assert_rejects(_src(["bad-key: x"]), 2, "hyphenated key")
	_assert_rejects(_src(["BAD_KEY:"]), 2, "uppercase list opener")


func test_rejects_orphan_list_items() -> void:
	_assert_rejects(_src(["  - orphan"]), 2, "item with no opener")
	_assert_rejects(_src(["tags:", "  - a", "title: x", "  - b"]), 5, "item after scalar reset")


func test_quoted_values_bypass_structural_rejections() -> void:
	var fm := (
		LoreFrontmatter
		. parse(
			_src(
				[
					'pitch: "[a, b] as a literal"',
					'note: "| pipe start"',
					"tags:",
					'  - "{braced item}"',
				]
			)
		)
	)
	assert_true(fm.ok, "quoting is the escape hatch: %s" % fm.error)
	assert_eq(fm.get_scalar("pitch"), "[a, b] as a literal")
	assert_eq(fm.get_scalar("note"), "| pipe start")
	assert_eq(fm.get_list("tags"), PackedStringArray(["{braced item}"]))


func test_rejects_lines_matching_neither_form() -> void:
	_assert_rejects(_src(["just words"]), 2, "bare words")
	_assert_rejects(_src(["key:value"]), 2, "colon without space")
