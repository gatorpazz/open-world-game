class_name ArmorDef
extends ItemDef
## Armor, shields, and jewelry. Never stackable.

## Declared slots an armor piece may claim. &"ring" is a wildcard that
## resolves to ring_1 or ring_2 at equip time.
const VALID_SLOTS: Array[StringName] = [
	&"head", &"chest", &"legs", &"hands", &"feet",
	&"off_hand", &"ring", &"amulet",
]

@export var slot: StringName
@export var armor_rating: int = 0
## heavy_armor or light_armor; empty for jewelry (ring/amulet slots).
@export var skill_id: StringName
