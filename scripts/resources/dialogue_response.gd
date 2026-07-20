class_name DialogueResponse
extends Resource
## One conditional answer inside a DialogueTopicDef (spec 005) — always a
## sub-resource in the topic's .tres, never a standalone file. Conditions
## AND together; a response with every condition empty is an unconditional
## fallback. take_items is both an effect and an implicit condition: the
## response is only offered while the player holds the items, so effects
## can never fail once a response is shown.

## Conditions. Empty npc_id means any NPC. blocked_by_journal is the
## negative gate (spec 006): the response matches only while the journal
## holds NONE of the listed entries — cross-NPC branch exclusion.
@export var npc_id: StringName = &""
@export var requires_topics: Array[StringName] = []
@export var requires_journal: Array[StringName] = []
@export var blocked_by_journal: Array[StringName] = []
@export var take_items: Array[ItemStack] = []

## Effects. [[topic_id]] markup in text unlocks topics when displayed.
@export_multiline var text: String
@export var journal_entry: StringName = &""
@export var give_items: Array[ItemStack] = []


## True when every condition field is empty — an always-available fallback.
## Responses after one of these in the same topic are unreachable.
func is_unconditional() -> bool:
	return (
		npc_id == &""
		and requires_topics.is_empty()
		and requires_journal.is_empty()
		and blocked_by_journal.is_empty()
		and take_items.is_empty()
	)
