extends Node3D
## Debug scene for spec 005. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - Swift and Suddel greet with their own lines; Tansy uses the fallback.
## - Keywords render highlighted; reading the greeting puts "Lastdoor"
##   and "scar-hounds" straight into the topic list.
## - "Lastdoor" mentions the drowned stair — the topic appears mid-talk.
## - Ask "the drowned stair" twice: vague answer + journal entry first,
##   the richer requires_journal answer on the second ask.
## - Suddel's "a small favor" stays hidden until the rat pelt on the floor
##   is picked up; the exchange takes the pelt, gives a healing draught,
##   and writes the journal (watch the label).
## - J opens the journal, paused, entries in order; J or Close closes it.
## - Dialogue and journal pause the game while open.
## - The purple load-door round-trips to the interior and back; the label's
##   topics and entries survive the transition.

const RAT_PELT := preload("res://data/items/rat_pelt.tres")

var _player: Player

@onready var debug_label: Label = $DebugHud/DebugLabel


func _ready() -> void:
	# Game injects the player one frame after the scene loads.
	await get_tree().process_frame
	_player = Game.player


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var journal := _player.journal
	debug_label.text = (
		"\n"
		. join(
			[
				(
					"known topics (%d): %s"
					% [journal.known_topics.size(), _join(journal.known_topics)]
				),
				"journal entries (%d): %s" % [journal.entries.size(), _join(journal.entries)],
				"rat pelts held: %d" % _player.inventory_component.inventory.count_of(RAT_PELT),
			]
		)
	)


## Discovery order — the tail of each list is the latest dialogue effect.
func _join(ids: Array[StringName]) -> String:
	var parts: Array[String] = []
	for id: StringName in ids:
		parts.append(String(id))
	return ", ".join(parts)
