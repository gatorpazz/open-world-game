class_name WorkingRules
extends RefCounted
## Pure licensing verdict and costs for a working (spec 018): all static, no
## scene tree, every input passed in (the CrimeRules/BarterRules pattern). A
## working above hearth-charm cast without its order's charter is unlicensed and
## draws notice; if witnessed it also draws a warden fine. Hearth-charm and
## licensed casting are free. The Working orchestrator ties this to the live
## game; the numbers all come from BalanceConfig.

## The aspect orders that charter the three schools (the_workings: Flame →
## evocation, Stone → warding, Tide → mending). No FactionDef exists for them
## yet — the player holds no aspect-charter in v1, so licensed-tier casting is
## always unlicensed (the intended teeth). Phase 3 makes them joinable orders.
const ASPECT_ORDERS: Array[StringName] = [&"flame_order", &"stone_order", &"tide_order"]


## Whether casting this working is unlicensed: it names a chartering order (i.e.
## it is above hearth-charm) and the caster does not hold that charter.
static func is_unlicensed(spell: SpellDef, chartered: bool) -> bool:
	return spell.license_order != &"" and not chartered


## The notice an unlicensed working draws each cast — the permanent magical mark.
static func notice_cost(_spell: SpellDef, config: BalanceConfig) -> int:
	return config.notice_per_unlicensed_working


## The warden fine a *witnessed* unlicensed working draws into the bounty ledger.
static func working_bounty(_spell: SpellDef, config: BalanceConfig) -> int:
	return config.unlicensed_working_fine


## Reputation lost with the jurisdiction — an offense is an offense, so this
## reuses the crime dock.
static func reputation_dock(config: BalanceConfig) -> int:
	return config.crime_reputation_dock
