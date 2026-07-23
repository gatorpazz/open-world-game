class_name SpellDef
extends Resource
## A castable working (spec 008). Content lives in data/spells/*.tres;
## this script only defines the shape. Effect dispatch keys on skill_id.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Must be a magic-archetype skill id from data/skills/.
@export var skill_id: StringName
## Learning gate: castable once the school skill reaches this. v1 data
## uses only the licensing tiers 0 / 25 / 50 (the_workings).
@export var min_skill: int = 0
## The aspect order that charters this working (spec 018): flame_order /
## stone_order / tide_order. Empty = hearth-charm (free, license-free). By
## invariant, empty iff min_skill == 0 — every chartered/ordained working names
## its order. Casting it without that charter is unlicensed (draws notice).
@export var license_order: StringName = &""
@export var mana_cost: float = 0.0
## Damage / heal / absorb amount before skill scaling.
@export var magnitude: float = 0.0
## Ward lifetime in seconds; > 0 only for warding spells in v1.
@export var duration: float = 0.0
## Bolt range in meters; > 0 only for evocation spells, 0 = self-target.
## (Named cast_range so it never shadows GDScript's range().)
@export var cast_range: float = 0.0
## Seconds between casts (the swing_time analog).
@export var cast_time: float = 1.0
