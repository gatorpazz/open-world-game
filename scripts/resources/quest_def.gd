class_name QuestDef
extends Resource
## A quest read from the journal (spec 006): an ordered sequence of stages,
## each bound to one JournalEntryDef id. Runtime status is derived from
## Journal.entries by QuestEvaluator — no quest state is stored anywhere.

@export var id: StringName = &""
@export var display_name: String = ""
## Lore entry ids (docs/lore/ stems) this quest's content derives from —
## durable canon-packet citations, validated against the vault by the lore
## suite (spec 006: the reverse of the game_ids bridge).
@export var lore_sources: Array[StringName] = []
## Ordered; the array index IS the stage index. Progress is the highest
## index whose journal entry is held — out-of-order arrival is legal.
@export var stages: Array[QuestStage] = []
