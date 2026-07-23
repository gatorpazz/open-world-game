class_name BalanceConfig
extends Resource
## Every tunable number in the stats system. The one true source of values
## is data/balance/balance_config.tres — scripts must never hardcode these.

@export_group("Skill Progression")
@export var skill_xp_base: int = 15
@export var skill_xp_per_level: int = 3
@export var skill_start_minor: int = 5
@export var skill_start_major: int = 25
@export var skill_max: int = 100

@export_group("Character Level")
@export var level_up_threshold: int = 10
@export var attribute_points_per_level: int = 3

@export_group("Attributes")
@export var attribute_start: int = 30
## Starting value of the one attribute favored at character creation (009).
@export var attribute_favored_start: int = 40
@export var attribute_max: int = 100

@export_group("Derived Stats")
@export var health_base: float = 20.0
@export var health_per_endurance: float = 1.5
@export var mana_per_intellect: float = 1.5
@export var stamina_factor: float = 0.5
@export var carry_per_strength: float = 4.0

@export_group("Movement")
@export var encumbered_speed_multiplier: float = 0.25

@export_group("Interaction")
@export var interact_range: float = 2.5

@export_group("Combat")
## Weapon-skill damage multiplier endpoints at skill 0 and 100.
@export var damage_skill_min: float = 0.5
@export var damage_skill_max: float = 1.5
## Strength damage multiplier: base + strength * per_strength.
@export var damage_strength_base: float = 0.5
@export var damage_per_strength: float = 0.01
## Swing stamina cost: base + weapon.weight * per_weight.
@export var attack_stamina_base: float = 5.0
@export var attack_stamina_per_weight: float = 0.5
## Swing damage multiplier when stamina is below the swing cost.
@export var exhausted_damage_multiplier: float = 0.5
@export var stamina_regen_per_second: float = 8.0
## Armor reduction: AR / (AR + scale) of incoming damage is removed.
@export var armor_mitigation_scale: float = 50.0
## Passive block: chance = base + block_skill * per_skill, clamped to [0, 1].
@export var block_chance_base: float = 0.1
@export var block_chance_per_skill: float = 0.003
## Fraction of damage kept when a hit is blocked (before armor).
@export var block_damage_multiplier: float = 0.5
@export var melee_sweep_radius: float = 0.4
@export var xp_per_weapon_hit: int = 5
@export var xp_per_block: int = 5
@export var xp_per_armor_hit: int = 2

@export_group("Magic")
## Magic-skill power multiplier endpoints at skill 0 and 100.
@export var magic_skill_min: float = 0.5
@export var magic_skill_max: float = 1.5
@export var mana_regen_per_second: float = 1.0
@export var spell_sweep_radius: float = 0.3
@export var xp_per_cast: int = 5

@export_group("Notice")
## Casting an unlicensed working (spec 018) draws this much notice each time;
## notice never clears. At or past overcast_threshold the caster is overcast —
## permanently remarkable. A witnessed unlicensed working also draws a warden
## fine (unlicensed_working_fine) into the bounty ledger; the reputation dock
## reuses crime_reputation_dock (an offense is an offense).
@export var notice_per_unlicensed_working: int = 10
@export var overcast_threshold: int = 100
@export var unlicensed_working_fine: int = 15

@export_group("Time")
## The real-time clock (spec 020). A day is bells_per_day bells; a circuit is
## circuit_length days (canon: 9). One bell passes every real_seconds_per_bell
## seconds of play. Resting restores rest_heal_per_bell health+stamina per bell.
@export var bells_per_day: int = 12
@export var circuit_length: int = 9
@export var real_seconds_per_bell: float = 30.0
@export var rest_heal_per_bell: float = 8.0
## How many bells a single rest passes (a full restful span; v1 has no duration
## picker).
@export var rest_bells: int = 8

@export_group("Alchemy")
## Brewing (spec 022). A brew yields output_count + alchemy_skill /
## yield_skill_step draughts (skill scales quantity — potency is fixed by the
## ConsumableDef). Ingredient inspection reveals base_discovery effects at skill
## 0, +1 per discovery_step of skill. A brew grants xp_per_brew alchemy xp.
@export var alchemy_yield_skill_step: int = 25
@export var alchemy_base_discovery: int = 1
@export var alchemy_discovery_step: int = 20
@export var xp_per_brew: int = 5

@export_group("Economy")
## Barter price spread (spec 016). The player buys at base_value * markup and
## sells at base_value * fraction; fraction < markup guarantees sell <= buy —
## the merchant margin. A regional price_multiplier and (spec 019) a persuasion
## factor scale both ends; neither lives here (per-def / per-attempt).
@export var barter_buy_markup: float = 1.5
@export var barter_sell_fraction: float = 0.5

@export_group("Crime")
## Sneak detection (spec 017). Deterministic: an observer sees an actor within
## detection_radius with clear LOS. Skill and crouch shrink the radius — a
## skilled crouched thief works inside a smaller circle. No RNG (locks roll,
## sneak is fixed — the director ruling).
@export var sneak_base_detection_radius: float = 12.0
@export var sneak_crouch_factor: float = 0.5
## Radius-scaling skill endpoints: at sneak_skill_min the radius is full, at
## sneak_skill_max it is multiplied by sneak_skilled_radius_factor.
@export var sneak_skill_min: int = 5
@export var sneak_skill_max: int = 100
@export var sneak_skilled_radius_factor: float = 0.3
## Crouch move-speed multiplier (feeds Player.get_speed_multiplier).
@export var sneak_move_factor: float = 0.5
## Lockpicking (spec 017, rebalanced). pick_chance = 1 - difficulty / (security +
## base_competence): a lock at or below your reach opens reliably, one above it
## falls off fast, one beyond your reach entirely (difficulty ≥ security +
## competence) can't be forced at all. base_competence is the floor of skill a
## novice brings — it lets security 5 open an easy (difficulty ≤ ~10) lock most
## tries, while a difficulty-30+ lock still needs training. The caller rolls
## randf() < chance.
@export var lock_base_competence: int = 25
## Theft economics (spec 017). Bounty per stolen base_value; the fine charged
## per bounty (the 019 seam, pinned 1.0); reputation lost per witnessed theft.
@export var theft_bounty_multiplier: float = 1.0
@export var fine_multiplier: float = 1.0
@export var crime_reputation_dock: int = 5

@export_group("Creatures")
@export var creature_wander_speed_multiplier: float = 0.4
@export var creature_wander_radius: float = 5.0
@export var creature_idle_time_min: float = 1.0
@export var creature_idle_time_max: float = 4.0
