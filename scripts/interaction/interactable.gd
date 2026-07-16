class_name Interactable
extends Node3D
## Generic interaction hook, added as a child of any CollisionObject3D-based
## scene. The owning root connects to `interacted` (signals up), or a subclass
## overrides `_interact()`. The detector finds this via `find_in()`.

signal interacted(by: Node)

@export var display_name: String = ""
@export var verb: StringName = &"use"


func _ready() -> void:
	assert(
		not display_name.is_empty(),
		"Interactable needs a non-empty display_name; owners with dynamic names set it in _enter_tree()."
	)


func interact(by: Node) -> void:
	_interact(by)
	interacted.emit(by)


## HUD prompt text, e.g. "Take Flawed Gem".
func get_prompt() -> String:
	return "%s %s" % [String(verb).capitalize(), display_name]


## The Interactable child of a raycast hit, or null.
static func find_in(body: Node) -> Interactable:
	for child: Node in body.get_children():
		if child is Interactable:
			return child
	return null


func _interact(_by: Node) -> void:
	pass
