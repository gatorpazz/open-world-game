class_name TransitionDoor
extends StaticBody3D
## Morrowind-style load-door: interiors are separate scenes. Interacting asks
## the Game autoload to swap scenes and spawn the player at the named marker.

@export_file("*.tscn") var target_scene: String
@export var spawn_point: StringName

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	assert(not target_scene.is_empty(), "TransitionDoor needs a target_scene")
	assert(spawn_point != &"", "TransitionDoor needs a spawn_point name")
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node) -> void:
	Game.change_scene(target_scene, spawn_point)
