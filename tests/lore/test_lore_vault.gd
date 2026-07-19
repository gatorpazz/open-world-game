extends GutTest
## Vault tests for LoreVault (spec 011, criterion 4): graph build, duplicate
## ids, BFS reachability, inbound query, and the walker's quarantine rule
## (proved against a real tree in user:// compared with a raw listing).

const WALKER_ROOT := "user://lore_vault_walker_test"

const ENTRY_TEXT := (
	"---\ntitle: T\ntype: location\nstatus: draft\nregion: world\n---\n" + "## Function\nx\n"
)


func _fx(id: String, body: String) -> LoreEntry:
	var path := "res://docs/lore/locations/%s.md" % id
	var front := "---\ntitle: T\ntype: location\nstatus: draft\nregion: world\n---\n"
	return LoreEntry.from_string(path, front + body)


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(WALKER_ROOT.path_join("locations"))
	DirAccess.make_dir_recursive_absolute(WALKER_ROOT.path_join("_templates"))
	DirAccess.make_dir_recursive_absolute(WALKER_ROOT.path_join(".hidden"))
	_write(WALKER_ROOT.path_join("bible.md"), ENTRY_TEXT.replace("## Function\nx", "[[alpha]]"))
	_write(WALKER_ROOT.path_join("locations/alpha.md"), ENTRY_TEXT)
	_write(WALKER_ROOT.path_join("locations/notes.txt"), "not markdown")
	_write(WALKER_ROOT.path_join("_templates/skip.md"), "quarantined")
	_write(WALKER_ROOT.path_join(".hidden/skip_too.md"), "quarantined")


func after_all() -> void:
	_remove_recursive(WALKER_ROOT)


func test_from_entries_graph_reachability_and_inbound() -> void:
	var vault := LoreVault.from_entries(
		[_fx("bible", "[[alpha]]"), _fx("alpha", "[[beta]]"), _fx("beta", "no links")]
	)
	assert_eq(vault.errors, [] as Array[String], "clean fixtures produce no errors")
	var reachable := vault.reachable_from(&"bible")
	assert_eq(reachable.size(), 3, "bible -> alpha -> beta all reachable")
	assert_true(reachable.has(&"bible"), "start is included")
	assert_eq(vault.inbound_links_to(&"beta"), [&"alpha"] as Array[StringName])
	assert_eq(vault.inbound_links_to(&"bible"), [] as Array[StringName], "nothing links the hub")


func test_bfs_survives_cycles_and_ignores_dangling_links() -> void:
	var vault := LoreVault.from_entries(
		[_fx("alpha", "[[beta]] [[ghost]]"), _fx("beta", "[[alpha]]")]
	)
	var reachable := vault.reachable_from(&"alpha")
	assert_eq(reachable.size(), 2, "cycle terminates; dangling [[ghost]] is not followed")
	assert_false(reachable.has(&"ghost"))


func test_reachable_from_missing_start_is_empty() -> void:
	var vault := LoreVault.from_entries([_fx("alpha", "x")])
	assert_eq(vault.reachable_from(&"missing").size(), 0)


func test_duplicate_ids_land_in_errors() -> void:
	var twin := LoreEntry.from_string("res://docs/lore/npcs/alpha.md", ENTRY_TEXT)
	var vault := LoreVault.from_entries([_fx("alpha", "x"), twin])
	assert_eq(vault.entries.size(), 1, "first claim wins")
	assert_eq(vault.errors.size(), 1)
	assert_true(vault.errors[0].contains("duplicate id 'alpha'"), vault.errors[0])


func test_parse_failures_land_in_errors() -> void:
	var broken := LoreEntry.from_string("res://docs/lore/locations/broken.md", "no frontmatter")
	var vault := LoreVault.from_entries([broken])
	assert_eq(vault.entries.size(), 0)
	assert_eq(vault.errors.size(), 1)
	assert_true(vault.errors[0].contains("broken.md"), vault.errors[0])


func test_walker_skips_quarantined_dirs_and_non_markdown() -> void:
	var walked := LoreVault.collect_markdown_files(WALKER_ROOT)
	var raw := _raw_files(WALKER_ROOT)
	walked.sort()
	var excluded := PackedStringArray()
	for file_path: String in raw:
		if not walked.has(file_path):
			excluded.append(file_path)
	excluded.sort()
	assert_eq(
		walked,
		PackedStringArray(
			[WALKER_ROOT.path_join("bible.md"), WALKER_ROOT.path_join("locations/alpha.md")]
		),
		"exactly the live .md files are walked"
	)
	assert_eq(
		excluded,
		PackedStringArray(
			[
				WALKER_ROOT.path_join(".hidden/skip_too.md"),
				WALKER_ROOT.path_join("_templates/skip.md"),
				WALKER_ROOT.path_join("locations/notes.txt"),
			]
		),
		"exactly the quarantined and non-markdown files are excluded"
	)


func test_load_vault_over_a_real_tree() -> void:
	var vault := LoreVault.load_vault(WALKER_ROOT)
	assert_eq(vault.errors, [] as Array[String], "tree loads clean: %s" % str(vault.errors))
	assert_eq(vault.entries.size(), 2)
	assert_true(vault.reachable_from(&"bible").has(&"alpha"), "links resolve across folders")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "user:// must be writable for the walker fixture")
	file.store_string(text)
	file.close()


## Everything under root, no skips — the comparison baseline for quarantine.
## include_hidden makes dot-directories visible; DirAccess hides them by
## default, which is half of what the production walker relies on.
func _raw_files(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.include_hidden = true
	for file_name: String in dir.get_files():
		found.append(root.path_join(file_name))
	for dir_name: String in dir.get_directories():
		found.append_array(_raw_files(root.path_join(dir_name)))
	return found


func _remove_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name: String in dir.get_directories():
		_remove_recursive(path.path_join(dir_name))
	DirAccess.remove_absolute(path)
