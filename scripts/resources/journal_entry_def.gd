class_name JournalEntryDef
extends Resource
## One journal entry's content (spec 005), addressed by id from dialogue
## response effects and (spec 006) quest stages. Chronology is runtime
## state on the Journal resource, not content — no date field here.
## Content lives in data/journal/*.tres.

@export var id: StringName
## Lore entry ids this entry's text derives from (spec 006) — durable
## canon-packet citations; ≥1 required, validated against the vault by
## the lore suite.
@export var lore_sources: Array[StringName] = []
@export_multiline var text: String
