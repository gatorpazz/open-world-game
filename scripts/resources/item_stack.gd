class_name ItemStack
extends Resource
## One inventory entry: an item and how many of it. Non-stackable items
## always sit in stacks of count 1.

@export var item: ItemDef
@export var count: int = 1
