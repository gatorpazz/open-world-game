extends GutTest
## The real-vault canon suite (spec 011, criteria 5-9) — the quality gate the
## Phase 3 bulk pipeline runs against. Loads docs/lore fresh and validates
## every grammar-passing entry against the schema: ids and folders, known
## keys, enum fields, the graduated per-status matrix, link integrity, the
## deprecation rules, reachability from bible.md, the game_ids bridge, and
## its reverse — the lore_sources citation bridge (spec 006).

const VAULT_ROOT := "res://docs/lore"
const HUB_ID := &"bible"

const FOLDER_TYPES: Dictionary[String, StringName] = {
	"rules": &"world_rule",
	"timeline": &"timeline_event",
	"regions": &"region",
	"locations": &"location",
	"cultures": &"culture",
	"factions": &"faction",
	"npcs": &"npc",
	"wildlife": &"wildlife",
	"items": &"item",
}

const VALID_STATUSES: Array[StringName] = [&"draft", &"reviewed", &"canon", &"deprecated"]
const VALID_SPOILERS: Array[String] = ["none", "low", "high"]
const VALID_SURFACES: Array[String] = [
	"dialogue", "journal", "environment", "rumor", "quest", "none"
]
const VALID_KINDS: Array[String] = ["settlement", "landmark", "dungeon", "route", "danger_zone"]

## Fixed by the M2 timeline pass from bible.md's Historical spine (spec
## 011): grief-shaped — the world lost, wounded, enduring.
const VALID_ERAS: Array[String] = ["the_daylight", "the_coming", "the_roofed_years"]

const GAME_ID_FOLDERS: Dictionary[String, String] = {
	"npc": "npcs",
	"topic": "dialogue",
	"journal": "journal",
	"item": "items",
	"creature": "creatures",
	"quest": "quests",
	"faction": "factions",
}

## The reverse of the game_ids bridge (spec 006): data folders whose files
## carry lore_sources citations, each resolving to a live vault entry — a
## changed entry greps to its exact rewrite set.
const CITED_DATA: Array[String] = [
	"res://data/quests",
	"res://data/dialogue",
	"res://data/journal",
	"res://data/factions",
]

const SPINE_SECTIONS: Array[String] = [
	"Function",
	"Canon summary",
	"Visible traits",
	"Systems impact",
	"Relationships",
	"Quest hooks",
	"Environmental storytelling",
	"Open questions",
]
const CULTURE_SECTIONS: Array[String] = [
	"Naming conventions", "Speech & register", "Material culture"
]
const HUB_SECTIONS: Array[String] = [
	"Core promise",
	"Rules of the world",
	"Historical spine",
	"Regional map index",
	"Peoples & powers",
	"Content grammar",
	"Player-facing surfaces",
	"Aesthetic brief",
	"Open questions",
]

const HOOK_COUNTED_TYPES: Array[StringName] = [&"location", &"faction", &"npc", &"culture"]
const BASE_KEYS: Array[String] = [
	"title",
	"type",
	"status",
	"region",
	"pitch",
	"spoiler",
	"surface",
	"tags",
	"game_ids",
	"superseded_by",
]

static var _id_regex := RegEx.create_from_string("^[a-z0-9_]+$")
static var _markup_regex := RegEx.create_from_string(DialogueMarkup.MARKUP_PATTERN)

var _vault: LoreVault


func before_all() -> void:
	_vault = LoreVault.load_vault(VAULT_ROOT)


func test_vault_loads_clean_and_is_not_empty() -> void:
	for problem: String in _vault.errors:
		fail_test(problem)
	assert_true(_vault.errors.is_empty(), "no parse failures or duplicate ids")
	assert_true(
		_vault.entries.has(HUB_ID),
		"bible.md exists and loads — the suite must never pass vacuously"
	)


func test_ids_folders_and_the_single_hub() -> void:
	var hub_count := 0
	for entry: LoreEntry in _vault.entries.values():
		assert_not_null(_id_regex.search(String(entry.id)), "%s: id is [a-z0-9_]+" % entry.path)
		var folder := entry.path.get_base_dir().get_file()
		if folder == "lore":
			assert_eq(entry.type, &"hub", "%s: only the hub lives at the vault root" % entry.path)
			assert_eq(entry.id, HUB_ID, "%s: the root file is bible.md" % entry.path)
			hub_count += 1
		else:
			assert_true(
				FOLDER_TYPES.has(folder), "%s: folder '%s' is a typed folder" % [entry.path, folder]
			)
			if FOLDER_TYPES.has(folder):
				assert_eq(
					entry.type, FOLDER_TYPES[folder], "%s: type matches its folder" % entry.path
				)
	assert_eq(hub_count, 1, "exactly one hub entry exists")


func test_frontmatter_keys_are_known() -> void:
	for entry: LoreEntry in _vault.entries.values():
		var allowed := _allowed_keys(entry.type)
		var present: Array[String] = []
		present.append_array(entry.frontmatter.scalars.keys())
		present.append_array(entry.frontmatter.lists.keys())
		for key: String in present:
			assert_has(allowed, key, "%s: key '%s' is in the schema" % [entry.path, key])


func test_enum_fields_and_per_type_rules() -> void:
	var era_orders: Dictionary[String, String] = {}
	for entry: LoreEntry in _vault.entries.values():
		assert_has(VALID_STATUSES, entry.status, "%s: valid status" % entry.path)
		assert_ne(entry.frontmatter.get_scalar("title"), "", "%s: has a title" % entry.path)
		var region := entry.frontmatter.get_scalar("region")
		assert_ne(region, "", "%s: has a region" % entry.path)
		if region != "world":
			var target := _vault.entries.get(StringName(region)) as LoreEntry
			assert_not_null(target, "%s: region '%s' resolves" % [entry.path, region])
			if target != null:
				assert_eq(target.type, &"region", "%s: region field names a region" % entry.path)
		var spoiler := entry.frontmatter.get_scalar("spoiler")
		if not spoiler.is_empty():
			assert_has(VALID_SPOILERS, spoiler, "%s: valid spoiler" % entry.path)
		for surface: String in entry.frontmatter.get_list("surface"):
			assert_has(VALID_SURFACES, surface, "%s: valid surface '%s'" % [entry.path, surface])
		if entry.type == &"location":
			assert_has(
				VALID_KINDS,
				entry.frontmatter.get_scalar("kind"),
				"%s: location kind from the allow-list" % entry.path
			)
		if entry.type == &"timeline_event":
			assert_has(
				VALID_ERAS, entry.frontmatter.get_scalar("era"), "%s: era is fixed" % entry.path
			)
			var order := entry.frontmatter.get_scalar("order")
			assert_true(order.is_valid_int(), "%s: order is an integer" % entry.path)
			var pair := "%s|%s" % [entry.frontmatter.get_scalar("era"), order]
			assert_false(era_orders.has(pair), "%s: (era, order) unique" % entry.path)
			era_orders[pair] = entry.path
		var culture := entry.frontmatter.get_scalar("culture")
		if not culture.is_empty():
			var culture_entry := _vault.entries.get(StringName(culture)) as LoreEntry
			assert_not_null(culture_entry, "%s: culture '%s' resolves" % [entry.path, culture])
			if culture_entry != null:
				assert_eq(culture_entry.type, &"culture", "%s: culture field typed" % entry.path)
		var superseded := entry.frontmatter.get_scalar("superseded_by")
		if not superseded.is_empty():
			assert_eq(
				entry.status, &"deprecated", "%s: superseded_by is deprecated-only" % entry.path
			)
			var live := _vault.entries.get(StringName(superseded)) as LoreEntry
			assert_not_null(live, "%s: superseded_by resolves" % entry.path)
			if live != null:
				assert_ne(live.status, &"deprecated", "%s: successor is live" % entry.path)


func test_graduated_matrix_by_status() -> void:
	var checked := 0
	for entry: LoreEntry in _vault.entries.values():
		if entry.status != &"reviewed" and entry.status != &"canon":
			continue
		checked += 1
		assert_ne(entry.frontmatter.get_scalar("pitch"), "", "%s: pitch present" % entry.path)
		assert_ne(entry.frontmatter.get_scalar("spoiler"), "", "%s: spoiler present" % entry.path)
		assert_gt(
			entry.frontmatter.get_list("surface").size(), 0, "%s: surface present" % entry.path
		)
		if entry.type == &"hub":
			for section: String in HUB_SECTIONS:
				assert_has(
					entry.sections.keys(), section, "%s: hub section '%s'" % [entry.path, section]
				)
			continue
		_assert_spine(entry)
		if entry.type == &"culture":
			for section: String in CULTURE_SECTIONS:
				assert_has(
					entry.sections.keys(),
					section,
					"%s: culture section '%s'" % [entry.path, section]
				)
		if HOOK_COUNTED_TYPES.has(entry.type):
			assert_gt(
				_bullet_count(entry.sections.get("Quest hooks", "")),
				2,
				"%s: at least 3 quest-hook bullets at reviewed+" % entry.path
			)
	if checked == 0:
		pass_test("no reviewed/canon entries yet — the matrix has nothing to check (M0)")


func test_links_resolve_with_deprecation_and_markup_rules() -> void:
	for entry: LoreEntry in _vault.entries.values():
		for link: StringName in entry.body_links:
			var target := _vault.entries.get(link) as LoreEntry
			assert_not_null(
				target,
				"%s: [[%s]] dangles — create a stub (spec 011 stub ritual)" % [entry.path, link]
			)
			if target != null and entry.status != &"deprecated":
				assert_ne(
					target.status,
					&"deprecated",
					"%s: live entry links deprecated [[%s]] — relink" % [entry.path, link]
				)
		var values: Array[String] = []
		values.append_array(entry.frontmatter.scalars.values())
		for list_name: String in entry.frontmatter.lists:
			values.append_array(entry.frontmatter.lists[list_name])
		for value: String in values:
			assert_false(
				value.contains("[["), "%s: no wikilinks in frontmatter values" % entry.path
			)
		var residue := _markup_regex.sub(entry.stripped_body, "", true)
		assert_false(
			residue.contains("[[") or residue.contains("]]"),
			"%s: no stray or malformed [[markup]] outside code" % entry.path
		)


func test_reachability_and_the_single_active_region() -> void:
	if not _vault.entries.has(HUB_ID):
		return
	var reachable := _vault.reachable_from(HUB_ID)
	var active_regions := 0
	var region_count := 0
	for entry: LoreEntry in _vault.entries.values():
		if entry.status == &"deprecated":
			continue
		assert_true(
			reachable.has(entry.id),
			"%s: unreachable from bible.md — link it from its parent" % entry.path
		)
		if entry.type == &"region":
			region_count += 1
			if not entry.frontmatter.get_list("tags").has("locked"):
				active_regions += 1
	if region_count > 0:
		assert_eq(active_regions, 1, "exactly one active (non-locked) region")


func test_game_ids_bridge_resolves() -> void:
	var checked := 0
	for entry: LoreEntry in _vault.entries.values():
		for item: String in entry.frontmatter.get_list("game_ids"):
			checked += 1
			var parts := item.split(":")
			assert_eq(parts.size(), 2, "%s: game_ids '%s' is kind:id" % [entry.path, item])
			if parts.size() != 2:
				continue
			assert_true(
				GAME_ID_FOLDERS.has(parts[0]),
				"%s: game_ids kind '%s' is known" % [entry.path, parts[0]]
			)
			if not GAME_ID_FOLDERS.has(parts[0]):
				continue
			var res_path := "res://data/%s/%s.tres" % [GAME_ID_FOLDERS[parts[0]], parts[1]]
			assert_true(
				FileAccess.file_exists(res_path),
				"%s: game_ids '%s' resolves to %s" % [entry.path, item, res_path]
			)
	if checked == 0:
		pass_test("no game_ids in the vault yet — the bridge arrives with M3 (spec 011)")


func test_lore_sources_resolve_to_live_entries() -> void:
	var checked := 0
	for dir: String in CITED_DATA:
		for file_name: String in DirAccess.get_files_at(dir):
			if not file_name.ends_with(".tres"):
				continue
			var resource: Resource = load(dir.path_join(file_name))
			assert_not_null(resource, "%s loads" % file_name)
			if resource == null:
				continue
			var sources: Array[StringName] = resource.get("lore_sources")
			for source: StringName in sources:
				checked += 1
				assert_true(
					_vault.entries.has(source),
					"%s: lore_sources '%s' resolves to a vault entry" % [file_name, source]
				)
				if not _vault.entries.has(source):
					continue
				var entry: LoreEntry = _vault.entries[source]
				assert_ne(
					entry.status,
					&"deprecated",
					"%s: lore_sources '%s' cites a live entry" % [file_name, source]
				)
	assert_gt(checked, 0, "the citation bridge covers shipped content (spec 006)")


func test_quarantine_is_honored() -> void:
	for entry: LoreEntry in _vault.entries.values():
		assert_false(
			entry.path.contains("/_") or entry.path.contains("/."),
			"%s: quarantined directories are never loaded" % entry.path
		)


func _allowed_keys(entry_type: StringName) -> Array[String]:
	var keys := BASE_KEYS.duplicate()
	if entry_type == &"location":
		keys.append("kind")
		keys.append("culture")
	elif entry_type == &"timeline_event":
		keys.append("era")
		keys.append("order")
	elif entry_type == &"npc":
		keys.append("culture")
	return keys


## Asserts all eight spine sections are present in canonical relative order
## (extra sections may interleave freely).
func _assert_spine(entry: LoreEntry) -> void:
	var keys: Array = entry.sections.keys()
	var last_position := -1
	for section: String in SPINE_SECTIONS:
		var position := keys.find(section)
		assert_ne(position, -1, "%s: spine section '%s' present" % [entry.path, section])
		if position != -1:
			assert_gt(position, last_position, "%s: '%s' in spine order" % [entry.path, section])
			last_position = position


func _bullet_count(text: String) -> int:
	var count := 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("- "):
			count += 1
	return count
