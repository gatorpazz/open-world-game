class_name QuestEvaluator
extends RefCounted
## Derives quest status from the journal (spec 006). Quests store no runtime
## state: a QuestDef is a lens over Journal.entries, evaluated on demand.
## Precedence COMPLETED > FAILED > ACTIVE > NOT_STARTED makes the degenerate
## both-terminals case defined; progress is the highest held stage index, so
## out-of-order arrival is legal by construction. Static and pure — the
## CombatMath/DialogueEvaluator testability pattern.

enum Status { NOT_STARTED, ACTIVE, COMPLETED, FAILED }


static func status(quest: QuestDef, journal: Journal) -> Status:
	var any_held := false
	var any_failed := false
	for stage: QuestStage in quest.stages:
		if stage == null or not journal.has_entry(stage.journal_entry):
			continue
		any_held = true
		if stage.outcome == QuestStage.OUTCOME_COMPLETE:
			return Status.COMPLETED
		if stage.outcome == QuestStage.OUTCOME_FAIL:
			any_failed = true
	if any_failed:
		return Status.FAILED
	return Status.ACTIVE if any_held else Status.NOT_STARTED


## Highest stage index whose entry is held; -1 if none.
static func latest_stage_index(quest: QuestDef, journal: Journal) -> int:
	var latest := -1
	for i: int in quest.stages.size():
		var stage: QuestStage = quest.stages[i]
		if stage != null and journal.has_entry(stage.journal_entry):
			latest = i
	return latest


## Held stages in stage (array) order — the quests-view render source.
static func reached_stages(quest: QuestDef, journal: Journal) -> Array[QuestStage]:
	var reached: Array[QuestStage] = []
	for stage: QuestStage in quest.stages:
		if stage != null and journal.has_entry(stage.journal_entry):
			reached.append(stage)
	return reached


## Status -> Array[QuestDef]. Within a group, quests order by the journal
## chronology of their earliest held entry (stable ordering derived from
## existing state); NOT_STARTED quests keep their input order.
static func group_by_status(quests: Array[QuestDef], journal: Journal) -> Dictionary:
	var groups: Dictionary[Status, Array] = {
		Status.NOT_STARTED: [] as Array[QuestDef],
		Status.ACTIVE: [] as Array[QuestDef],
		Status.COMPLETED: [] as Array[QuestDef],
		Status.FAILED: [] as Array[QuestDef],
	}
	for quest: QuestDef in quests:
		if quest == null:
			continue
		var group: Array[QuestDef] = groups[status(quest, journal)]
		group.append(quest)
	for key: Status in [Status.ACTIVE, Status.COMPLETED, Status.FAILED]:
		var group: Array[QuestDef] = groups[key]
		group.sort_custom(
			func(a: QuestDef, b: QuestDef) -> bool:
				return _earliest_entry_index(a, journal) < _earliest_entry_index(b, journal)
		)
	return groups


## Journal chronology index of the quest's earliest held entry; -1 if none.
static func _earliest_entry_index(quest: QuestDef, journal: Journal) -> int:
	var earliest := -1
	for stage: QuestStage in quest.stages:
		if stage == null:
			continue
		var index := journal.entries.find(stage.journal_entry)
		if index == -1:
			continue
		if earliest == -1 or index < earliest:
			earliest = index
	return earliest
