# Spec 001 — Character Stats System

**Status:** ready to implement
**Depends on:** nothing (first system)
**Why first:** every other system (combat, magic, dialogue, economy, guilds) reads from or writes to the character sheet. This is the spine.

## Scope

**In:** attributes, skills, use-based skill progression, character levels, derived stats, a debug scene, full test coverage.
**Out (later specs):** UI beyond the debug scene, races, birthsign-style perks, combat, save/load to disk, status effects, Morrowind-style governed-attribute level bonuses.

## Design

### Attributes (7)

`strength, endurance, agility, speed, intellect, willpower, presence` — integers, range 1–100, default starting value 30 (40 in one attribute of the player's choice at character creation; creation flow itself is a later spec, so for now the debug scene just sets values). *(Amended, 009: the creation flow now exists — title screen + creation form; the favored value lives in `BalanceConfig.attribute_favored_start`. The debug scene remains the value-poking tool.)*

### Skills (12)

Integers 1–100. Non-major skills start at 5; major skills start at 25. Each skill is a `SkillDef` resource in `data/skills/`:

| id | display name | governing attribute | archetype |
|---|---|---|---|
| blades | Blades | strength | combat |
| ranged | Ranged | agility | combat |
| block | Block | endurance | combat |
| heavy_armor | Heavy Armor | endurance | combat |
| evocation | Evocation | intellect | magic |
| mending | Mending | willpower | magic |
| warding | Warding | willpower | magic |
| alchemy | Alchemy | intellect | magic |
| sneak | Sneak | agility | stealth |
| security | Security | intellect | stealth |
| light_armor | Light Armor | speed | stealth |
| persuasion | Persuasion | presence | stealth |

Governing attributes do nothing yet — store the reference now, use it in a later spec.

### Skill progression (use-based)

- Systems call `gain_skill_xp(skill_id, amount)` when a skill is used.
- XP required for a skill's next level: `skill_xp_base + skill_xp_per_level * current_level` (defaults 15 and 3).
- On reaching the requirement: subtract it, increment the skill, carry over remainder, emit `skill_leveled`. Handle multi-level gains from one large xp grant.
- Skills cap at 100; xp beyond the cap is discarded.

### Character level

- The sheet has `major_skills: Array[StringName]` — exactly 5 skill ids.
- Each level-up of a *major* skill increments a counter. At `level_up_threshold` (default 10): reset the counter (carry remainder), increment character level, grant `attribute_points_per_level` (default 3) unspent attribute points, emit `leveled_up`.
- `spend_attribute_point(attribute)` decrements the pool and raises the attribute (respect the 100 cap; refuse and return false if capped or pool is empty).

### Derived stats — always computed, never stored

Recompute (and emit changed signals) whenever an input attribute changes. Deliberate simplification vs. Morrowind: no permanent accrual, so there is no retroactive-bonus weirdness — respec-friendly by construction.

- `max_health = health_base + endurance * health_per_endurance` (defaults 20, 1.5)
- `max_mana = intellect * mana_per_intellect` (default 1.5)
- `max_stamina = (strength + endurance + agility + speed) * stamina_factor` (default 0.5)
- `carry_capacity = strength * carry_per_strength` (default 4.0)

Current health/mana/stamina are floats clamped to [0, max]; when a max drops below current, clamp current down.

## Architecture

| file | type | role |
|---|---|---|
| `scripts/resources/skill_def.gd` | `SkillDef extends Resource` | `id: StringName`, `display_name: String`, `governing_attribute: StringName`, `archetype: StringName`, `description: String` |
| `scripts/resources/balance_config.gd` | `BalanceConfig extends Resource` | every constant named above, `@export`ed |
| `scripts/resources/character_sheet.gd` | `CharacterSheet extends Resource` | pure data + pure logic: attributes, skills, xp pools, major skills, level, unspent points; all rules above as methods; **no signals, no node references** — fully unit-testable |
| `scripts/systems/stats_component.gd` | `StatsComponent extends Node` | owns a `CharacterSheet`, forwards mutations, emits all signals, tracks current health/mana/stamina |
| `data/balance/balance_config.tres` | resource | the one true source of tuning values |
| `data/skills/*.tres` | resources | the 12 skills |
| `scenes/debug/stats_debug.tscn` | scene | buttons to grant xp to each skill and spend attribute points; live label dump of the full sheet |

Signals on `StatsComponent`: `skill_leveled(skill_id, new_level)`, `leveled_up(new_level)`, `attribute_changed(attribute, new_value)`, `health_changed(current, max)`, `mana_changed(current, max)`, `stamina_changed(current, max)`.

## Acceptance criteria (GUT tests)

1. Skill xp accrues; crossing the threshold levels the skill and carries remainder; one large grant can produce multiple levels; cap at 100 holds.
2. Ten major-skill level-ups trigger exactly one character level-up; non-major skills never advance the counter; remainder carries.
3. Attribute points: granted on level-up, spendable, refused when pool empty or attribute capped.
4. Derived stats match the formulas for several attribute combinations and update when attributes change; current values clamp when max drops.
5. Data validation: loading every `data/skills/*.tres` finds exactly 12, unique ids, non-empty display names, governing attributes and archetypes from the valid sets.
6. All constants read from `balance_config.tres` — changing a value in the resource changes behavior with no code edits.

## How to implement

Work in this order, one commit each: SkillDef + skill resources + validation test → BalanceConfig → CharacterSheet with tests → StatsComponent with tests → debug scene. Run the full GUT suite before each commit.
