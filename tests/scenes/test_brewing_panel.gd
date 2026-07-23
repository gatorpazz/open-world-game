extends GutTest
## The brewing panel + the apparatus gate (spec 022, acceptance criteria 4-5).
## Panel methods are driven directly — no mouse simulation. Standalone fixtures
## for the brew logic; a real player for the kit gate. Mouse mode is never
## asserted (headless).

const PANEL_SCENE := preload("res://scenes/ui/brewing_panel.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALANCE := preload("res://data/balance/balance_config.tres")
const TERRACE_FUNGUS := preload("res://data/items/terrace_fungus.tres")
const SALTER_BRINE := preload("res://data/items/salter_brine.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")
const BREWING_KIT := preload("res://data/items/brewing_kit.tres")

var _stats: StatsComponent
var _items: InventoryComponent


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_items = InventoryComponent.new()
	_items.stats = _stats
	add_child_autofree(_items)


func after_each() -> void:
	get_tree().paused = false


func _open(alchemy_level: int) -> BrewingPanel:
	_stats.sheet.skills[&"alchemy"] = alchemy_level
	var panel := PANEL_SCENE.instantiate() as BrewingPanel
	add_child_autofree(panel)
	panel.open(_items, _stats, BALANCE)
	return panel


func test_brew_consumes_inputs_and_grants_yield_and_xp() -> void:
	_items.add_item(TERRACE_FUNGUS, 1)
	_items.add_item(SALTER_BRINE, 1)
	var panel := _open(0)  # brine_tonic (min_skill 0) is known

	assert_true(panel.brew_row(0), "a held, known recipe brews")
	assert_eq(_items.inventory.count_of(HEALING_DRAUGHT), 1, "one draught (base yield at skill 0)")
	assert_eq(_items.inventory.count_of(TERRACE_FUNGUS), 0, "the fungus is consumed")
	assert_eq(_items.inventory.count_of(SALTER_BRINE), 0, "the brine is consumed")
	assert_gt(int(_stats.sheet.skill_xp.get(&"alchemy", 0)), 0, "brewing grants alchemy xp")


func test_brew_refused_without_ingredients() -> void:
	var panel := _open(0)
	assert_false(panel.brew_row(0), "no ingredients: a silent no-op")
	assert_eq(_items.inventory.count_of(HEALING_DRAUGHT), 0, "nothing brewed")


func test_recipes_gate_on_alchemy_skill() -> void:
	var panel := _open(0)
	assert_eq(panel.recipe_row_count(), 1, "only the hearth recipe at skill 0")
	_stats.sheet.skills[&"alchemy"] = 25
	panel._refresh()
	assert_eq(panel.recipe_row_count(), 2, "the philtre unlocks at 25")


func test_yield_scales_with_alchemy_skill() -> void:
	_items.add_item(TERRACE_FUNGUS, 1)
	_items.add_item(SALTER_BRINE, 1)
	var panel := _open(BALANCE.alchemy_yield_skill_step)  # one step of skill: +1

	panel.brew_row(0)
	assert_eq(_items.inventory.count_of(HEALING_DRAUGHT), 2, "a step of skill gives +1 draught")


func test_the_brew_key_needs_the_kit() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)

	player.open_brewing()
	assert_false(_has_brewing_panel(player), "no kit: the panel does not open")

	player.inventory_component.add_item(BREWING_KIT, 1)
	player.open_brewing()
	assert_true(_has_brewing_panel(player), "with the kit held: the panel opens")


func _has_brewing_panel(player: Player) -> bool:
	for child: Node in player.get_children():
		if child is BrewingPanel:
			return true
	return false
