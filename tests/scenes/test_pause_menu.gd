extends GutTest
## PauseMenu (spec 025, acceptance criterion 6): it pauses on open, resumes on
## close, and opens the SaveLoadPanel sub-panel for Save/Load. Quit-to-title's
## scene swap is playthrough-verified — a live change_scene_to_file would break
## the headless runner.

const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const DIR := "user://test_pause_saves"

var _game: Node
var _saved_dir: String
var _menu: PauseMenu


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_dir = _game.saves_dir
	_game.saves_dir = DIR
	_clear()
	_menu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child_autofree(_menu)


func after_each() -> void:
	get_tree().paused = false
	_clear()
	_game.saves_dir = _saved_dir


func _clear() -> void:
	for slot_id: StringName in SaveSlots.SLOT_IDS:
		SaveSlots.delete(DIR, slot_id)


func _sub_panel() -> SaveLoadPanel:
	for child: Node in _menu.get_children():
		if child is SaveLoadPanel:
			return child
	return null


func test_open_pauses_and_close_resumes() -> void:
	_menu.open()
	assert_true(get_tree().paused, "the pause menu pauses the tree")
	watch_signals(_menu)

	_menu.close()

	assert_false(get_tree().paused, "closing resumes")
	assert_signal_emitted(_menu, "closed")


func test_save_opens_the_slot_panel_in_save_mode() -> void:
	_menu.open()
	_menu.open_slots(SaveLoadPanel.Mode.SAVE)
	assert_not_null(_sub_panel(), "a SaveLoadPanel sub-panel opened")


func test_open_slots_is_idempotent() -> void:
	_menu.open()
	_menu.open_slots(SaveLoadPanel.Mode.LOAD)
	var first := _sub_panel()
	_menu.open_slots(SaveLoadPanel.Mode.LOAD)  # a second call is a no-op
	assert_same(_sub_panel(), first, "only one sub-panel at a time")


func test_a_load_request_closes_the_menu() -> void:
	# A non-existent slot: load_game returns false (no scene swap), then the menu
	# closes and unpauses — the safe half of the load hand-off.
	_menu.open()
	watch_signals(_menu)

	_menu._on_load_requested(&"slot_1")

	assert_false(get_tree().paused, "the menu unpaused on load")
	assert_signal_emitted(_menu, "closed")
