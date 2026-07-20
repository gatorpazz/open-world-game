class_name JournalGate
extends Node3D
## Load-time conditional world content (spec 006): this node's children ARE
## the conditional subtree. At _ready the gate evaluates its journal
## conditions and frees itself — children and all — when they fail. Free,
## don't hide: a hidden StaticBody still collides, and "the rubble is gone"
## must mean gone. Evaluation is load-time only (the cell-reload model);
## a changed journal shows on next scene entry.
##
## Reads Game.journal — sanctioned by spec 006 (gates run during world
## _ready, before spawn_player, so there is no player to inject from; the
## Creature/Game.player precedent). journal_override injects for tests.

## All must be held for the subtree to stay.
@export var requires_journal: Array[StringName] = []
## None may be held.
@export var blocked_by_journal: Array[StringName] = []

var journal_override: Journal = null


func _ready() -> void:
	var journal := _resolve_journal()
	if journal == null:
		push_warning("JournalGate found no journal source; keeping the subtree")
		return
	if not _conditions_pass(journal):
		queue_free()


func _resolve_journal() -> Journal:
	if journal_override != null:
		return journal_override
	return Game.journal


func _conditions_pass(journal: Journal) -> bool:
	for entry: StringName in requires_journal:
		if not journal.has_entry(entry):
			return false
	for entry: StringName in blocked_by_journal:
		if journal.has_entry(entry):
			return false
	return true
