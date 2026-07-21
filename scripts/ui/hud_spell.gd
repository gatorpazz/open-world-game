class_name HudSpell
extends Control
## Ugly-but-functional selected-spell label (spec 008), the HudPrompt
## pattern: shows the selection's display_name, hidden when nothing is
## castable.

@onready var label: Label = $Label


func set_spell(spell: SpellDef) -> void:
	if spell == null:
		hide()
		return
	label.text = spell.display_name
	show()
