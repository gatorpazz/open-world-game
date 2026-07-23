class_name RecipeLibrary
extends RefCounted
## Loads every RecipeDef in data/recipes/ into an id-keyed map (spec 022) — the
## ItemLibrary/MerchantLibrary/SpellLibrary pattern: lazy, cached, reset() for
## tests.

const DIR := "res://data/recipes"

static var _recipes: Dictionary[StringName, RecipeDef] = {}


static func get_recipes() -> Dictionary[StringName, RecipeDef]:
	if _recipes.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var recipe := load(DIR.path_join(file_name)) as RecipeDef
			if recipe != null:
				_recipes[recipe.id] = recipe
	return _recipes


static func reset() -> void:
	_recipes.clear()
