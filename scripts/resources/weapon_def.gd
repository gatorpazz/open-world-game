class_name WeaponDef
extends ItemDef
## A weapon. Equips to main_hand; two-handed weapons also block off_hand.
## Never stackable.

@export var damage: int = 0
## Must be a combat-archetype skill id from data/skills/.
@export var skill_id: StringName
@export var two_handed: bool = false
## Seconds between swings (spec 004 amendment to 002).
@export var swing_time: float = 1.0
## Melee sweep length in meters; keep <= BalanceConfig.interact_range.
@export var reach: float = 2.0
