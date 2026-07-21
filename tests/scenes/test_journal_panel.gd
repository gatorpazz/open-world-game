extends GutTest
## The journal input action and JournalPanel (spec 005 criterion 8; the
## Quests view is spec 006 criterion 8).
## Panel methods are driven directly; mouse-mode transitions are not
## asserted (headless runs cannot capture the mouse).

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _player: Player


func before_each() -> void:
	QuestLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	get_tree().paused = false
	QuestLibrary.reset()


func _open_quests_view() -> JournalPanel:
	_player.open_journal()
	var panel: JournalPanel = _player._journal_panel
	panel.set_view(JournalPanel.View.QUESTS)
	return panel


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


# --- the Quests view (spec 006, criterion 8) ---


func test_quests_view_groups_active_and_hides_empty_groups() -> void:
	_player.journal.add_entry(&"suddel_wants_a_pelt")
	var panel := _open_quests_view()
	var text := panel.entries_label.get_parsed_text()
	assert_string_contains(text, "Active")
	assert_string_contains(text, "A Small Favor")
	assert_string_contains(text, "wants a vault-rat pelt", "the reached offer stage renders")
	assert_eq(text.find("Completed"), -1, "empty groups are hidden")
	assert_eq(text.find("Failed"), -1, "empty groups are hidden")


func test_quests_view_completed_group_in_stage_order() -> void:
	_player.journal.add_entry(&"suddel_wants_a_pelt")
	_player.journal.add_entry(&"suddels_stores_favor")
	var panel := _open_quests_view()
	var text := panel.entries_label.get_parsed_text()
	assert_string_contains(text, "Completed")
	assert_eq(text.find("Active"), -1, "a completed quest leaves the Active group")
	var offer_at := text.find("wants a vault-rat pelt")
	var done_at := text.find("brought Suddel the rat pelt")
	assert_gt(offer_at, -1)
	assert_gt(done_at, -1)
	assert_lt(offer_at, done_at, "reached stages render in stage order")


func test_quests_view_empty_message() -> void:
	var panel := _open_quests_view()
	assert_string_contains(panel.entries_label.get_parsed_text(), "No quests yet.")


func test_toggle_back_restores_the_chronicle_unchanged() -> void:
	_player.journal.add_entry(&"heard_of_the_stair")
	_player.open_journal()
	var panel: JournalPanel = _player._journal_panel
	var chronicle_before := panel.entries_label.get_parsed_text()
	panel.set_view(JournalPanel.View.QUESTS)
	panel.set_view(JournalPanel.View.CHRONICLE)
	assert_eq(
		panel.entries_label.get_parsed_text(),
		chronicle_before,
		"the Chronicle render is unchanged by the toggle"
	)


func test_view_buttons_mark_the_active_view() -> void:
	_player.open_journal()
	var panel: JournalPanel = _player._journal_panel
	assert_true(panel.chronicle_button.disabled, "Chronicle is the opening view")
	assert_false(panel.quests_button.disabled)
	panel.set_view(JournalPanel.View.QUESTS)
	assert_true(panel.quests_button.disabled)
	assert_false(panel.chronicle_button.disabled)
