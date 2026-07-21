extends Node3D
## Debug scene for spec 006. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - A Small Favor: talk Suddel pelt-less (ACTIVE via the nudge), take the
##   pelt, exchange (COMPLETED) — watch the label and the Quests view (J).
## - The Skipped Name: Kellom's greeting seeds the reading and tablet law;
##   the reading joins (novice, no roll-name — ACTIVE, and the rubble pile
##   is gone next load). Ollun's extra name advances the chain; the mock
##   columns fire the trigger only once the_walkers_name is held; the
##   waxed staff appears at the columns only after the_cut_rope (gate on
##   next load), and taking it writes the_waxed_staff with a HUD notice.
## - Resolve either way: Ollun's "the kept name" (expose) or Kellom's
##   "tablet law" after Ollun frames the choice (absolve). The other path
##   stops matching — cross-blocked.
## - Outcome props (nine stones / the blank course) appear only after a
##   door round-trip: gates evaluate at load, the cell-reload model.
## - The Quests view groups Active/Completed; empty groups stay hidden.

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
	var lines: Array[String] = []
	for quest: QuestDef in QuestLibrary.get_quests().values():
		(
			lines
			. append(
				(
					"%s: %s (stage %d/%d)"
					% [
						quest.display_name,
						_status_name(QuestEvaluator.status(quest, journal)),
						QuestEvaluator.latest_stage_index(quest, journal) + 1,
						quest.stages.size(),
					]
				)
			)
		)
	lines.append("journal (%d): %s" % [journal.entries.size(), _join(journal.entries)])
	lines.append("rat pelts held: %d" % _player.inventory_component.inventory.count_of(RAT_PELT))
	debug_label.text = "\n".join(lines)


func _status_name(status: QuestEvaluator.Status) -> String:
	return QuestEvaluator.Status.keys()[status]


## Chronological — the tail of the list is the latest journal effect.
func _join(ids: Array[StringName]) -> String:
	var parts: Array[String] = []
	for id: StringName in ids:
		parts.append(String(id))
	return ", ".join(parts)
