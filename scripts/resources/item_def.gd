class_name ItemDef
extends Resource
## Base definition shared by every item type. Content lives in
## data/items/*.tres; this script only defines the shape.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var weight: float = 0.0
@export var base_value: int = 0
@export var stackable: bool = false
@export var max_stack: int = 1
