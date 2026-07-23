class_name IngredientDef
extends ItemDef
## An alchemy ingredient (spec 022). A plain item until brewed — it sits in
## data/items/ like any other, so ItemLibrary/Inventory carry it for free. Its
## effects are the inspection layer only: the brewing panel reveals the first k
## as alchemy skill rises (AlchemyRules.discovered_effects), the "identify
## ingredients" fantasy. Fixed recipes carry the actual mechanics — the effects
## never pick a brew. Each tag must be one of AlchemyRules.EFFECTS.

## Ordered — inspection reveals them front-to-back as skill rises.
@export var effects: Array[StringName] = []
