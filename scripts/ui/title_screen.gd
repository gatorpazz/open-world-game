class_name TitleScreen
extends Control
## Boot scene (spec 009): New Game / Continue / Quit over the hidden
## creation form. Deliberately carries no spawn marker, so Game._ready's
## boot adoption stays inert here; the world is only entered through
## Game.start_new_game or Game.load_game. Chrome text only — any future
## flavor prose goes through the canon packet (spec 011).

const SAVE_UNREADABLE := "The save file could not be read."

@onready var title_column: VBoxContainer = %TitleColumn
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var quit_button: Button = %QuitButton
@onready var notice_label: Label = %NoticeLabel
@onready var creation_form: CreationForm = %CreationForm


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	creation_form.confirmed.connect(_on_creation_confirmed)
	creation_form.cancelled.connect(_show_title)
	_show_title()


## Shows the title column, hiding the form and any stale notice; Continue
## re-checks the save file every time the column returns.
func _show_title() -> void:
	creation_form.hide()
	notice_label.hide()
	title_column.show()
	continue_button.disabled = not Game.has_save()


func _on_new_game_pressed() -> void:
	title_column.hide()
	creation_form.show()


func _on_continue_pressed() -> void:
	# Decode-before-touch (007): a corrupt file returns false with Game
	# untouched, so the title simply stays up with a notice.
	if not Game.load_game():
		notice_label.text = SAVE_UNREADABLE
		notice_label.show()


func _on_creation_confirmed(sheet: CharacterSheet) -> void:
	Game.start_new_game(sheet)


func _on_quit_pressed() -> void:
	get_tree().quit()
