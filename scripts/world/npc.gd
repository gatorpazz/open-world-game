class_name Npc
extends StaticBody3D
## A stationary, def-driven dialogue NPC (spec 005) — one scene, many
## NPCDefs, like creature.tscn. Replaces spec 003's TalkStub: the
## Interactable wiring ("talk" verb) is unchanged, the guts now open the
## dialogue panel. The consumer-less talk_requested signal is gone (003
## amendment) — like WorldContainer, the NPC owns and opens its own panel.

const PANEL_SCENE := preload("res://scenes/ui/dialogue_panel.tscn")

@export var def: NPCDef

var _panel: DialoguePanel = null

@onready var interactable: Interactable = $Interactable


## Before the child Interactable's _ready assert: prompt name per instance.
func _enter_tree() -> void:
	if def != null:
		($Interactable as Interactable).display_name = def.display_name


func _ready() -> void:
	assert(def != null, "Npc needs an NPCDef")
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
	_panel.open(def, player.journal, player.inventory_component)


func _on_panel_closed() -> void:
	_panel = null
