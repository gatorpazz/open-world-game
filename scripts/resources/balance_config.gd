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
