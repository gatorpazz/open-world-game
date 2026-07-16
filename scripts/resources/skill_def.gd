class_name SkillDef
extends Resource
## Definition of a single skill. Content lives in data/skills/*.tres;
## this script only defines the shape.

@export var id: StringName
@export var display_name: String
@export var governing_attribute: StringName
@export var archetype: StringName
@export_multiline var description: String
