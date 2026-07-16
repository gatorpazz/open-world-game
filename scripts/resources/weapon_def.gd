class_name WeaponDef
extends ItemDef
## A weapon. Equips to main_hand; two-handed weapons also block off_hand.
## Never stackable.

@export var damage: int = 0
## Must be a combat-archetype skill id from data/skills/.
@export var skill_id: StringName
@export var two_handed: bool = false
