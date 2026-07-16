class_name WorldContainer
extends StaticBody3D
## A lootable container. Owns its own Inventory resource (002 reuse),
## authored in-editor with resource_local_to_scene so instances don't share
## stacks. Take-only in v1; depositing comes with the real inventory UI.
## NOTE: gold in containers is out of scope until barter (Phase 2).
##
## Named WorldContainer, not Container: Godot reserves Container for its
## built-in GUI class (spec 003 amendment).

const PANEL_SCENE := preload("res://scenes/ui/container_panel.tscn")

@export var inventory: Inventory

@onready var interactable: Interactable = $Interactable

var _panel: ContainerPanel = null


func _ready() -> void:
	if inventory == null:
		inventory = Inventory.new()
	interactable.interacted.connect(_on_interacted)


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null:
		return
	if _panel != null:
		return
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	_panel.closed.connect(_on_panel_closed)
	_panel.open(inventory, player.inventory_component, interactable.display_name)


func _on_panel_closed() -> void:
	_panel = null
