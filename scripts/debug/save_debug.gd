extends Node3D
## Debug scene for spec 007. Run with F6; Game spawns the player at "default".
##
## Manual checklist:
## - Pick up the draught, let the rat land a hit, walk somewhere odd, F5
##   ("Game saved." notice, label flips to save: yes) -> move away, F9 ->
##   back at the exact spot with the saved health, draught held, and the
##   landmark entry still in the journal tail.
## - Walk the landmark ring: the trigger writes its entry once, with a HUD
##   notice; it is part of what the save carries.
## - Through the door, F5 inside, walk back out, F9 -> re-enters the
##   interior at the saved spot (cross-scene load).
## - Die to the rat with a save present -> "Load Last Save" lands at the
##   save point, not the default spawn.
## - Delete user://save.json (or F9 before ever saving: "No save to load."),
##   die -> the button degrades to the 004 default-spawn reload.
## - Open user://save.json in a text editor once: readable, tab-indented
##   JSON is part of the point.

const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")

var _player: Player

@onready var debug_label: Label = $DebugHud/DebugLabel


func _ready() -> void:
	# Game injects the player one frame after the scene loads.
	await get_tree().process_frame
	_player = Game.player


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var stats := _player.stats
	var lines: Array[String] = []
	lines.append("save file: %s" % ("yes" if Game.has_save() else "none"))
	(
		lines
		. append(
			(
				"health %.1f/%.1f  mana %.1f/%.1f  stamina %.1f/%.1f"
				% [
					stats.current_health,
					stats.sheet.get_max_health(),
					stats.current_mana,
					stats.sheet.get_max_mana(),
					stats.current_stamina,
					stats.sheet.get_max_stamina(),
				]
			)
		)
	)
	lines.append("position: %.1v" % _player.global_position)
	lines.append(
		"draughts held: %d" % _player.inventory_component.inventory.count_of(HEALING_DRAUGHT)
	)
	lines.append(
		"journal (%d): %s" % [_player.journal.entries.size(), _join(_player.journal.entries)]
	)
	debug_label.text = "\n".join(lines)


## Chronological — the tail of the list is the latest journal write.
func _join(ids: Array[StringName]) -> String:
	var parts: Array[String] = []
	for id: StringName in ids:
		parts.append(String(id))
	return ", ".join(parts)
