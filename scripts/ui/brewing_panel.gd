class_name BrewingPanel
extends CanvasLayer
## The brewing counter (spec 022): known recipes on the left (Brew), your held
## ingredients with their discovered effects on the right. Opened off the
## carried Simpler's Kit. Pauses the tree like the barter panel (the scene root
## is process_mode = ALWAYS), frees the mouse, emits `closed`, frees itself.
## Mutation routes through the InventoryComponent so item signals fire; a failed
## guard is a silent no-op (the 016 precedent). Buttons route through the public
## API tests call directly.

signal closed

var _taker: InventoryComponent
var _stats: StatsComponent
var _config: BalanceConfig
## Known recipes in list order — a recipe row index maps here.
var _known: Array[RecipeDef] = []

@onready var recipe_list: ItemList = $Dim/Panel/Layout/Body/Recipes/List
@onready var ingredient_list: ItemList = $Dim/Panel/Layout/Body/Ingredients/List
@onready var brew_button: Button = $Dim/Panel/Layout/Buttons/Brew
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	brew_button.pressed.connect(_on_brew_pressed)
	close_button.pressed.connect(close)


func open(taker: InventoryComponent, stats: StatsComponent, config: BalanceConfig) -> void:
	_taker = taker
	_stats = stats
	_config = config
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Brews the known recipe at row `index`, consuming its inputs and granting the
## skill-scaled yield of the output ConsumableDef plus alchemy xp. False (no-op)
## when the row is invalid or the ingredients aren't held.
func brew_row(index: int) -> bool:
	if index < 0 or index >= _known.size():
		return false
	var recipe := _known[index]
	if not AlchemyRules.can_brew(recipe, _taker.inventory):
		return false
	var output := ItemLibrary.get_items().get(recipe.output_id) as ConsumableDef
	if output == null:
		return false
	for input: ItemStack in recipe.inputs:
		_taker.remove_item(input.item, input.count)
	_taker.add_item(output, AlchemyRules.brew_yield(recipe, _stats.sheet, _config))
	_stats.gain_skill_xp(&"alchemy", _config.xp_per_brew)
	_refresh()
	return true


func recipe_row_count() -> int:
	return _known.size()


func _refresh() -> void:
	_rebuild_recipes()
	_rebuild_ingredients()


func _rebuild_recipes() -> void:
	recipe_list.clear()
	var all: Array[RecipeDef] = []
	all.assign(RecipeLibrary.get_recipes().values())
	_known = AlchemyRules.known_recipes(all, _stats.sheet)
	for recipe: RecipeDef in _known:
		var output: ItemDef = ItemLibrary.get_items().get(recipe.output_id)
		var output_name := output.display_name if output != null else String(recipe.output_id)
		var count := AlchemyRules.brew_yield(recipe, _stats.sheet, _config)
		var mark := (
			"" if AlchemyRules.can_brew(recipe, _taker.inventory) else "  (need ingredients)"
		)
		recipe_list.add_item("%s → %s x%d%s" % [recipe.display_name, output_name, count, mark])


func _rebuild_ingredients() -> void:
	ingredient_list.clear()
	for stack: ItemStack in _taker.inventory.stacks:
		if not (stack.item is IngredientDef):
			continue
		var effects := AlchemyRules.discovered_effects(
			stack.item as IngredientDef, _stats.sheet, _config
		)
		var parts := PackedStringArray()
		for effect: StringName in effects:
			parts.append(String(effect))
		var effect_text := ", ".join(parts) if not parts.is_empty() else "?"
		ingredient_list.add_item(
			"%s x%d — %s" % [stack.item.display_name, stack.count, effect_text]
		)


func _on_brew_pressed() -> void:
	var selected := recipe_list.get_selected_items()
	if not selected.is_empty():
		brew_row(selected[0])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("brew") or event.is_action_pressed("ui_cancel"):
		close()
