class_name ItemStack
extends Resource
## One inventory entry: an item and how many of it. Non-stackable items
## always sit in stacks of count 1.

@export var item: ItemDef
@export var count: int = 1
## True when this stack was taken from an owner (spec 017). Per-stack, not on
## ItemDef (that resource is shared across every copy in the world). A stolen
## stack never merges with a clean one, so provenance survives stacking.
@export var stolen: bool = false
