class_name LoreEntry
extends RefCounted
## One parsed lore-vault entry (spec 011): frontmatter, the body split into
## `## ` sections, and the wikilink ids the body carries. The filename stem
## IS the id — frontmatter has no id field. Section splitting ignores `## `
## lines inside fenced code blocks, and link extraction ignores fenced
## blocks and inline `code` spans (quoted examples must never create graph
## edges). Link syntax is 005's exactly — see DialogueMarkup, reused here
## rather than copied so the two regexes cannot drift.
## Pure RefCounted — fixture-testable via from_string, no scene tree.

const INLINE_CODE_PATTERN := "`[^`\\n]*`"

static var _inline_code_regex := RegEx.create_from_string(INLINE_CODE_PATTERN)

var ok := false
var error := ""
var id: StringName = &""
var path := ""
var type: StringName = &""
var status: StringName = &""
var frontmatter: LoreFrontmatter = null
var preamble := ""
var sections: Dictionary[String, String] = {}
var body_links: Array[StringName] = []
var stripped_body := ""


## Builds an entry from raw file text; `file_path` supplies the id (stem)
## and never has to exist on disk — the fixture path for unit tests.
static func from_string(file_path: String, text: String) -> LoreEntry:
	var entry := LoreEntry.new()
	entry.path = file_path
	entry.id = StringName(file_path.get_file().get_basename())
	entry.frontmatter = LoreFrontmatter.parse(text)
	if not entry.frontmatter.ok:
		entry.error = entry.frontmatter.error
		return entry
	entry.ok = true
	entry.type = StringName(entry.frontmatter.get_scalar("type"))
	entry.status = StringName(entry.frontmatter.get_scalar("status"))
	entry._split_sections()
	entry._extract_links()
	return entry


static func load_file(file_path: String) -> LoreEntry:
	if not FileAccess.file_exists(file_path):
		var entry := LoreEntry.new()
		entry.path = file_path
		entry.id = StringName(file_path.get_file().get_basename())
		entry.error = "file not found: %s" % file_path
		return entry
	return from_string(file_path, FileAccess.get_file_as_string(file_path))


## Splits the body on `## ` headings (outside code fences). Text before the
## first heading lands in `preamble`; section text is edge-trimmed; keys keep
## first-appearance order (Dictionary preserves insertion order). A malformed
## empty heading (`## ` with no title) is treated as content, and duplicate
## headings merge into the first occurrence — both deliberate: this model
## feeds validators, so mis-routing must be impossible, and the canon suite
## checks presence and order, not multiplicity.
func _split_sections() -> void:
	var current := ""
	var in_fence := false
	var chunks: Dictionary[String, PackedStringArray] = {}
	var preamble_lines := PackedStringArray()
	for line: String in frontmatter.body.split("\n"):
		var heading := line.substr(3).strip_edges() if line.begins_with("## ") else ""
		if line.strip_edges().begins_with("```"):
			in_fence = not in_fence
		elif not in_fence and not heading.is_empty():
			current = heading
			if not chunks.has(current):
				chunks[current] = PackedStringArray()
			continue
		if current.is_empty():
			preamble_lines.append(line)
		else:
			chunks[current].append(line)
	preamble = "\n".join(preamble_lines).strip_edges()
	for key: String in chunks:
		sections[key] = "\n".join(chunks[key]).strip_edges()


## Drops fenced blocks and inline code spans, then extracts wikilink ids.
## The stripped text is kept for the canon suite's stray-markup check.
func _extract_links() -> void:
	var kept := PackedStringArray()
	var in_fence := false
	for line: String in frontmatter.body.split("\n"):
		if line.strip_edges().begins_with("```"):
			in_fence = not in_fence
			continue
		if not in_fence:
			kept.append(line)
	stripped_body = _inline_code_regex.sub("\n".join(kept), "", true)
	body_links = DialogueMarkup.extract_topic_ids(stripped_body)
