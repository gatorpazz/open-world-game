class_name FactionDef
extends Resource
## A joinable faction (spec 015): the numeric layer over the joined_* journal
## entry that membership rides today. Content lives in data/factions/*.tres;
## this script only defines the shape. Reputation and rank are stored per
## faction on Game via FactionStanding; this def carries the fixed rules —
## the rank ladder, which rank confers a charter, and which factions (if any)
## joining excludes. Pure rules that combine a def with a standing live in
## FactionRules (the SaveCodec-style static-and-injected pattern).

@export var id: StringName = &""
@export var display_name: String = ""
## Lore entry ids (docs/lore/ stems) this faction derives from — the
## canon-packet citation bridge, validated against the vault by the lore
## suite (the reverse of the game_ids bridge).
@export var lore_sources: Array[StringName] = []
## The joined_* journal entry that IS membership today (spec 005). Both the
## dialogue join effect and the save migration key off it: holding this entry
## seeds this faction's record. Resolves to res://data/journal/<id>.tres.
@export var join_journal_entry: StringName = &""
## Ordered low->high; the array index IS the rank. Index 0 is the joining
## rank — its reputation_min is the standing seeded on joining.
@export var ranks: Array[FactionRank] = []
## Rank index that confers a charter (spec 018 gates casting on it via
## Game.is_chartered_under). -1 = this faction never charters.
@export var charter_rank: int = -1
## Faction ids that block joining this one while held (the exclusivity
## mechanism). Ships EMPTY on every faction — all guilds stay independently
## joinable (director ruling); the machinery waits for content that excludes.
@export var rivals: Array[StringName] = []
