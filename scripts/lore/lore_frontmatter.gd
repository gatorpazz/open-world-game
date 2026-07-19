class_name LoreFrontmatter
extends RefCounted
## Strict-subset YAML frontmatter parser for the lore vault (spec 011).
## Line 1 is exactly "---"; frontmatter ends at the next "---"; between the
## fences each non-blank line is `key: value` (a scalar) or `key:` alone
## (opening a string list of `  - item` lines). Everything else is rejected
## with a line number. Double-quoting a value exempts its content from the
## structural rejections (the escape hatch for literals). The parser knows
## grammar only — the canon suite in tests/lore/ owns the schema.
## Files are LF-only: a CRLF file fails at line 1 by design.
## Static and pure — no scene-tree dependencies.

const KEY_PATTERN := "^[a-z_][a-z0-9_]*$"

static var _key_regex := RegEx.create_from_string(KEY_PATTERN)

var ok := false
var error := ""
var error_line := 0
var scalars: Dictionary[String, String] = {}
var lists: Dictionary[String, PackedStringArray] = {}
var body := ""


## Parses a whole file's text. On failure, `ok` is false and `error` /
## `error_line` say what and where; on success, `body` holds everything
## after the closing fence, byte for byte.
static func parse(source: String) -> LoreFrontmatter:
	var result := LoreFrontmatter.new()
	var lines := source.split("\n")
	if lines.is_empty() or lines[0] != "---":
		return _fail(result, 1, "expected opening --- on line 1")
	var open_list := ""
	var index := 1
	while index < lines.size():
		var line: String = lines[index]
		var line_number := index + 1
		if line == "---":
			result.body = "\n".join(lines.slice(index + 1))
			result.ok = true
			return result
		if line.contains("\t"):
			return _fail(result, line_number, "tabs are not allowed")
		if line.strip_edges().is_empty():
			index += 1
			continue
		if line.strip_edges().begins_with("#"):
			return _fail(result, line_number, "comments are not allowed")
		if line.begins_with("  - "):
			if open_list.is_empty():
				return _fail(result, line_number, "list item without an open list")
			var item := line.substr(4).strip_edges()
			if item.begins_with('"'):
				if item.length() < 2 or not item.ends_with('"'):
					return _fail(result, line_number, "unterminated quote")
				item = item.substr(1, item.length() - 2)
			if item.is_empty():
				return _fail(result, line_number, "empty list item")
			result.lists[open_list].append(item)
			index += 1
			continue
		if line.begins_with(" "):
			return _fail(result, line_number, "unexpected indentation (nesting is not allowed)")
		var colon := line.find(": ")
		if colon == -1 and line.ends_with(":"):
			var key := line.substr(0, line.length() - 1)
			if not _claim_key(result, key, line_number):
				return result
			result.lists[key] = PackedStringArray()
			open_list = key
		elif colon != -1:
			var key := line.substr(0, colon)
			if not _claim_key(result, key, line_number):
				return result
			open_list = ""
			var raw := line.substr(colon + 2).strip_edges()
			if raw.is_empty():
				return _fail(result, line_number, "empty scalar value")
			if raw.begins_with('"'):
				if raw.length() < 2 or not raw.ends_with('"'):
					return _fail(result, line_number, "unterminated quote")
				raw = raw.substr(1, raw.length() - 2)
				if raw.is_empty():
					return _fail(result, line_number, "empty scalar value")
			elif raw.begins_with("[") or raw.begins_with("{"):
				return _fail(result, line_number, "inline collections are not allowed")
			elif raw.begins_with("|") or raw.begins_with(">"):
				return _fail(result, line_number, "multiline scalars are not allowed")
			result.scalars[key] = raw
		else:
			return _fail(result, line_number, "not a valid frontmatter line")
		index += 1
	return _fail(result, lines.size(), "missing closing ---")


func get_scalar(key: String, default_value: String = "") -> String:
	if scalars.has(key):
		return scalars[key]
	return default_value


func get_list(key: String) -> PackedStringArray:
	if lists.has(key):
		return lists[key]
	return PackedStringArray()


## Validates and reserves a key; on failure sets the error and returns false.
static func _claim_key(result: LoreFrontmatter, key: String, line_number: int) -> bool:
	if _key_regex.search(key) == null:
		_fail(result, line_number, "invalid key '%s'" % key)
		return false
	if result.scalars.has(key) or result.lists.has(key):
		_fail(result, line_number, "duplicate key '%s'" % key)
		return false
	return true


static func _fail(result: LoreFrontmatter, line_number: int, message: String) -> LoreFrontmatter:
	result.ok = false
	result.error = "line %d: %s" % [line_number, message]
	result.error_line = line_number
	return result
