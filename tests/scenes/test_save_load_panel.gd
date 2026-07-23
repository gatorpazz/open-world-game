extends GutTest
## SaveLoadPanel (spec 025, acceptance criterion 6): the slot menu lists slots
## and routes its actions to Game/SaveSlots. Points Game.saves_dir at a scratch
## dir; the live SAVE-writes-a-slot path is proven in test_save_load.

const PANEL_SCENE := preload("res://scenes/ui/save_load_panel.tscn")
const DIR := "user://test_slp_saves"

var _game: Node
var _saved_dir: String
var _panel: SaveLoadPanel


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_dir = _game.saves_dir
	_game.saves_dir = DIR
	_clear()
	_panel = PANEL_SCENE.instantiate() as SaveLoadPanel
	add_child_autofree(_panel)


func after_each() -> void:
	get_tree().paused = false
	_clear()
	_game.saves_dir = _saved_dir


func _clear() -> void:
	for slot_id: StringName in SaveSlots.SLOT_IDS:
		SaveSlots.delete(DIR, slot_id)


func _fill(slot_id: StringName) -> void:
	var meta := {
		"day": 3,
		"bell": 5,
		"scene": "res://scenes/world/lastdoor.tscn",
		"level": 2,
		"playtime": 90.0,
	}
	SaveSlots.write(DIR, slot_id, meta, {"save_version": 8})


func _index_of(slot_id: StringName) -> int:
	return SaveSlots.SLOT_IDS.find(slot_id)


func test_load_mode_emits_load_requested_for_a_filled_slot() -> void:
	_fill(&"slot_1")
	_panel.open(SaveLoadPanel.Mode.LOAD)
	watch_signals(_panel)

	assert_true(_panel.primary_action(_index_of(&"slot_1")), "a filled slot loads")
	assert_signal_emitted_with_parameters(_panel, "load_requested", [&"slot_1"])


func test_load_mode_ignores_an_empty_slot() -> void:
	_panel.open(SaveLoadPanel.Mode.LOAD)
	watch_signals(_panel)

	assert_false(_panel.primary_action(_index_of(&"slot_2")), "an empty slot loads nothing")
	assert_signal_not_emitted(_panel, "load_requested")


func test_delete_clears_a_slot() -> void:
	_fill(&"slot_3")
	_panel.open(SaveLoadPanel.Mode.LOAD)

	assert_true(_panel.delete_slot(_index_of(&"slot_3")))
	assert_false(SaveSlots.exists(DIR, &"slot_3"), "the slot file is gone")


func test_row_labels_show_empty_and_metadata() -> void:
	_fill(&"slot_1")
	_panel.open(SaveLoadPanel.Mode.LOAD)

	assert_true(_panel.row_label(_index_of(&"slot_2")).contains("(empty)"), "empty slot labelled")
	var filled := _panel.row_label(_index_of(&"slot_1"))
	assert_true(filled.contains("Lastdoor"), "the place is shown")
	assert_true(filled.contains("Lv 2"), "the level is shown")


func test_save_mode_routes_to_game_save_game() -> void:
	# No live world here, so save_game guards to false — proving the SAVE branch
	# delegates to Game.save_game (the live write is covered in test_save_load).
	_game.current_world = null
	_game.player = null
	_panel.open(SaveLoadPanel.Mode.SAVE)

	assert_false(
		_panel.primary_action(_index_of(&"slot_1")), "save routes to the guarded save_game"
	)
