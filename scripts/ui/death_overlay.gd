class_name DeathOverlay
extends Control
## "You died" overlay (spec 004). Pauses the tree and releases the mouse;
## Reload re-enters the current scene through Game. The persistent
## identity survives (xp and loot kept, health re-derived full) while
## world state resets — the stated v1 caveat; spec 007 (save/load)
## replaces this with load-last-save.

@onready var reload_button: Button = $Center/Layout/Reload


func _ready() -> void:
	reload_button.pressed.connect(_on_reload_pressed)


func open() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_reload_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.reload_current_scene()
