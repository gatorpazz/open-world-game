extends GutTest
## The Npc scene and DialoguePanel (spec 005, acceptance criteria 6-7).
## Panel methods are driven directly — no mouse simulation. Runs against
## the real data/ content: hunald's greeting seeds the_village and
## bog_hounds, and the_village's fallback response marks the_old_barrow.

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUNALD := preload("res://data/npcs/hunald.tres")

var _player: Player
var _npc: Npc


func before_each() -> void:
	DialogueLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_npc = NPC_SCENE.instantiate()
	_npc.def = HUNALD
	add_child_autofree(_npc)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()


func _open_panel() -> DialoguePanel:
	_npc.interactable.interact(_player)
	return _npc._panel


func test_prompt_reads_talk_display_name() -> void:
	assert_eq(_npc.interactable.get_prompt(), "Talk Hunald")


func test_interact_opens_panel_with_this_npcs_greeting() -> void:
	var panel := _open_panel()
	assert_not_null(panel)
	assert_eq(panel.title_label.text, "Hunald")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"Another stranger",
		"hunald's npc-specific greeting, not the fallback"
	)


func test_panel_operates_on_the_players_own_journal() -> void:
	_open_panel()
	assert_true(_player.journal.knows_topic(&"the_village"), "greeting keyword learned")
	assert_true(_player.journal.knows_topic(&"bog_hounds"))


func test_double_interact_does_not_open_second_panel() -> void:
	var panel := _open_panel()
	_npc.interactable.interact(_player)
	assert_eq(_npc._panel, panel, "interacting while open is a no-op")


func test_topic_list_matches_evaluator_and_grows_after_unlock() -> void:
	var panel := _open_panel()
	assert_eq(panel.topic_list.item_count, 2, "greeting seeds two topics hunald can answer")
	assert_eq(panel.topic_list.get_item_text(0), "the village")
	assert_eq(panel.topic_list.get_item_text(1), "bog hounds")
	panel.show_topic(&"the_village")
	assert_eq(
		panel.topic_list.item_count,
		3,
		"the response's [[the_old_barrow]] keyword appears immediately"
	)
	assert_eq(panel.topic_list.get_item_text(2), "the old barrow")


func test_keyword_click_navigates_to_that_topic() -> void:
	var panel := _open_panel()
	panel.show_topic(&"the_village")
	var before := panel.transcript.get_parsed_text().length()
	panel._on_keyword_clicked("the_old_barrow")
	assert_string_contains(
		panel.transcript.get_parsed_text().substr(before),
		"mound of old stones",
		"clicking the keyword speaks the barrow response"
	)
	assert_true(_player.journal.has_entry(&"heard_of_the_barrow"), "its journal effect applied")


func test_journal_gated_response_variant_on_second_ask() -> void:
	var panel := _open_panel()
	panel.show_topic(&"the_village")
	panel.show_topic(&"the_old_barrow")
	assert_true(_player.journal.has_entry(&"heard_of_the_barrow"))
	panel.show_topic(&"the_old_barrow")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"So you've been asking around",
		"the requires_journal response wins once the entry is held"
	)


func test_dialogue_pauses_and_close_restores() -> void:
	# Mouse-mode transitions are not asserted: headless runs cannot
	# capture the mouse, so MOUSE_MODE_CAPTURED never sticks in CI.
	var panel := _open_panel()
	assert_true(get_tree().paused, "dialogue pauses the tree")
	watch_signals(panel)
	panel.close()
	assert_false(get_tree().paused, "close unpauses")
	assert_signal_emitted(panel, "closed")
	await wait_process_frames(1)
	assert_null(_npc._panel, "the npc forgets the freed panel")
