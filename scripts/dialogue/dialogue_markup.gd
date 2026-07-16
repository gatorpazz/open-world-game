class_name DialogueMarkup
extends RefCounted
## Parses the inline [[topic_id]] keyword markup in dialogue text (spec 005).
## Markup is the one unlock mechanism: displaying a response learns every
## marked topic. [[id]] renders the topic's display name; [[id|shown text]]
## renders custom text. Static and pure — no scene-tree dependencies.

## Matches [[topic_id]] and [[topic_id|shown text]].
const MARKUP_PATTERN := "\\[\\[([a-z0-9_]+)(?:\\|([^\\]|]+))?\\]\\]"

## Keyword highlight color (UI styling, not balance — see spec 005).
const KEYWORD_COLOR := "#7ec8e3"

static var _regex := RegEx.create_from_string(MARKUP_PATTERN)


## Every topic id marked in the text, in order of first appearance,
## deduplicated. Unparseable bracket text is ignored (validators reject it
## in data files; at runtime it just isn't a keyword).
static func extract_topic_ids(text: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for found: RegExMatch in _regex.search_all(text):
		var id := StringName(found.get_string(1))
		if not ids.has(id):
			ids.append(id)
	return ids


## Converts markup to BBCode for a RichTextLabel with meta_clicked: each
## keyword becomes [url=id]-wrapped highlighted text. The label is the
## custom |text if present, else the topic's display name from the lookup,
## else the raw id. Text without markup passes through unchanged.
static func to_bbcode(text: String, display_names: Dictionary[StringName, String]) -> String:
	var result := ""
	var cursor := 0
	for found: RegExMatch in _regex.search_all(text):
		result += text.substr(cursor, found.get_start() - cursor)
		var id := StringName(found.get_string(1))
		var label := found.get_string(2)
		if label.is_empty():
			label = display_names.get(id, String(id))
		result += "[url=%s][color=%s]%s[/color][/url]" % [id, KEYWORD_COLOR, label]
		cursor = found.get_end()
	return result + text.substr(cursor)
