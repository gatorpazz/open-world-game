class_name AlchemyRules
extends RefCounted
## Pure alchemy logic (spec 022): all static, no scene tree, every input passed
## in (the WorkingRules/CrimeRules pattern). Known recipes and discovered
## effects are DERIVED from the alchemy skill each call — never stored (the
## PlayerCasting.filter_castable precedent), so nothing new joins the save.
## Brewing is deterministic; skill scales the yield, never a pass/fail.

## The closed vocabulary of ingredient effect tags — flavor labels the
## inspection layer reveals, not brewing inputs (fixed recipes carry the
## mechanics). Validated against IngredientDef.effects.
const EFFECTS: Array[StringName] = [
	&"restore_health", &"restore_mana", &"restore_stamina", &"hide_regard"
]

## The carried apparatus that gates brewing (a MiscDef id). Held, never consumed.
const APPARATUS_ID := &"brewing_kit"


## The recipes the player knows: alchemy skill at or above each min_skill, in
## deterministic (min_skill, id) order. Derived, never stored.
static func known_recipes(recipes: Array[RecipeDef], sheet: CharacterSheet) -> Array[RecipeDef]:
	var level: int = sheet.skills.get(&"alchemy", 0)
	var known: Array[RecipeDef] = []
	for recipe: RecipeDef in recipes:
		if level >= recipe.min_skill:
			known.append(recipe)
	known.sort_custom(
		func(a: RecipeDef, b: RecipeDef) -> bool:
			if a.min_skill != b.min_skill:
				return a.min_skill < b.min_skill
			return String(a.id) < String(b.id)
	)
	return known


## Whether the inventory holds every input in the required count.
static func can_brew(recipe: RecipeDef, inventory: Inventory) -> bool:
	for input: ItemStack in recipe.inputs:
		if inventory.count_of(input.item) < input.count:
			return false
	return true


## The number of output draughts a brew yields: the recipe's base count plus a
## bonus that rises with alchemy skill (the only lever — a ConsumableDef's
## potency is fixed). Never below the base.
static func brew_yield(recipe: RecipeDef, sheet: CharacterSheet, config: BalanceConfig) -> int:
	var level: int = sheet.skills.get(&"alchemy", 0)
	return recipe.output_count + level / config.alchemy_yield_skill_step


## The effects of an ingredient the player can read — the first k of its ordered
## list, k rising with alchemy skill (a novice reads one, a master reads all).
## Derived from skill, never stored.
static func discovered_effects(
	ingredient: IngredientDef, sheet: CharacterSheet, config: BalanceConfig
) -> Array[StringName]:
	var level: int = sheet.skills.get(&"alchemy", 0)
	var count := config.alchemy_base_discovery + level / config.alchemy_discovery_step
	return ingredient.effects.slice(0, mini(count, ingredient.effects.size()))
