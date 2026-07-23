class_name Working
extends RefCounted
## The casting enforcement choke (spec 018), the Theft.acquire analog: given a
## working the player just cast, decide if it was unlicensed and, if so, draw
## the consequences. Ties the pure verdict (WorkingRules) and the witness
## primitive (WitnessQuery, built in 017) to the live game. Impure by design —
## it reads the actor and calls Game's own report/notice APIs; every number
## comes from WorkingRules + the balance config. Hearth-charm and licensed
## casting fall straight through.

## The enforcing authority for the one shipped settlement (the Theft precedent).
## The wardens measure, witness, and price (the_workings); per-settlement
## jurisdiction is Phase 3.
const JURISDICTION := &"wardens"


## Records the working. Returns true when it was a witnessed unlicensed working
## (the caller may care). Notice accrues on any unlicensed working; a warden
## bounty is added only when it is witnessed — and an overcast caster is always
## witnessed ("the sky answers invitations").
static func report(actor: Player, spell: SpellDef) -> bool:
	var chartered := Game.is_chartered_under(spell.license_order)
	if not WorkingRules.is_unlicensed(spell, chartered):
		return false  # hearth-charm or licensed — nothing to answer for

	var threshold := actor.config.overcast_threshold
	var was_overcast := Game.notice.is_overcast(threshold)
	Game.notice.add(WorkingRules.notice_cost(spell, actor.config))
	actor.show_notice(HudNotice.WORKING_NOTICED)

	var witnessed := (
		Game.notice.is_overcast(threshold)
		or WitnessQuery.is_witnessed(
			actor,
			actor.get_parent(),
			actor.stats.sheet.skills.get(&"sneak", 0),
			actor.sneaking,
			actor.config
		)
	)
	if witnessed:
		Game.report_working(
			JURISDICTION,
			WorkingRules.working_bounty(spell, actor.config),
			WorkingRules.reputation_dock(actor.config)
		)
		actor.show_notice(HudNotice.WORKING_SEEN)

	# Crossing into overcast is a one-time reckoning: an extra reputation dock
	# with the jurisdiction, and the beacon lights.
	if not was_overcast and Game.notice.is_overcast(threshold):
		Game.report_overcast(JURISDICTION, WorkingRules.reputation_dock(actor.config))
		actor.show_notice(HudNotice.OVERCAST)

	return witnessed
