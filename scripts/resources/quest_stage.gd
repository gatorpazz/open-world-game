class_name QuestStage
extends Resource
## One stage of a QuestDef (spec 006) — always a sub-resource inside the
## quest's .tres, never a standalone file (the DialogueResponse pattern).
## A stage binds one JournalEntryDef id; outcome marks terminals as a
## StringName enum (the ArmorDef.slot precedent).

const OUTCOME_PROGRESS := &""
const OUTCOME_COMPLETE := &"complete"
const OUTCOME_FAIL := &"fail"
const VALID_OUTCOMES: Array[StringName] = [
	OUTCOME_PROGRESS,
	OUTCOME_COMPLETE,
	OUTCOME_FAIL,
]

## JournalEntryDef id — resolves to res://data/journal/<id>.tres.
@export var journal_entry: StringName = &""
## &"" = progress stage; &"complete" / &"fail" are terminal outcomes.
@export var outcome: StringName = OUTCOME_PROGRESS
