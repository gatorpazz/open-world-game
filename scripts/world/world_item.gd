class_name WorldItem
extends StaticBody3D
## A takeable item lying in the world. Interacting adds it to the player's
## inventory and frees this node. Placeholder mesh; per-item meshes later.

@export var item: ItemDef
@export var count: int = 1
## Optional quest hook (spec 006): journal entry added on pickup — the
## "concrete item or document" trigger. Empty = no journal effect.
@export var journal_entry: StringName = &""
## Owner (spec 017): non-empty means taking this is theft (flagged stolen, and
## bounty if witnessed). Empty = free for the taking. Dropped items stay empty.
@export var owner_faction: StringName = &""

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
	Theft.acquire(player, player.inventory_component, item, count, owner_faction)
	if journal_entry != &"" and player.journal.add_entry(journal_entry):
		player.show_notice(HudNotice.JOURNAL_UPDATED)
	queue_free()
