class_name WorldItem
extends StaticBody3D
## A takeable item lying in the world. Interacting adds it to the player's
## inventory and frees this node. Placeholder mesh; per-item meshes later.

@export var item: ItemDef
@export var count: int = 1

@onready var interactable: Interactable = $Interactable


## Before the child Interactable's _ready assert: prompt name comes from data.
func _enter_tree() -> void:
	if item != null:
		($Interactable as Interactable).display_name = item.display_name


func _ready() -> void:
	assert(item != null, "WorldItem needs an ItemDef")
	assert(count > 0, "WorldItem count must be positive")
	interactable.interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null:
		return
	player.inventory_component.add_item(item, count)
	queue_free()
