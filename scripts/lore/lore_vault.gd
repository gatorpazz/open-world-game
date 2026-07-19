class_name LoreVault
extends RefCounted
## Loads every lore entry under a root (spec 011) and answers graph
## questions: reachability from the hub and inbound links. The walker skips
## `_`-prefixed directories (`_templates/`, `_examples/` are quarantined
## from validation), dot-directories (`.obsidian/`), and non-`.md` files.
## Parse failures and duplicate ids land in `errors` instead of `entries`.
## Pure RefCounted, no caching — the canon suite loads fresh per run.

var entries: Dictionary[StringName, LoreEntry] = {}
var errors: Array[String] = []


static func load_vault(root: String = "res://docs/lore") -> LoreVault:
	var vault := LoreVault.new()
	for file_path: String in collect_markdown_files(root):
		vault._absorb(LoreEntry.load_file(file_path))
	return vault


## Fixture path for unit tests — builds a vault from pre-parsed entries.
static func from_entries(list: Array[LoreEntry]) -> LoreVault:
	var vault := LoreVault.new()
	for entry: LoreEntry in list:
		vault._absorb(entry)
	return vault


## Every non-quarantined .md path under root, recursively.
static func collect_markdown_files(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".md"):
			found.append(root.path_join(file_name))
	for dir_name: String in dir.get_directories():
		if dir_name.begins_with("_") or dir_name.begins_with("."):
			continue
		found.append_array(collect_markdown_files(root.path_join(dir_name)))
	return found


## Ids reachable from `start` by BFS over body wikilinks, `start` included.
## Links to ids that are not in the vault are simply not followed — the
## canon suite reports those separately as dangling links.
func reachable_from(start: StringName) -> Dictionary[StringName, bool]:
	var visited: Dictionary[StringName, bool] = {}
	if not entries.has(start):
		return visited
	visited[start] = true
	var queue: Array[StringName] = [start]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for link: StringName in entries[current].body_links:
			if entries.has(link) and not visited.has(link):
				visited[link] = true
				queue.append(link)
	return visited


func inbound_links_to(target: StringName) -> Array[StringName]:
	var sources: Array[StringName] = []
	for id: StringName in entries:
		if entries[id].body_links.has(target):
			sources.append(id)
	return sources


func _absorb(entry: LoreEntry) -> void:
	if not entry.ok:
		errors.append("%s: %s" % [entry.path, entry.error])
		return
	if entries.has(entry.id):
		errors.append(
			"duplicate id '%s': %s and %s" % [entry.id, entries[entry.id].path, entry.path]
		)
		return
	entries[entry.id] = entry
