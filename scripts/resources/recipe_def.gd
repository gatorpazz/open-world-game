class_name RecipeDef
extends Resource
## A fixed brewing recipe (spec 022): exact ingredients → an existing
## ConsumableDef. Content lives in data/recipes/*.tres; this script only defines
## the shape. No dynamic crafted items (Decision Log) — output_id names a
## ConsumableDef that already ships. Alchemy skill gates whether the recipe is
## known (min_skill) and scales the yield; it never rolls a pass/fail.

@export var id: StringName
@export var display_name: String
## Required ingredients + counts (the MerchantDef.stock shape).
@export var inputs: Array[ItemStack] = []
## The ConsumableDef this brews, by id (resolved through ItemLibrary).
@export var output_id: StringName
## Base yield before the skill bonus.
@export var output_count: int = 1
## Alchemy level that unlocks the recipe (the 001 licensing tiers 0 / 25 / 50).
@export var min_skill: int = 0
