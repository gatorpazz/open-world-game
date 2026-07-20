extends GutTest
## Unit tests for QuestEvaluator and QuestLibrary (spec 006, acceptance
## criteria 1-2): status derivation, precedence, out-of-order arrival,
## grouping chronology, and the cached loader.


func before_each() -> void:
	QuestLibrary.reset()


func after_each() -> void:
	QuestLibrary.reset()


func test_fresh_journal_is_not_started() -> void:
	var quest := _quest(&"q", [_stage(&"a"), _stage(&"b", QuestStage.OUTCOME_COMPLETE)])
	var journal := _journal_with([])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.NOT_STARTED)
	assert_eq(QuestEvaluator.latest_stage_index(quest, journal), -1)
	assert_eq(QuestEvaluator.reached_stages(quest, journal).size(), 0)


func test_progress_entry_makes_active() -> void:
	var quest := _quest(&"q", [_stage(&"a"), _stage(&"b", QuestStage.OUTCOME_COMPLETE)])
	var journal := _journal_with([&"a"])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.ACTIVE)
	assert_eq(QuestEvaluator.latest_stage_index(quest, journal), 0)


func test_complete_entry_completes_even_alone() -> void:
	var quest := _quest(&"q", [_stage(&"a"), _stage(&"b", QuestStage.OUTCOME_COMPLETE)])
	var journal := _journal_with([&"b"])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.COMPLETED)
	assert_eq(QuestEvaluator.latest_stage_index(quest, journal), 1)


func test_fail_entry_fails_without_complete() -> void:
	var quest := _quest(
		&"q",
		[
			_stage(&"a"),
			_stage(&"lost", QuestStage.OUTCOME_FAIL),
			_stage(&"won", QuestStage.OUTCOME_COMPLETE),
		]
	)
	var journal := _journal_with([&"a", &"lost"])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.FAILED)


func test_completed_beats_failed_when_both_held() -> void:
	var quest := _quest(
		&"q",
		[_stage(&"lost", QuestStage.OUTCOME_FAIL), _stage(&"won", QuestStage.OUTCOME_COMPLETE)]
	)
	var journal := _journal_with([&"lost", &"won"])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.COMPLETED)


func test_out_of_order_arrival_is_defined() -> void:
	var quest := _quest(
		&"q", [_stage(&"a"), _stage(&"b"), _stage(&"c"), _stage(&"d", QuestStage.OUTCOME_COMPLETE)]
	)
	var journal := _journal_with([&"c"])
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.ACTIVE)
	assert_eq(QuestEvaluator.latest_stage_index(quest, journal), 2)
	journal.add_entry(&"a")
	assert_eq(
		QuestEvaluator.latest_stage_index(quest, journal),
		2,
		"a lower stage arriving later never lowers progress"
	)


func test_reached_stages_in_stage_order_not_journal_order() -> void:
	var quest := _quest(
		&"q", [_stage(&"a"), _stage(&"b"), _stage(&"c", QuestStage.OUTCOME_COMPLETE)]
	)
	var journal := _journal_with([&"c", &"a"])
	var reached := QuestEvaluator.reached_stages(quest, journal)
	assert_eq(reached.size(), 2)
	assert_eq(reached[0].journal_entry, &"a")
	assert_eq(reached[1].journal_entry, &"c")


func test_group_by_status_buckets() -> void:
	var fresh := _quest(&"fresh", [_stage(&"f1"), _stage(&"f2", QuestStage.OUTCOME_COMPLETE)])
	var active := _quest(&"active", [_stage(&"a1"), _stage(&"a2", QuestStage.OUTCOME_COMPLETE)])
	var done := _quest(&"done", [_stage(&"d1", QuestStage.OUTCOME_COMPLETE)])
	var lost := _quest(
		&"lost",
		[_stage(&"l1", QuestStage.OUTCOME_FAIL), _stage(&"l2", QuestStage.OUTCOME_COMPLETE)]
	)
	var journal := _journal_with([&"a1", &"d1", &"l1"])
	var groups := QuestEvaluator.group_by_status([fresh, active, done, lost], journal)
	var not_started: Array[QuestDef] = groups[QuestEvaluator.Status.NOT_STARTED]
	var actives: Array[QuestDef] = groups[QuestEvaluator.Status.ACTIVE]
	var completed: Array[QuestDef] = groups[QuestEvaluator.Status.COMPLETED]
	var failed: Array[QuestDef] = groups[QuestEvaluator.Status.FAILED]
	assert_eq(not_started, [fresh] as Array[QuestDef])
	assert_eq(actives, [active] as Array[QuestDef])
	assert_eq(completed, [done] as Array[QuestDef])
	assert_eq(failed, [lost] as Array[QuestDef])


func test_group_order_follows_journal_chronology_of_earliest_entry() -> void:
	var first := _quest(&"first", [_stage(&"f_a"), _stage(&"f_z", QuestStage.OUTCOME_COMPLETE)])
	var second := _quest(&"second", [_stage(&"s_a"), _stage(&"s_z", QuestStage.OUTCOME_COMPLETE)])
	var journal := _journal_with([&"s_a", &"f_a"])
	var groups := QuestEvaluator.group_by_status([first, second], journal)
	var actives: Array[QuestDef] = groups[QuestEvaluator.Status.ACTIVE]
	assert_eq(
		actives,
		[second, first] as Array[QuestDef],
		"the quest whose earliest entry landed first comes first"
	)


func test_library_loads_and_caches_data_quests() -> void:
	var quests := QuestLibrary.get_quests()
	assert_true(quests.has(&"a_small_favor"), "shipped quest loads by id")
	assert_same(quests, QuestLibrary.get_quests(), "second call returns the cache")
	QuestLibrary.reset()
	var reloaded := QuestLibrary.get_quests()
	assert_true(reloaded.has(&"a_small_favor"), "reset reloads from disk")


func test_shipped_retrofit_derives_on_real_data() -> void:
	var quest: QuestDef = QuestLibrary.get_quests()[&"a_small_favor"]
	var journal := Journal.new()
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.NOT_STARTED)
	journal.add_entry(&"suddel_wants_a_pelt")
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.ACTIVE)
	journal.add_entry(&"suddels_stores_favor")
	assert_eq(QuestEvaluator.status(quest, journal), QuestEvaluator.Status.COMPLETED)


func _stage(entry: StringName, outcome: StringName = QuestStage.OUTCOME_PROGRESS) -> QuestStage:
	var stage := QuestStage.new()
	stage.journal_entry = entry
	stage.outcome = outcome
	return stage


func _quest(id: StringName, stages: Array[QuestStage]) -> QuestDef:
	var quest := QuestDef.new()
	quest.id = id
	quest.display_name = String(id)
	quest.stages = stages
	return quest


func _journal_with(entries: Array[StringName]) -> Journal:
	var journal := Journal.new()
	for entry: StringName in entries:
		journal.add_entry(entry)
	return journal
