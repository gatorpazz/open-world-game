class_name BoundWorkingDef
extends Resource
## A hand-authored bound working (spec 023): the regard a worked object holds,
## released as a standing charm (constant), a weapon's discharge (on_hit), or a
## triggered charge (on_use). No dynamic crafting — content lives in
## data/bound_workings/*.tres; this script defines the shape. Effect dispatch
## keys on trigger + effect; magnitude scales on the aspect skill_id (008's
## spell_power) or is flat for an unscaled hearth-charm (empty skill_id).

## The three hooks a working fires through.
const TRIGGERS: Array[StringName] = [&"constant", &"on_hit", &"on_use"]
## What a working does. damage is outward (into a struck target); heal is the
## ratified give-back; fortify/ward/resist are the standing/defensive charms.
const EFFECTS: Array[StringName] = [&"damage", &"heal", &"fortify", &"ward", &"resist"]

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## constant / on_hit / on_use (one of TRIGGERS).
@export var trigger: StringName
## damage / heal / fortify / ward / resist (one of EFFECTS).
@export var effect: StringName
## The aspect school the magnitude scales on (evocation/mending/warding). Empty
## = an unscaled hearth-charm (flat magnitude — a blessing-mark).
@export var skill_id: StringName = &""
## Base effect amount, before aspect-skill scaling.
@export var magnitude: float = 0.0
## Ward lifetime in seconds; 0 = instant / constant.
@export var duration: float = 0.0
## The skill a `fortify` charm lifts; empty for every other effect.
@export var subject: StringName = &""
