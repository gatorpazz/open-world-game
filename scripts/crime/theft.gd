class_name Theft
extends RefCounted
## The acquire choke (spec 017): the one path every take of a possibly-owned
## item runs through — a world pickup, a container take, a shop grab. Ties the
## pure verdict (CrimeRules) and the witness primitive (WitnessQuery) to the
## live game: flags the taken stack stolen when it isn't yours, and — if any
## NPC saw — records the theft with the jurisdiction. Impure by design (it
## reads the actor and calls Game's own report API); the numbers it feeds Game
## come from CrimeRules + the balance config, never hardcoded.

## The enforcing authority for the one shipped settlement (Lastdoor). Canon:
## the Wardens license, patrol, and witness (docs/lore/factions/wardens.md).
## Per-settlement jurisdiction becomes world-production data in Phase 3.
const JURISDICTION := &"wardens"


## Takes `count` of `item` from a source owned by `owner_faction` into the
## taker. Returns true when the take was a witnessed crime (the caller flashes
## the HUD). An unowned source (empty owner_faction) is a clean pickup.
static func acquire(
	actor: Player, taker: InventoryComponent, item: ItemDef, count: int, owner_faction: StringName
) -> bool:
	var stolen := CrimeRules.marks_stolen(owner_faction)
	taker.add_item(item, count, stolen)
	if not stolen:
		return false
	var sneak_skill: int = actor.stats.sheet.skills.get(&"sneak", 0)
	var witnessed := WitnessQuery.is_witnessed(
		actor, actor.get_parent(), sneak_skill, actor.sneaking, actor.config
	)
	if witnessed:
		Game.report_theft(
			JURISDICTION,
			CrimeRules.theft_bounty(item, actor.config),
			CrimeRules.reputation_dock(actor.config)
		)
		actor.show_notice(HudNotice.CRIME_WITNESSED)
	return witnessed
