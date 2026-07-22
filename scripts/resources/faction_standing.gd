class_name FactionStanding
extends Resource
## The player's per-faction standing (spec 015): reputation and rank, one
## entry per joined faction. Pure data + pure logic — no signals, no node
## references (the Journal/Inventory pattern). Membership IS a rank key being
## present. Held on Game like the journal and serialized by SaveCodec. The
## fixed rules that combine this with a FactionDef (advancement, charter) live
## in FactionRules.

@export var reputation: Dictionary[StringName, int] = {}
@export var rank: Dictionary[StringName, int] = {}


## True once the faction has a record — i.e. the player has joined.
func is_member(faction_id: StringName) -> bool:
	return rank.has(faction_id)


func get_reputation(faction_id: StringName) -> int:
	if not reputation.has(faction_id):
		return 0
	return reputation[faction_id]


func get_rank(faction_id: StringName) -> int:
	if not rank.has(faction_id):
		return 0
	return rank[faction_id]


## Moves reputation by delta — it can go negative (crime docks it in 017).
## No-op on a non-member: standing only exists once joined.
func adjust_reputation(faction_id: StringName, delta: int) -> void:
	if not rank.has(faction_id):
		return
	reputation[faction_id] = reputation[faction_id] + delta


## Seeds a fresh record — idempotent: a faction that already has a record is
## left exactly as-is (reputation and rank both preserved). This is what lets
## FactionRules.reconcile run at every scene entry without ever resetting a
## reputation dock (017) or a rank-up.
func seed_if_absent(faction_id: StringName, start_rank: int, start_reputation: int) -> void:
	if rank.has(faction_id):
		return
	rank[faction_id] = start_rank
	reputation[faction_id] = start_reputation
