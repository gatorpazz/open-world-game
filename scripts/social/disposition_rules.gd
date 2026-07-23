class_name DispositionRules
extends RefCounted
## Pure disposition + persuasion math (spec 019). No Game, no nodes — the
## dialogue panel and barter panel compose the inputs from Game and the sheet;
## the Persuasion orchestrator rolls the odds this returns (the
## LockRules/pick_chance shape — the dice live in the impure caller). Every
## number comes from BalanceConfig.

const ADMIRE := &"admire"
const INTIMIDATE := &"intimidate"
const BRIBE := &"bribe"


## An NPCDef's starting regard: its base_disposition, or the config default
## when it left the field at 0 ("use the default").
static func base_of(npc_def: NPCDef, config: BalanceConfig) -> int:
	if npc_def.base_disposition != 0:
		return npc_def.base_disposition
	return config.disposition_base_default


## An NPC's effective disposition: base + weighted faction reputation + the
## persistent per-NPC modifier − the overcast penalty (018), clamped.
static func disposition(
	base: int, faction_rep: int, modifier: int, overcast: bool, config: BalanceConfig
) -> int:
	var penalty := config.disposition_overcast_penalty if overcast else 0
	var raw := base + roundi(faction_rep * config.disposition_faction_weight) + modifier - penalty
	return clampi(raw, config.disposition_min, config.disposition_max)


## The odds a move lands: base + skill·weight + rapport·weight − the move's
## difficulty, clamped away from 0 and 1. Intimidate is harder the friendlier
## the NPC (bullying a friend backfires); admire/bribe rise with rapport. The
## caller rolls randf() < chance.
static func persuade_chance(
	move: StringName, skill: int, disposition_value: int, config: BalanceConfig
) -> float:
	# Rapport helps admire/bribe and hurts intimidate — bullying a friend is
	# harder, courting one easier — so its sign flips for intimidate.
	var rapport := float(disposition_value - config.disposition_neutral)
	var rapport_sign := -1.0 if move == INTIMIDATE else 1.0
	var chance := config.persuade_base + skill * config.persuade_skill_weight
	chance += rapport * config.persuade_disposition_weight * rapport_sign
	chance -= _move_difficulty(move, config)
	return clampf(chance, config.persuade_chance_min, config.persuade_chance_max)


## The modifier shift a move produces: its gain on success; on failure, nothing
## for admire/bribe, a backfire drop for intimidate.
static func move_delta(move: StringName, success: bool, config: BalanceConfig) -> int:
	if success:
		return _move_gain(move, config)
	if move == INTIMIDATE:
		return -config.intimidate_backfire
	return 0


## Beads to attempt a bribe — dearer the friendlier the NPC (diminishing goodwill).
static func bribe_cost(disposition_value: int, config: BalanceConfig) -> int:
	return config.bribe_cost_base + roundi(disposition_value * config.bribe_cost_per_disposition)


## The barter price factor from a merchant's disposition: a friendly merchant
## slides prices down (cheaper buys), a cold one up. Symmetric — it multiplies
## both buy and sell (the single-factor ruling; buy/sell split backlog), clamped.
static func price_factor(disposition_value: int, config: BalanceConfig) -> float:
	var swing := (disposition_value - config.disposition_neutral) * config.disposition_price_swing
	return clampf(1.0 - swing, config.price_factor_min, config.price_factor_max)


static func _move_difficulty(move: StringName, config: BalanceConfig) -> float:
	match move:
		INTIMIDATE:
			return config.persuade_difficulty_intimidate
		BRIBE:
			return config.persuade_difficulty_bribe
		_:
			return config.persuade_difficulty_admire


static func _move_gain(move: StringName, config: BalanceConfig) -> int:
	match move:
		INTIMIDATE:
			return config.persuade_gain_intimidate
		BRIBE:
			return config.persuade_gain_bribe
		_:
			return config.persuade_gain_admire
