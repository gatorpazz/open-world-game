class_name FactionRank
extends Resource
## One rank of a FactionDef (spec 015) — always a sub-resource inside the
## faction's .tres, never a standalone file (the QuestStage pattern). Ranks
## are ordered low->high in FactionDef.ranks; the array index IS the rank.
## reputation_min is the standing needed to advance INTO this rank; rank 0's
## value is the reputation seeded on joining. skill_id/skill_min are an
## optional governing-skill gate on advancement (&"" = no skill requirement).

@export var id: StringName = &""
@export var title: String = ""
## Reputation required to advance into this rank. Rank 0: the join value.
@export var reputation_min: int = 0
## Optional governing-skill gate — &"" means no skill requirement.
## Resolves to res://data/skills/<id>.tres when set.
@export var skill_id: StringName = &""
@export var skill_min: int = 0
