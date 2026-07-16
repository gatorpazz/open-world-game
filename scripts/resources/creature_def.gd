class_name CreatureDef
extends Resource
## Definition of a single creature (spec 004). Content lives in
## data/creatures/*.tres; this script only defines the shape.
##
## Creatures are deliberately NOT characters: flat damage, flat armor,
## no skills, no xp. If a future spec needs humanoid NPCs fighting with
## real equipment, that is a new decision — don't grow this one silently.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var max_health: float = 1.0
## Flat raw melee damage per hit.
@export var damage: int = 1
## Flat armor rating against incoming damage.
@export var armor: int = 0
@export var attack_reach: float = 1.5
## Seconds between hits.
@export var attack_cooldown: float = 1.5
## Chase speed; wandering uses BalanceConfig.creature_wander_speed_multiplier.
@export var move_speed: float = 4.0
## Aggro range in meters; requires line of sight.
@export var detect_radius: float = 10.0
## Give-up-chase distance from home; must be >= detect_radius.
@export var leash_radius: float = 16.0
## Hand-authored drops, left in a "<name> Remains" container on death.
@export var loot: Array[ItemStack] = []
