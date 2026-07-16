class_name TalkStub
extends StaticBody3D
## Placeholder NPC: emits talk_requested and prints a canned line. Spec 005
## (dialogue) replaces the guts, not the wiring.

signal talk_requested(npc_name: String)

@export var npc_name: String = ""

@onready var interactable: Interactable = $Interactable


## Before the child Interactable's _ready assert: prompt name is the NPC's.
func _enter_tree() -> void:
	if not npc_name.is_empty():
		($Interactable as Interactable).display_name = npc_name


func _ready() -> void:
	assert(not npc_name.is_empty(), "TalkStub needs an npc_name")
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_by: Node) -> void:
	talk_requested.emit(npc_name)
	print("%s: \"Greetings, outlander.\"" % npc_name)
