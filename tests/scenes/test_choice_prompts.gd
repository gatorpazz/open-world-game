extends GutTest
## Choice prompts end-to-end on the retrofitted data (spec 013, acceptance
## criterion 2). Panel methods and button presses are driven directly —
## the test_npc_dialogue.gd style. Covers both shipped decision points:
## the refusal at the square (torrum) and the seal at tablet law (kellom).

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TORRUM := preload("res://data/npcs/torrum.tres")
const KELLOM := preload("res://data/npcs/kellom.tres")

var _player: Player
var _npc: Npc


func before_each() -> void:
	DialogueLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_npc = NPC_SCENE.instantiate()
	_npc.def = TORRUM
	add_child_autofree(_npc)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()


func _open_panel() -> DialoguePanel:
	_npc.interactable.interact(_player)
	return _npc._panel


func _press_choice(panel: DialoguePanel, text: String) -> void:
	for child: Node in panel.choices_box.get_children():
		var button := child as Button
		if button != null and button.text == text:
			button.pressed.emit()
			return
	fail_test("no choice button labeled '%s'" % text)


# --- The refusal at the square (torrum) ---


func test_torrum_ask_presents_two_replies_and_stays_non_modal() -> void:
	var panel := _open_panel()
	panel.show_topic(&"for_the_tallies")
	assert_true(panel.choices_box.visible, "the ask presents a choice prompt")
	assert_eq(panel.choices_box.get_child_count(), 2, "refuse + defer, the ruled shape")
	assert_eq((panel.choices_box.get_child(0) as Button).text, "I refuse. Enter it.")
	assert_eq((panel.choices_box.get_child(1) as Button).text, "Not yet. Ask me again.")
	assert_false(panel.goodbye_button.disabled, "non-modal: Goodbye stays live")
	assert_gt(panel.topic_list.item_count, 0, "non-modal: the topic list stays live")


func test_refuse_press_speaks_the_line_and_commits() -> void:
	var panel := _open_panel()
	panel.show_topic(&"for_the_tallies")
	_press_choice(panel, "I refuse. Enter it.")
	assert_true(_player.journal.has_entry(&"refused_the_square"), "the commit lands")
	var spoken := panel.transcript.get_parsed_text()
	assert_string_contains(spoken, "I refuse. Enter it.", "the player's line is in the transcript")
	assert_string_contains(spoken, "Then it is entered", "torrum answers the refusal")
	assert_false(panel.choices_box.visible, "the prompt is resolved")


func test_defer_press_changes_nothing_and_reasking_represents() -> void:
	var panel := _open_panel()
	panel.show_topic(&"for_the_tallies")
	var entries_before := _player.journal.entries.duplicate()
	_press_choice(panel, "Not yet. Ask me again.")
	assert_eq(_player.journal.entries, entries_before, "a dismissal mutates nothing")
	assert_false(panel.choices_box.visible, "the prompt lapses")
	panel.show_topic(&"for_the_tallies")
	assert_true(panel.choices_box.visible, "re-asking re-presents the prompt")
	assert_eq(panel.choices_box.get_child_count(), 2)


func test_navigating_away_lapses_a_pending_prompt() -> void:
	var panel := _open_panel()
	panel.show_topic(&"for_the_tallies")
	assert_true(panel.choices_box.visible)
	panel.show_topic(&"lastdoor")
	assert_false(panel.choices_box.visible, "moving the conversation clears the buttons")
	assert_eq(panel.choices_box.get_child_count(), 0)
	assert_false(_player.journal.has_entry(&"refused_the_square"), "and commits nothing")


func test_topic_click_cannot_fire_the_gated_commit() -> void:
	var panel := _open_panel()
	panel.show_topic(&"for_the_tallies")
	panel.show_topic(&"refuse_the_square")  # a plain click, not a choice press
	assert_false(
		_player.journal.has_entry(&"refused_the_square"),
		"the gated commit is invisible to topic clicks — the spec 013 point"
	)


# --- The seal at tablet law (kellom) ---


func _open_kellom_in_decision_state() -> DialoguePanel:
	_npc.def = KELLOM
	_player.journal.learn_topic(&"the_kept_name")
	_player.journal.add_entry(&"the_waxed_staff")
	return _open_panel()


func test_tablet_law_presents_the_seal_prompt_instead_of_instant_sealing() -> void:
	var panel := _open_kellom_in_decision_state()
	panel.show_topic(&"tablet_law")
	assert_false(
		_player.journal.has_entry(&"the_gap_kept"),
		"asking about the law no longer seals the ending — the 010 playthrough bug"
	)
	assert_true(panel.choices_box.visible, "kellom asks instead")
	assert_eq(panel.choices_box.get_child_count(), 2)


func test_seal_press_fires_the_gated_absolve_and_reask_is_sealed() -> void:
	var panel := _open_kellom_in_decision_state()
	panel.show_topic(&"tablet_law")
	_press_choice(panel, "I say it once. Seal it unsaid.")
	assert_true(_player.journal.has_entry(&"the_gap_kept"), "the absolve commits")
	assert_string_contains(panel.transcript.get_parsed_text(), "It is heard. It is sealed.")
	panel.show_topic(&"tablet_law")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"It will not be said again",
		"re-asking picks the sealed post-state, not the prompt"
	)
	assert_false(panel.choices_box.visible, "no prompt after the decision")


func test_not_yet_press_keeps_the_decision_open() -> void:
	var panel := _open_kellom_in_decision_state()
	panel.show_topic(&"tablet_law")
	_press_choice(panel, "Not yet. I keep what I know.")
	assert_false(_player.journal.has_entry(&"the_gap_kept"), "nothing sealed")
	panel.show_topic(&"tablet_law")
	assert_true(panel.choices_box.visible, "the question stands on re-ask")
