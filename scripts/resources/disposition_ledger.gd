class_name DispositionLedger
extends Resource
## The player's persistent per-NPC disposition modifier (spec 019): the regard a
## persuasion move (admire/intimidate/bribe) shifts, keyed by NPC id. It is one
## term of the effective disposition — base + faction reputation + THIS modifier
## − overcast (DispositionRules composes them). Pure data + pure helpers (the
## BountyLedger pattern) — held on Game like the journal, serialized by SaveCodec.

@export var modifier: Dictionary[StringName, int] = {}


## The standing modifier for an NPC; 0 when none has been earned.
func get_modifier(npc_id: StringName) -> int:
	if not modifier.has(npc_id):
		return 0
	return modifier[npc_id]


## Moves an NPC's modifier by delta — it can go negative (a failed intimidate
## docks it), seeding the record on the first move.
func adjust(npc_id: StringName, delta: int) -> void:
	modifier[npc_id] = get_modifier(npc_id) + delta
