extends GutTest
## Validates every QuestDef resource in data/quests/ (spec 006, acceptance
## criterion 10). Quests are journal-derived: every stage binds a resolvable
## JournalEntryDef id, every quest must be completable, the final stage must
## be terminal, and no journal id may drive more than one quest.

const DIR := "res://data/quests"
const JOURNAL_DIR := "res://data/journal"
const EXPECTED_COUNT := 3

var _quests: Array[QuestDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var quest: QuestDef = load(DIR.path_join(file_name)) as QuestDef
		assert_not_null(quest, "%s should load as a QuestDef" % file_name)
		if quest != null:
			_quests.append(quest)


func test_expected_count() -> void:
	assert_eq(_quests.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding quests")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for quest: QuestDef in _quests:
		assert_ne(quest.id, &"", "%s has an id" % quest.resource_path)
		assert_false(seen.has(quest.id), "id %s is unique" % quest.id)
		seen[quest.id] = true
		var file_stem := quest.resource_path.get_file().get_basename()
		assert_eq(String(quest.id), file_stem, "id matches filename for %s" % quest.resource_path)


func test_display_names_are_non_empty() -> void:
	for quest: QuestDef in _quests:
		assert_ne(quest.display_name, "", "%s has a display_name" % quest.id)


func test_lore_sources_present() -> void:
	for quest: QuestDef in _quests:
		assert_gt(quest.lore_sources.size(), 0, "%s cites at least one lore source" % quest.id)
		for source: StringName in quest.lore_sources:
			assert_ne(source, &"", "%s has no empty lore_sources id" % quest.id)


func test_stages_resolve_with_valid_unique_outcomes() -> void:
	for quest: QuestDef in _quests:
		assert_gt(quest.stages.size(), 0, "%s has at least one stage" % quest.id)
		var seen_entries: Dictionary[StringName, bool] = {}
		for stage: QuestStage in quest.stages:
			assert_not_null(stage, "%s has no null stages" % quest.id)
			if stage == null:
				continue
			assert_ne(stage.journal_entry, &"", "%s: every stage names a journal entry" % quest.id)
			_assert_resolves(stage.journal_entry, JOURNAL_DIR, "JournalEntryDef", quest.id)
			assert_has(
				QuestStage.VALID_OUTCOMES,
				stage.outcome,
				"%s: outcome '%s' is valid" % [quest.id, stage.outcome]
			)
			assert_false(
				seen_entries.has(stage.journal_entry),
				"%s: stage entry %s appears once" % [quest.id, stage.journal_entry]
			)
			seen_entries[stage.journal_entry] = true


func test_every_quest_is_completable() -> void:
	for quest: QuestDef in _quests:
		var has_complete := false
		for stage: QuestStage in quest.stages:
			if stage != null and stage.outcome == QuestStage.OUTCOME_COMPLETE:
				has_complete = true
		assert_true(has_complete, "%s has at least one complete stage" % quest.id)


func test_final_stage_is_terminal() -> void:
	for quest: QuestDef in _quests:
		if quest.stages.is_empty():
			continue
		var last: QuestStage = quest.stages[quest.stages.size() - 1]
		if last == null:
			continue
		assert_ne(
			last.outcome,
			QuestStage.OUTCOME_PROGRESS,
			"%s: a trailing progress stage is unreachable narrative" % quest.id
		)


func test_journal_ids_claimed_by_at_most_one_quest() -> void:
	var claims: Dictionary[StringName, StringName] = {}
	for quest: QuestDef in _quests:
		for stage: QuestStage in quest.stages:
			if stage == null:
				continue
			assert_false(
				claims.has(stage.journal_entry),
				(
					"journal id %s claimed by both %s and %s"
					% [stage.journal_entry, claims.get(stage.journal_entry, &""), quest.id]
				)
			)
			claims[stage.journal_entry] = quest.id


func _assert_resolves(id: StringName, dir: String, type_name: String, context: StringName) -> void:
	var path := dir.path_join(String(id) + ".tres")
	assert_true(
		ResourceLoader.exists(path),
		"%s: %s id '%s' resolves to %s" % [context, type_name, id, path]
	)
