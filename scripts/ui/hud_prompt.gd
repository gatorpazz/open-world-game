class_name HudPrompt
extends Control
## Ugly-but-functional interaction prompt: "<verb> <display_name>".
## Hidden when there is no target.

@onready var label: Label = $Label


func set_target(target: Interactable) -> void:
	if target == null:
		hide()
		return
	label.text = target.get_prompt()
	show()
