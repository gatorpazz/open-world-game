class_name NPCDef
extends Resource
## A dialogue anchor with a name (spec 005). Two sanctioned amendments: a
## presence schedule (spec 020) and a disposition seam (spec 019 —
## base_disposition + an optional faction whose reputation feeds disposition).
## NPCs that fight stay a future spec's decision. Content lives in data/npcs/*.tres.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Optional present-window (spec 020): null = always at post. When set, the Npc
## node shows/hides itself as the bell crosses the window (presence-lite).
@export var schedule: NPCSchedule
## Starting regard (spec 019): where this NPC's disposition sits before any
## faction standing or persuasion. 0 uses config.disposition_base_default.
@export var base_disposition: int = 0
## Optional guild (spec 019): when set, the player's reputation with this
## faction (015) feeds the NPC's disposition. Empty = no faction term.
@export var faction: StringName = &""
