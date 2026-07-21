class_name SkillDef
extends Resource
## Definition of a single skill. Content lives in data/skills/*.tres;
## this script only defines the shape.

## The archetype vocabulary (spec 001): every skill belongs to exactly one.
## The one canonical list — the data validator and the creation form's
## picker columns both read it.
const ARCHETYPES: Array[StringName] = [&"combat", &"magic", &"stealth"]

@export var id: StringName
@export var display_name: String
@export var governing_attribute: StringName
@export var archetype: StringName
@export_multiline var description: String
