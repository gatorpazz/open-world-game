class_name Persuasion
extends RefCounted
## The persuasion move gate (spec 019): the one path admire/intimidate/bribe run
## through. Impure — it reads the mover's skill + purse, ROLLS (randf, the
## LockRules pattern — the dice in the social layer), shifts the NPC's
## disposition through Game, and returns a line for the dialogue transcript (the
## HUD is hidden behind the paused dialogue, so the outcome speaks there). The
## odds and deltas come from DispositionRules + the balance config.


## Attempts a move against the NPC at its current disposition. Bribe spends beads
## first and aborts if unpayable — no roll, no move. Returns the transcript line
## describing the outcome; the caller appends it and refreshes the topic list.
static func attempt(
	move: StringName,
	npc_id: StringName,
	skill: int,
	disposition_value: int,
	inventory: InventoryComponent,
	config: BalanceConfig
) -> String:
	if move == DispositionRules.BRIBE:
		var cost := DispositionRules.bribe_cost(disposition_value, config)
		if not inventory.spend_gold(cost):
			return "You haven't the %d beads to press." % cost
	var chance := DispositionRules.persuade_chance(move, skill, disposition_value, config)
	var success := randf() < chance
	var delta := DispositionRules.move_delta(move, success, config)
	Game.report_persuasion(npc_id, delta)
	return _outcome_line(move, success)


static func _outcome_line(move: StringName, success: bool) -> String:
	match move:
		DispositionRules.INTIMIDATE:
			if success:
				return "The threat lands; they give ground."
			return "They stiffen — the threat cost you."
		DispositionRules.BRIBE:
			if success:
				return "The beads change hands; they warm."
			return "They take the beads and stay cool."
		_:
			if success:
				return "They warm to the good word."
			return "The good word falls flat."
