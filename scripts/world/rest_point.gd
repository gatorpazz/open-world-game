class_name RestPoint
extends StaticBody3D
## A bed (spec 020): interacting rests the player — passes a restful span and
## heals — the settlement rest path (wilderness rest needs the open, via the
## rest key). Blocked by nearby danger. The StashContainer world-station pattern.

@export var display_name := "Bed"

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
	if player.hostiles_near():
		player.show_notice(HudNotice.REST_ENEMIES_NEAR)
		return
	player.rest()
