class_name PauseMenu
extends CanvasLayer
## The Esc pause menu (spec 025): Resume / Save / Load / Quit to Title, on the
## JournalPanel pause-lifecycle. Save and Load open a SaveLoadPanel sub-panel;
## a load hands off to Game.load_game and closes the menu; Quit to Title swaps to
## the title screen. (Settings joins in commit 6.) Owned by the Player.

signal closed

const SAVE_LOAD_SCENE := preload("res://scenes/ui/save_load_panel.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")

var _slots: SaveLoadPanel = null
var _settings: SettingsPanel = null

@onready var dim: ColorRect = $Dim
@onready var resume_button: Button = $Dim/Panel/Layout/Resume
@onready var save_button: Button = $Dim/Panel/Layout/Save
@onready var load_button: Button = $Dim/Panel/Layout/Load
@onready var settings_button: Button = $Dim/Panel/Layout/Settings
@onready var quit_button: Button = $Dim/Panel/Layout/QuitToTitle


func _ready() -> void:
	resume_button.pressed.connect(close)
	save_button.pressed.connect(open_slots.bind(SaveLoadPanel.Mode.SAVE))
	load_button.pressed.connect(open_slots.bind(SaveLoadPanel.Mode.LOAD))
	settings_button.pressed.connect(open_settings)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the menu — but only when no sub-panel is up (they consume their own).
	if event.is_action_pressed("ui_cancel") and _slots == null and _settings == null:
		close()


func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Opens the save/load slot sub-panel in the given mode (spec 025). Idempotent
## while one is up. A load routes through _on_load_requested.
func open_slots(mode: SaveLoadPanel.Mode) -> void:
	if _slots != null:
		return
	dim.hide()  # the sub-panel is a translucent overlay; hide our menu behind it
	_slots = SAVE_LOAD_SCENE.instantiate()
	add_child(_slots)
	_slots.closed.connect(_on_slots_closed)
	_slots.load_requested.connect(_on_load_requested)
	_slots.open(mode)


func _on_slots_closed() -> void:
	_slots = null
	dim.show()


## Opens the settings sub-panel (spec 025). Idempotent while one is up.
func open_settings() -> void:
	if _settings != null:
		return
	dim.hide()  # the sub-panel is a translucent overlay; hide our menu behind it
	_settings = SETTINGS_SCENE.instantiate()
	add_child(_settings)
	_settings.closed.connect(_on_settings_closed)
	_settings.open()


func _on_settings_closed() -> void:
	_settings = null
	dim.show()


## A slot was chosen to load: hand off to Game (it defers the scene swap) and
## close the menu so the tree unpauses before the swap applies.
func _on_load_requested(slot_id: StringName) -> void:
	Game.load_game(slot_id)
	close()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.quit_to_title()
	closed.emit()
	queue_free()
