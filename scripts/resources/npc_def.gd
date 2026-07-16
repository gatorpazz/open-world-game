class_name NPCDef
extends Resource
## A dialogue anchor with a name (spec 005). Deliberately minimal — no
## faction, no disposition, no stats. Creatures got the "not characters"
## ruling in spec 004; NPCs that fight, trade, or keep schedules are a
## future spec's decision. Content lives in data/npcs/*.tres.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
