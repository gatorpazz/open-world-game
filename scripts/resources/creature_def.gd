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
## False = ambient (spec 024): the creature never aggros — it drifts and ignores
## the player (the hush-moths niche), and never joins the runtime &"hostile"
## group. Named apart from that group (disposition, not current state). Every
## existing creature is aggressive by default.
@export var aggressive: bool = true
## Flat raw melee damage per hit.
@export var damage: int = 1
## Flat armor rating against incoming damage.
@export var armor: int = 0
@export var attack_reach: float = 1.5
## Ranged attack distance (spec 024): 0 = melee only (closes to attack_reach);
## > 0 = a spitter that attacks from up to this range with a hitscan spit
## (LOS-gated, the player-bolt shape). When set, should be >= attack_reach.
@export var attack_range: float = 0.0
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
