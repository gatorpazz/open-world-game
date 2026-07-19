extends GutTest
## Milestone floor tests (spec 011, criteria 10-12). All floors are `>=` —
## the report's numbers are minimums, never pins. Grows one milestone at a
## time: M1 (foundation) lands here; the M2 passes raise it; M3 completes it.

const VAULT_ROOT := "res://docs/lore"

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

var _vault: LoreVault


func before_all() -> void:
	_vault = LoreVault.load_vault(VAULT_ROOT)


func test_m1_bible_sections_are_seeded() -> void:
	var bible := _vault.entries.get(&"bible") as LoreEntry
	assert_not_null(bible, "bible.md loads")
	if bible == null:
		return
	for section: String in HUB_SECTIONS:
		assert_has(bible.sections.keys(), section, "bible has '%s'" % section)
		var body: String = bible.sections.get(section, "")
		assert_false(
			body.contains("*(M1"), "'%s' holds content, not template scaffolding" % section
		)
		assert_false(body.strip_edges().is_empty(), "'%s' is non-empty" % section)


func test_m1_core_promise_has_forbidden_cliche_floor() -> void:
	var bible := _vault.entries.get(&"bible") as LoreEntry
	if bible == null:
		return
	var promise: String = bible.sections.get("Core promise", "")
	assert_true(promise.contains("Forbidden clich"), "the ban list lives in Core promise")
	assert_gt(_bullets(promise, "- "), 2, "at least 3 forbidden-cliche bullets")


func test_m1_aesthetic_brief_floors() -> void:
	var bible := _vault.entries.get(&"bible") as LoreEntry
	if bible == null:
		return
	var brief: String = bible.sections.get("Aesthetic brief", "")
	assert_gt(_bullets(brief, "- ref:"), 5, "at least 6 described visual references")
	assert_gt(_bullets(brief, "- texture:"), 4, "5 texture words")
	assert_gt(_bullets(brief, "- audio:"), 4, "5 audio words")
	assert_gt(_bullets(brief, "- tone:"), 4, "5 dialogue-tone words")
	assert_true(brief.contains("MDA"), "the MDA lens note lives in the Aesthetic brief")


func test_m2_geography_floors() -> void:
	var counts: Dictionary[String, int] = {
		"settlement": 0, "landmark": 0, "dungeon": 0, "route": 0, "danger_zone": 0
	}
	for entry: LoreEntry in _vault.entries.values():
		if entry.type != &"location" or entry.status == &"deprecated":
			continue
		if entry.frontmatter.get_scalar("region") != "undervault":
			continue
		var kind := entry.frontmatter.get_scalar("kind")
		if counts.has(kind):
			counts[kind] += 1
	assert_gt(counts["settlement"], 2, "at least 3 settlements in the active region")
	assert_gt(counts["landmark"] + counts["dungeon"], 7, "at least 8 landmarks + dungeons")
	assert_gt(counts["route"], 1, "at least 2 routes")
	assert_gt(counts["danger_zone"], 1, "at least 2 danger zones")


func test_m2_timeline_floors() -> void:
	var events := 0
	var eras: Dictionary[String, bool] = {}
	for entry: LoreEntry in _vault.entries.values():
		if entry.type != &"timeline_event" or entry.status == &"deprecated":
			continue
		events += 1
		eras[entry.frontmatter.get_scalar("era")] = true
	assert_gt(events, 11, "at least 12 timeline events")
	assert_gt(eras.size(), 1, "events span at least 2 eras")


func test_m1_active_region_exists_and_is_reachable() -> void:
	var regions := 0
	var reachable := _vault.reachable_from(&"bible")
	for entry: LoreEntry in _vault.entries.values():
		if entry.type != &"region" or entry.status == &"deprecated":
			continue
		regions += 1
		assert_true(reachable.has(entry.id), "%s: region reachable from bible" % entry.path)
	assert_gt(regions, 0, "at least one region entry exists (M1 floor)")


func _bullets(text: String, prefix: String) -> int:
	var count := 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(prefix):
			count += 1
	return count
