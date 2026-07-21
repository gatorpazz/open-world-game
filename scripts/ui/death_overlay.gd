class_name DeathOverlay
extends Control
## "You died" overlay (spec 004, amended by 007). Pauses the tree and
## releases the mouse; the button loads the last save, closing 004's
## stated caveat. When no save exists (or the file is corrupt) it falls
## back to re-entering the current scene through Game — the original 004
## behavior: identity survives, health re-derives full, world resets.

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
	if not Game.load_game():
		Game.reload_current_scene()
