extends GutTest
## The journal input action and JournalPanel (spec 005, criterion 8).
## Panel methods are driven directly; mouse-mode transitions are not
## asserted (headless runs cannot capture the mouse).

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	get_tree().paused = false


func test_journal_action_is_mapped() -> void:
	assert_true(InputMap.has_action(&"journal"), "the journal input action exists")


func test_open_shows_entries_in_chronological_order_with_resolved_text() -> void:
	_player.journal.add_entry(&"heard_of_the_stair")
	_player.journal.add_entry(&"hounds_near_the_covers")
	_player.open_journal()
	var panel := _player._journal_panel
	assert_not_null(panel)
	assert_true(get_tree().paused, "the journal pauses the tree")
	var text := panel.entries_label.get_parsed_text()
	assert_string_contains(text, "Entry 1")
	assert_string_contains(text, "Entry 2")
	var stair_at := text.find("old stairs at the bottom of the Scar")
	var hounds_at := text.find("ranging closer to the covers")
	assert_gt(stair_at, -1, "first entry's def text is rendered")
	assert_gt(hounds_at, -1, "second entry's def text is rendered")
	assert_lt(stair_at, hounds_at, "entries render in chronological order")


func test_empty_journal_shows_placeholder() -> void:
	_player.open_journal()
	assert_string_contains(
		_player._journal_panel.entries_label.get_parsed_text(), "The journal is empty."
	)


func test_close_button_unpauses_and_frees() -> void:
	_player.open_journal()
	var panel := _player._journal_panel
	watch_signals(panel)
	panel.close()
	assert_false(get_tree().paused, "close unpauses")
	assert_signal_emitted(panel, "closed")
	await wait_process_frames(1)
	assert_null(_player._journal_panel, "the player forgets the freed panel")


func test_journal_action_closes_the_open_panel() -> void:
	_player.open_journal()
	var panel := _player._journal_panel
	var press := InputEventAction.new()
	press.action = &"journal"
	press.pressed = true
	panel._unhandled_input(press)
	assert_false(get_tree().paused, "pressing J again closes the panel")


func test_open_while_open_is_noop() -> void:
	_player.open_journal()
	var panel := _player._journal_panel
	_player.open_journal()
	assert_eq(_player._journal_panel, panel, "a second open does not stack panels")
