class_name NPCDef
extends Resource
## A dialogue anchor with a name (spec 005). Kept minimal — no faction, no
## disposition, no stats. The one sanctioned amendment (spec 020) is a presence
## schedule; NPCs that fight or trade stay a future spec's decision. Content
## lives in data/npcs/*.tres.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Optional present-window (spec 020): null = always at post. When set, the Npc
## node shows/hides itself as the bell crosses the window (presence-lite).
@export var schedule: NPCSchedule
