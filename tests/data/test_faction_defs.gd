extends GutTest
## Validates every FactionDef resource in data/factions/ (spec 015,
## acceptance criterion 1). lore_sources resolution is the lore suite's job
## (the CITED_DATA reverse bridge in tests/lore), matching how quests are
## validated.

const DIR := "res://data/factions"
const SKILLS_DIR := "res://data/skills"
const JOURNAL_DIR := "res://data/journal"
const EXPECTED_COUNT := 3

var _defs: Array[FactionDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: FactionDef = load(DIR.path_join(file_name)) as FactionDef
		assert_not_null(def, "%s should load as a FactionDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding factions")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: FactionDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_are_non_empty() -> void:
	for def: FactionDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)


func test_join_journal_entry_resolves() -> void:
	for def: FactionDef in _defs:
		assert_ne(def.join_journal_entry, &"", "%s names a join_journal_entry" % def.id)
		var path := JOURNAL_DIR.path_join("%s.tres" % def.join_journal_entry)
		assert_true(
			ResourceLoader.exists(path),
			"%s join_journal_entry '%s' resolves to %s" % [def.id, def.join_journal_entry, path]
		)


func test_ranks_are_non_empty_with_monotonic_reputation() -> void:
	for def: FactionDef in _defs:
		assert_false(def.ranks.is_empty(), "%s has at least one rank" % def.id)
		var previous_min := -1
		for rank: FactionRank in def.ranks:
			assert_ne(rank.id, &"", "%s rank has an id" % def.id)
			assert_ne(rank.title, "", "%s rank %s has a title" % [def.id, rank.id])
			assert_gte(
				rank.reputation_min,
				previous_min,
				"%s rank %s reputation_min is non-decreasing" % [def.id, rank.id]
			)
			previous_min = rank.reputation_min


func test_skill_gates_resolve_to_skills() -> void:
	for def: FactionDef in _defs:
		for rank: FactionRank in def.ranks:
			if rank.skill_id == &"":
				continue
			var skill := load(SKILLS_DIR.path_join("%s.tres" % rank.skill_id)) as SkillDef
			assert_not_null(
				skill,
				"%s rank %s skill_id '%s' resolves to a SkillDef" % [def.id, rank.id, rank.skill_id]
			)


func test_charter_rank_is_in_range() -> void:
	for def: FactionDef in _defs:
		assert_between(
			def.charter_rank, -1, def.ranks.size() - 1, "%s charter_rank in [-1, ranks)" % def.id
		)


func test_rivals_resolve_and_ship_empty() -> void:
	var ids: Dictionary[StringName, bool] = {}
	for def: FactionDef in _defs:
		ids[def.id] = true
	for def: FactionDef in _defs:
		# Director ruling (spec 015): independent, mechanism-ready — the rivals
		# machinery exists but every shipped faction ships empty rivals.
		assert_true(def.rivals.is_empty(), "%s ships empty rivals (independence ruling)" % def.id)
		for rival: StringName in def.rivals:
			assert_true(ids.has(rival), "%s rival '%s' resolves to a FactionDef" % [def.id, rival])
