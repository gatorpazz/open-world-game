extends GutTest
## Pure AlchemyRules (spec 022, acceptance criterion 3): the derived known-recipe
## gate, can-brew, skill-scaled yield, and the discovery curve. Defs are built in
## code — data files have their own validator; the real balance config is loaded.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func _sheet(alchemy: int) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.skills = {&"alchemy": alchemy}
	return sheet


func _ingredient(effects: Array[StringName]) -> IngredientDef:
	var ing := IngredientDef.new()
	ing.id = &"test_ingredient"
	ing.effects = effects
	return ing


func _recipe(min_skill: int, output_count := 1) -> RecipeDef:
	var recipe := RecipeDef.new()
	recipe.id = &"test_recipe"
	recipe.min_skill = min_skill
	recipe.output_count = output_count
	return recipe


func test_known_recipes_gate_on_alchemy_skill() -> void:
	var recipes: Array[RecipeDef] = [_recipe(25)]
	assert_true(
		AlchemyRules.known_recipes(recipes, _sheet(10)).is_empty(), "below min_skill: unknown"
	)
	assert_eq(AlchemyRules.known_recipes(recipes, _sheet(25)).size(), 1, "at min_skill: known")


func test_known_recipes_sort_deterministically() -> void:
	var low := _recipe(0)
	low.id = &"aaa"
	var high := _recipe(25)
	high.id = &"bbb"
	var known := AlchemyRules.known_recipes([high, low], _sheet(50))
	assert_eq(known[0].min_skill, 0, "lower tier first")
	assert_eq(known[1].min_skill, 25, "then the higher tier")


func test_can_brew_checks_held_ingredients() -> void:
	var ing := _ingredient([&"restore_health"])
	var recipe := _recipe(0)
	var stack := ItemStack.new()
	stack.item = ing
	stack.count = 2
	recipe.inputs = [stack]
	var inventory := Inventory.new()
	assert_false(AlchemyRules.can_brew(recipe, inventory), "nothing held: cannot brew")
	inventory.add_item(ing, 1)
	assert_false(AlchemyRules.can_brew(recipe, inventory), "one short: cannot brew")
	inventory.add_item(ing, 1)
	assert_true(AlchemyRules.can_brew(recipe, inventory), "both held: can brew")


func test_yield_scales_with_alchemy_skill() -> void:
	var recipe := _recipe(0, 2)  # base yield 2
	assert_eq(AlchemyRules.brew_yield(recipe, _sheet(0), _config), 2, "skill 0: base yield")
	assert_eq(
		AlchemyRules.brew_yield(recipe, _sheet(_config.alchemy_yield_skill_step), _config),
		3,
		"one step of skill: +1 draught"
	)
	assert_eq(
		AlchemyRules.brew_yield(recipe, _sheet(_config.alchemy_yield_skill_step * 2), _config),
		4,
		"two steps: +2"
	)


func test_discovery_reveals_more_effects_with_skill() -> void:
	var ing := _ingredient([&"restore_health", &"restore_mana", &"hide_regard"])
	assert_eq(
		AlchemyRules.discovered_effects(ing, _sheet(0), _config).size(),
		_config.alchemy_base_discovery,
		"a novice reads the base number of effects"
	)
	var master := AlchemyRules.discovered_effects(ing, _sheet(100), _config)
	assert_eq(master.size(), 3, "a master reads them all (clamped to the ingredient's list)")
	assert_eq(master[0], &"restore_health", "revealed front-to-back in order")
