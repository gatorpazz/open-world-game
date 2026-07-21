class_name CombatMath
extends RefCounted
## Pure combat formulas (spec 004). Static, no scene-tree or signal
## dependencies — fully unit-testable, mirroring CharacterSheet's pattern.
## Every constant comes from the BalanceConfig passed in, never hardcoded.


## Outcome of resolve_defense: what got through, and whether a block fired.
class DefenseResult:
	var final_damage: float = 0.0
	var blocked: bool = false


## Raw melee damage for a player swing, before the defender's mitigation.
## Creatures skip this entirely and deal flat CreatureDef.damage.
static func attack_damage(
	weapon_damage: int, skill: int, strength: int, exhausted: bool, cfg: BalanceConfig
) -> float:
	var skill_mult := lerpf(cfg.damage_skill_min, cfg.damage_skill_max, skill / 100.0)
	var strength_mult := cfg.damage_strength_base + strength * cfg.damage_per_strength
	var exhausted_mult := cfg.exhausted_damage_multiplier if exhausted else 1.0
	return weapon_damage * skill_mult * strength_mult * exhausted_mult


## Stamina cost of one swing with a weapon of the given weight.
static func stamina_cost(weapon_weight: float, cfg: BalanceConfig) -> float:
	return cfg.attack_stamina_base + weapon_weight * cfg.attack_stamina_per_weight


## Passive block chance for the given Block skill level, clamped to [0, 1].
static func block_chance(block_skill: int, cfg: BalanceConfig) -> float:
	return clampf(cfg.block_chance_base + block_skill * cfg.block_chance_per_skill, 0.0, 1.0)


## Damage remaining after the armor curve: AR / (AR + scale) is removed.
## Never negative, diminishing returns — no min-damage clamp needed.
static func armor_mitigation(damage: float, armor_rating: int, cfg: BalanceConfig) -> float:
	return damage * (1.0 - armor_rating / (armor_rating + cfg.armor_mitigation_scale))


## Scaled power of a working (spec 008): damage, heal, or ward absorb.
## The melee lerp shape with no attribute term — intellect already sizes
## the mana pool.
static func spell_power(magnitude: float, skill: int, cfg: BalanceConfig) -> float:
	return magnitude * lerpf(cfg.magic_skill_min, cfg.magic_skill_max, skill / 100.0)


## Amount a ward pool soaks from an incoming hit (spec 008): min of the
## two. Applied after resolve_defense, before health — the caller drains
## the pool and passes the remainder on.
static func ward_absorb(damage: float, ward: float) -> float:
	return minf(damage, ward)


## Resolves an incoming hit for a defender: passive block first (only with a
## shield equipped), then armor. The block roll is injected so tests are
## deterministic — gameplay callers pass randf().
static func resolve_defense(
	raw_damage: float,
	armor_rating: int,
	has_shield: bool,
	block_skill: int,
	roll: float,
	cfg: BalanceConfig,
) -> DefenseResult:
	var result := DefenseResult.new()
	var damage := raw_damage
	if has_shield and roll < block_chance(block_skill, cfg):
		result.blocked = true
		damage *= cfg.block_damage_multiplier
	result.final_damage = armor_mitigation(damage, armor_rating, cfg)
	return result
