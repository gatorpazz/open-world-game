class_name HudPrompt
extends Control
## Interaction prompt: "<verb> <display_name>". Shown only during free gameplay —
## hidden when there is no target, and while a panel pauses the tree (spec 025
## fix: it must not float over an open conversation or menu; the raycast detector
## that feeds it is frozen while paused). process_mode = ALWAYS so it re-derives
## across the pause boundary.

var _target: Interactable = null
var _was_paused := false

@onready var label: Label = $Label


func _ready() -> void:
	visible = false


func set_target(target: Interactable) -> void:
	_target = target
	_refresh()


## The detector is frozen while paused, so watch the pause boundary and re-derive
## on the transition (hide when a panel opens, restore the prompt when it closes).
func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_refresh()


func _refresh() -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
	var wanted := _target != null and not get_tree().paused
	if wanted:
		label.text = _target.get_prompt()
	visible = wanted
