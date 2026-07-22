extends GutTest
## The guild-join choice-prompt retrofit + the additive faction seam (spec
## 015, criterion 5). Driven through DialoguePanel like test_choice_prompts.
## The Game-level scene-entry seeding is covered in test_save_load.gd
## (test_load_restores_faction_standing); here the focus is that the
## retrofitted prompt presents, the join choice re-enters the gated commit
## that writes membership, and reconcile turns that entry into a record.

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TORRUM := preload("res://data/npcs/torrum.tres")
const WESTER := preload("res://data/npcs/wester.tres")

const CORD_JOIN_STOOD := "I stood for the tables. Give me the cord."
const CORD_JOIN_MAKEGOOD := "I came to it the small way. Give me the cord."
const CACHE_JOIN := "I saw the cache. Enter me a share line."
const NOT_YET := "Not yet."

var _player: Player
var _npc: Npc


func before_each() -> void:
	DialogueLibrary.reset()
	FactionLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()
	FactionLibrary.reset()


func test_stood_player_is_offered_the_cord_as_a_prompt() -> void:
	_player.journal.add_entry(&"stood_for_the_tallies")
	var panel := _open(TORRUM)
	panel.show_topic(&"take_the_cord")
	assert_true(panel.choices_box.visible, "the cord is offered as a choice prompt")
	assert_eq(panel.choices_box.get_child_count(), 2, "join + not-yet")
	assert_eq((panel.choices_box.get_child(0) as Button).text, CORD_JOIN_STOOD)


func test_join_press_commits_and_reconcile_seeds_membership() -> void:
	_player.journal.add_entry(&"stood_for_the_tallies")
	var panel := _open(TORRUM)
	panel.show_topic(&"take_the_cord")
	_press_choice(panel, CORD_JOIN_STOOD)
	assert_true(_player.journal.has_entry(&"joined_the_wardens"), "the join commit lands")
	assert_false(panel.choices_box.visible, "the prompt is resolved")
	# The additive seam: reconcile turns the journal entry into a record.
	assert_true(_reconciled().is_member(&"wardens"), "reconcile seeds membership from the entry")


func test_defer_press_joins_nothing_and_reasking_reoffers() -> void:
	_player.journal.add_entry(&"stood_for_the_tallies")
	var panel := _open(TORRUM)
	panel.show_topic(&"take_the_cord")
	_press_choice(panel, NOT_YET)
	assert_false(_player.journal.has_entry(&"joined_the_wardens"), "a dismissal joins nothing")
	panel.show_topic(&"take_the_cord")
	assert_true(panel.choices_box.visible, "re-asking re-presents the offer")


func test_topic_click_cannot_fire_the_gated_join() -> void:
	_player.journal.add_entry(&"stood_for_the_tallies")
	var panel := _open(TORRUM)
	panel.show_topic(&"take_the_cord")  # a plain click presents the prompt, never the commit
	assert_false(
		_player.journal.has_entry(&"joined_the_wardens"),
		"the gated join is invisible to topic clicks"
	)


func test_makegood_path_also_offers_and_commits_the_cord() -> void:
	_player.journal.add_entry(&"refused_the_square")
	_player.journal.add_entry(&"the_moth_test")
	var panel := _open(TORRUM)
	panel.show_topic(&"take_the_cord")
	assert_true(panel.choices_box.visible, "the make-good path also offers the cord")
	_press_choice(panel, CORD_JOIN_MAKEGOOD)
	assert_true(_player.journal.has_entry(&"joined_the_wardens"), "the make-good join commits")
	assert_true(_reconciled().is_member(&"wardens"))


func test_wester_cache_join_commits_and_seeds_membership() -> void:
	_player.journal.add_entry(&"found_the_roofed_cache")
	var panel := _open(WESTER)
	panel.show_topic(&"the_roofed_cache")
	assert_true(panel.choices_box.visible, "the share line is offered as a prompt")
	_press_choice(panel, CACHE_JOIN)
	assert_true(_player.journal.has_entry(&"joined_the_licensed_crews"), "the crew join commits")
	assert_true(_reconciled().is_member(&"licensed_crews"))


func _open(def: NPCDef) -> DialoguePanel:
	_npc = NPC_SCENE.instantiate()
	_npc.def = def
	add_child_autofree(_npc)
	_npc.interactable.interact(_player)
	return _npc._panel


func _press_choice(panel: DialoguePanel, text: String) -> void:
	for child: Node in panel.choices_box.get_children():
		var button := child as Button
		if button != null and button.text == text:
			button.pressed.emit()
			return
	fail_test("no choice button labeled '%s'" % text)


func _reconciled() -> FactionStanding:
	var standing := FactionStanding.new()
	FactionRules.reconcile(standing, _player.journal.entries, FactionLibrary.get_factions())
	return standing
