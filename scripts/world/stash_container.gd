class_name StashContainer
extends StaticBody3D
## The one sanctioned player bank (spec 016): a world chest whose contents ARE
## Game.stash — the persistent, Game-owned Inventory serialized with the save.
## Opens a deposit-capable ContainerPanel (take + deposit).
##
## Reading Game.stash here is the narrow, spec-sanctioned Game access: this node
## is the stash's designated world anchor (the save/load-UI precedent of a
## system calling into Game), not the ambient Game grab the CLAUDE.md access
## rule forbids. Exactly one node in the world binds the stash.

const PANEL_SCENE := preload("res://scenes/ui/container_panel.tscn")

@export var display_name := "Stash"

var _panel: ContainerPanel = null

@onready var interactable: Interactable = $Interactable


## Before the child Interactable's _ready assert: prompt name per instance.
func _enter_tree() -> void:
	($Interactable as Interactable).display_name = display_name


func _ready() -> void:
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
	_panel.open(Game.stash, player.inventory_component, display_name, true)


func _on_panel_closed() -> void:
	_panel = null
