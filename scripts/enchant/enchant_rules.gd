class_name EnchantRules
extends RefCounted
## Pure bound-working math (spec 023). No Game, no nodes — the hooks
## (player_combat, InventoryComponent) compose the inputs. A working's magnitude
## scales on its aspect skill via the 008 spell_power, or is flat for an unscaled
## hearth-charm (empty skill_id). Every number comes from BalanceConfig.


## Whether an item carries a bound working that fires on `trigger`.
static func triggers(item: ItemDef, trigger: StringName) -> bool:
	return item != null and item.bound_working != null and item.bound_working.trigger == trigger


## A working's effective magnitude: scaled by its aspect skill (the 008
## spell_power) when it names one, else the flat base (a hearth-charm).
static func magnitude(working: BoundWorkingDef, aspect_skill: int, config: BalanceConfig) -> float:
	if working.skill_id == &"":
		return working.magnitude
	return CombatMath.spell_power(working.magnitude, aspect_skill, config)


## Sums the effective magnitude of every equipped item carrying a `constant`
## working of the given effect (and, for fortify, the given subject). Each aspect
## skill is read from the sheet. Pure — the aggregation seam the defense pipeline
## and the combat/magic skill reads call.
static func constant_bonus(
	equipped: Array[ItemDef],
	effect: StringName,
	subject: StringName,
	sheet: CharacterSheet,
	config: BalanceConfig
) -> float:
	var total := 0.0
	for item: ItemDef in equipped:
		if not triggers(item, &"constant"):
			continue
		var working := item.bound_working
		if working.effect != effect:
			continue
		if effect == &"fortify" and working.subject != subject:
			continue
		var aspect_skill: int = sheet.skills.get(working.skill_id, 0)
		total += magnitude(working, aspect_skill, config)
	return total
