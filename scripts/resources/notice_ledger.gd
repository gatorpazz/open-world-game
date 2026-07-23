class_name NoticeLedger
extends Resource
## The player's notice (spec 018): the regard an unlicensed working draws, per
## the_workings — "a working makes the worker remarkable." A personal ledger
## that only ever rises: unlike BountyLedger there is deliberately no clear(),
## because notice never clears (director ruling), and its threshold crossing is
## the permanent overcast state. Pure data + pure helpers (the FactionStanding
## /BountyLedger pattern) — held on Game, serialized by SaveCodec.

@export var notice: int = 0


func get_notice() -> int:
	return notice


## Adds regard from an unlicensed working. Monotonic — there is no way down.
func add(amount: int) -> void:
	notice += amount


## Overcast — "spent past recovery, permanently remarkable" — is notice past the
## threshold. Permanent because notice never decreases.
func is_overcast(threshold: int) -> bool:
	return notice >= threshold
