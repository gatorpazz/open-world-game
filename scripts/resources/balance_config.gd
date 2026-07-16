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

@export_group("Creatures")
@export var creature_wander_speed_multiplier: float = 0.4
@export var creature_wander_radius: float = 5.0
@export var creature_idle_time_min: float = 1.0
@export var creature_idle_time_max: float = 4.0
