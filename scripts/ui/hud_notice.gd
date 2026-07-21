class_name HudNotice
extends VBoxContainer
## Fading notice queue on the player HUD (spec 006): brief lines for
## journal writes outside dialogue ("Your journal has been updated.").
## The dialogue panel keeps its inline transcript notices — nothing
## double-notices. Spec 007 reuses it for the quicksave notices.

const JOURNAL_UPDATED := "Your journal has been updated."
const GAME_SAVED := "Game saved."
const NO_SAVE_TO_LOAD := "No save to load."
## Spec 008 casting notices; terminology from the canon packet (a working
## draws — the pool noun stays deliberately unnamed in-world).
const CAST_FAILED := "Nothing left to draw."
const WORKING_LEARNED := "New working: %s"

## Timing is UI styling, not balance (spec 006's empty-BalanceConfig ruling).
@export var display_seconds := 3.0
@export var fade_seconds := 1.0


func show_notice(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(display_seconds)
	tween.tween_property(label, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(label.queue_free)
