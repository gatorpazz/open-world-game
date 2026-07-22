class_name CrimeRules
extends RefCounted
## Pure crime economics and the acquisition verdict (spec 017): all static, no
## scene tree, every input passed in (the BarterRules/FactionRules pattern).
## The witness query and the bounty ledger are scene/state objects wired in by
## the take paths; the decisions they feed on live here so they stay testable.


## The bounty a single stolen unit adds, from its base_value. Clamped >= 1 —
## even a worthless trinket carries some legal weight.
static func theft_bounty(item: ItemDef, config: BalanceConfig) -> int:
	return maxi(1, ceili(item.base_value * config.theft_bounty_multiplier))


## What a warden charges to clear a standing bounty. Takes the raw bounty (the
## caller reads it off Game.bounty) so this stays decoupled from the ledger.
## The fine_multiplier is 1.0 in v1 — the seam a persuaded warden (019) narrows.
static func fine_owed(bounty_amount: int, config: BalanceConfig) -> int:
	return maxi(0, ceili(bounty_amount * config.fine_multiplier))


## Reputation lost with the jurisdiction per witnessed theft.
static func reputation_dock(config: BalanceConfig) -> int:
	return config.crime_reputation_dock


## Whether taking from a source of this ownership yields stolen goods. Any
## owned source does — you took what wasn't yours, seen or not.
static func marks_stolen(owner_faction: StringName) -> bool:
	return owner_faction != &""


## Whether the take accrues bounty: only an owned take that an observer saw.
## Getting away with it still leaves the goods hot (marks_stolen), but unfined.
static func accrues_bounty(owner_faction: StringName, witnessed: bool) -> bool:
	return marks_stolen(owner_faction) and witnessed
