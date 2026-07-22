class_name TransitionDoor
extends StaticBody3D
## Morrowind-style load-door: interiors are separate scenes. Interacting asks
## the Game autoload to swap scenes and spawn the player at the named marker.

@export_file("*.tscn") var target_scene: String
@export var spawn_point: StringName
## Lock (spec 017): a locked load-door must be picked (or opened with key_id)
## before it will carry you through. Once opened it stays unlocked.
@export var locked := false
@export var lock_difficulty := 0
@export var key_id: StringName = &""

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	assert(not target_scene.is_empty(), "TransitionDoor needs a target_scene")
	assert(spawn_point != &"", "TransitionDoor needs a spawn_point name")
	interactable.interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player != null and not Lockpicking.try_open(locked, lock_difficulty, key_id, player):
		return
	locked = false
	Game.change_scene(target_scene, spawn_point)
