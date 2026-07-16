class_name CharacterSheet
extends Resource
## Pure character-sheet data and rules (spec 001): attributes, skills,
## use-based skill xp, character level, and derived stats.
## No signals and no node references — fully unit-testable. StatsComponent
## wraps this in the scene tree and emits signals.

const ATTRIBUTE_NAMES: Array[StringName] = [
	&"strength",
	&"endurance",
	&"agility",
	&"speed",
	&"intellect",
	&"willpower",
	&"presence",
]
const MAJOR_SKILL_COUNT := 5
const ATTRIBUTE_MIN := 1

@export var config: BalanceConfig
@export var attributes: Dictionary[StringName, int] = {}
@export var skills: Dictionary[StringName, int] = {}
@export var skill_xp: Dictionary[StringName, int] = {}
@export var major_skills: Array[StringName] = []
@export var level: int = 1
@export var unspent_attribute_points: int = 0
## Major-skill level-ups accrued toward the next character level.
@export var major_level_ups: int = 0


func setup(skill_ids: Array[StringName], majors: Array[StringName], balance: BalanceConfig) -> void:
	assert(
		majors.size() == MAJOR_SKILL_COUNT, "Exactly %d major skills required" % MAJOR_SKILL_COUNT
	)
	config = balance
	level = 1
	unspent_attribute_points = 0
	major_level_ups = 0
	major_skills = majors.duplicate()
	attributes.clear()
	for attribute: StringName in ATTRIBUTE_NAMES:
		attributes[attribute] = balance.attribute_start
	skills.clear()
	skill_xp.clear()
	for skill_id: StringName in skill_ids:
		var is_major := majors.has(skill_id)
		skills[skill_id] = balance.skill_start_major if is_major else balance.skill_start_minor
		skill_xp[skill_id] = 0


## XP needed to take skill_id from its current level to the next one.
func xp_required(skill_id: StringName) -> int:
	return _xp_required_at(skills[skill_id])


## Grants xp to a skill; returns how many levels it gained (0 if none).
## Handles multi-level gains from one grant, carries remainder xp,
## and discards xp beyond the skill cap. Major-skill levels advance the
## character-level counter and may raise `level` as a side effect.
func gain_skill_xp(skill_id: StringName, amount: int) -> int:
	assert(skills.has(skill_id), "Unknown skill id: %s" % skill_id)
	if amount <= 0 or skills[skill_id] >= config.skill_max:
		return 0
	var skill_level: int = skills[skill_id]
	var xp: int = skill_xp[skill_id] + amount
	var levels_gained := 0
	while skill_level < config.skill_max and xp >= _xp_required_at(skill_level):
		xp -= _xp_required_at(skill_level)
		skill_level += 1
		levels_gained += 1
	if skill_level >= config.skill_max:
		xp = 0
	skills[skill_id] = skill_level
	skill_xp[skill_id] = xp
	if levels_gained > 0 and major_skills.has(skill_id):
		_advance_major_counter(levels_gained)
	return levels_gained


## Spends one unspent point to raise an attribute by one.
## Returns false (and changes nothing) if the pool is empty or the
## attribute is at its cap.
func spend_attribute_point(attribute: StringName) -> bool:
	assert(attributes.has(attribute), "Unknown attribute: %s" % attribute)
	if unspent_attribute_points <= 0 or attributes[attribute] >= config.attribute_max:
		return false
	unspent_attribute_points -= 1
	attributes[attribute] += 1
	return true


func set_attribute(attribute: StringName, value: int) -> void:
	assert(attributes.has(attribute), "Unknown attribute: %s" % attribute)
	attributes[attribute] = clampi(value, ATTRIBUTE_MIN, config.attribute_max)


# --- Derived stats: always computed, never stored ---


func get_max_health() -> float:
	return config.health_base + attributes[&"endurance"] * config.health_per_endurance


func get_max_mana() -> float:
	return attributes[&"intellect"] * config.mana_per_intellect


func get_max_stamina() -> float:
	var physical_total: int = (
		attributes[&"strength"]
		+ attributes[&"endurance"]
		+ attributes[&"agility"]
		+ attributes[&"speed"]
	)
	return physical_total * config.stamina_factor


func get_carry_capacity() -> float:
	return attributes[&"strength"] * config.carry_per_strength


func _xp_required_at(skill_level: int) -> int:
	return config.skill_xp_base + config.skill_xp_per_level * skill_level


func _advance_major_counter(levels_gained: int) -> void:
	major_level_ups += levels_gained
	while major_level_ups >= config.level_up_threshold:
		major_level_ups -= config.level_up_threshold
		level += 1
		unspent_attribute_points += config.attribute_points_per_level
