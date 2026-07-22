class_name BountyLedger
extends Resource
## The player's per-jurisdiction bounty (spec 017): a legal debt keyed by the
## faction that holds jurisdiction, accrued when a theft is witnessed and
## cleared whole by paying a fine. Pure data + pure helpers (the FactionStanding
## pattern) — held on Game like the journal, serialized by SaveCodec. Kept
## separate from the notice ledger (018) by director ruling: a bounty clears, a
## notice never does.

@export var bounty: Dictionary[StringName, int] = {}


## The standing bounty with a jurisdiction; 0 when it holds no record.
func get_bounty(jurisdiction: StringName) -> int:
	if not bounty.has(jurisdiction):
		return 0
	return bounty[jurisdiction]


## Adds delta to a jurisdiction's bounty, seeding the record on the first crime.
func add_bounty(jurisdiction: StringName, delta: int) -> void:
	bounty[jurisdiction] = get_bounty(jurisdiction) + delta


## Wipes a jurisdiction's bounty — the fine is paid.
func clear(jurisdiction: StringName) -> void:
	bounty.erase(jurisdiction)
