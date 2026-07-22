extends GutTest
## The Npc scene and DialoguePanel (spec 005, acceptance criteria 6-7).
## Panel methods are driven directly — no mouse simulation. Runs against
## the real data/ content: swift's greeting seeds lastdoor and
## scar_hounds, and lastdoor's fallback response marks drowned_stair.

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")
const SUDDEL := preload("res://data/npcs/suddel.tres")
const SUDDEL_MERCHANT := preload("res://data/merchants/suddel.tres")
const RAT_PELT := preload("res://data/items/rat_pelt.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")

var _player: Player
var _npc: Npc
var _game: Node
var _saved_bounty: BountyLedger


func before_each() -> void:
	DialogueLibrary.reset()
	_game = get_node("/root/Game")
	_saved_bounty = _game.bounty
	_game.bounty = BountyLedger.new()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_npc = NPC_SCENE.instantiate()
	_npc.def = SWIFT
	add_child_autofree(_npc)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()
	_game.bounty = _saved_bounty


func _open_panel() -> DialoguePanel:
	_npc.interactable.interact(_player)
	return _npc._panel


func test_prompt_reads_talk_display_name() -> void:
	assert_eq(_npc.interactable.get_prompt(), "Talk Swift")


func test_interact_opens_panel_with_this_npcs_greeting() -> void:
	var panel := _open_panel()
	assert_not_null(panel)
	assert_eq(panel.title_label.text, "Swift")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"Another stranger",
		"swift's npc-specific greeting, not the fallback"
	)


func test_panel_operates_on_the_players_own_journal() -> void:
	_open_panel()
	assert_true(_player.journal.knows_topic(&"lastdoor"), "greeting keyword learned")
	assert_true(_player.journal.knows_topic(&"scar_hounds"))


func test_double_interact_does_not_open_second_panel() -> void:
	var panel := _open_panel()
	_npc.interactable.interact(_player)
	assert_eq(_npc._panel, panel, "interacting while open is a no-op")


func test_topic_list_matches_evaluator_and_grows_after_unlock() -> void:
	var panel := _open_panel()
	assert_eq(panel.topic_list.item_count, 2, "greeting seeds two topics swift can answer")
	assert_eq(panel.topic_list.get_item_text(0), "Lastdoor")
	assert_eq(panel.topic_list.get_item_text(1), "scar-hounds")
	panel.show_topic(&"lastdoor")
	assert_eq(
		panel.topic_list.item_count,
		3,
		"the response's [[drowned_stair]] keyword appears immediately"
	)
	assert_eq(panel.topic_list.get_item_text(2), "the drowned stair")


func test_keyword_click_navigates_to_that_topic() -> void:
	var panel := _open_panel()
	panel.show_topic(&"lastdoor")
	var before := panel.transcript.get_parsed_text().length()
	panel._on_keyword_clicked("drowned_stair")
	assert_string_contains(
		panel.transcript.get_parsed_text().substr(before),
		"Old stairs under the Scar",
		"clicking the keyword speaks the stair response"
	)
	assert_true(_player.journal.has_entry(&"heard_of_the_stair"), "its journal effect applied")


func test_journal_gated_response_variant_on_second_ask() -> void:
	var panel := _open_panel()
	panel.show_topic(&"lastdoor")
	panel.show_topic(&"drowned_stair")
	assert_true(_player.journal.has_entry(&"heard_of_the_stair"))
	panel.show_topic(&"drowned_stair")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"So you've been asking around",
		"the requires_journal response wins once the entry is held"
	)


func test_item_exchange_goes_through_the_component_and_its_signals() -> void:
	# Suddel's a_small_favor: listed once learned, nudges without a pelt, and
	# with one takes it, gives a draught, and writes the journal. Routed
	# through InventoryComponent so item_added / item_removed fire (the
	# ContainerPanel precedent).
	var suddel: Npc = NPC_SCENE.instantiate()
	suddel.def = SUDDEL
	add_child_autofree(suddel)
	suddel.interactable.interact(_player)
	var panel: DialoguePanel = suddel._panel
	var listed := func(list: ItemList) -> Array:
		var names := []
		for index: int in list.item_count:
			names.append(list.get_item_text(index))
		return names
	assert_true(
		listed.call(panel.topic_list).has("a small favor"),
		"the favor is listed once learned, even without a pelt"
	)
	panel.show_topic(&"a_small_favor")
	assert_string_contains(
		panel.transcript.get_parsed_text(),
		"Got that pelt for me yet?",
		"without a pelt the nudge response answers"
	)
	assert_false(_player.journal.has_entry(&"suddels_stores_favor"), "no exchange without a pelt")
	_player.inventory_component.add_item(RAT_PELT, 1)
	watch_signals(_player.inventory_component)
	panel.show_topic(&"a_small_favor")
	assert_signal_emitted_with_parameters(
		_player.inventory_component, "item_removed", [RAT_PELT, 1]
	)
	assert_signal_emitted_with_parameters(
		_player.inventory_component, "item_added", [HEALING_DRAUGHT, 1]
	)
	assert_eq(_player.inventory_component.inventory.count_of(RAT_PELT), 0)
	assert_eq(_player.inventory_component.inventory.count_of(HEALING_DRAUGHT), 1)
	assert_true(_player.journal.has_entry(&"suddels_stores_favor"))
	panel.close()


func test_give_gold_reward_pays_the_player_through_the_component() -> void:
	# The gold quest reward (spec 016): a give_gold response adds coin through
	# the component so gold_changed fires. Driven directly with a fabricated
	# response — no content needed to prove the effect path.
	var panel := _open_panel()
	watch_signals(_player.inventory_component)
	var reward := DialogueResponse.new()
	reward.text = "For your trouble."
	reward.give_gold = 40
	panel._apply_effects(reward)
	assert_eq(_player.inventory_component.inventory.gold, 40, "gold paid")
	assert_signal_emitted(_player.inventory_component, "gold_changed")


func test_pay_fine_settles_the_standing_bounty() -> void:
	# The warden confrontation's pay branch (spec 017): the fine leaves the
	# player through the component and the ledger clears.
	_game.bounty.add_bounty(Theft.JURISDICTION, 40)
	var panel := _open_panel()
	_player.inventory_component.add_gold(100)
	var settle := DialogueResponse.new()
	settle.text = "Here's what I owe."
	settle.pay_fine = true
	panel._apply_effects(settle)
	assert_eq(_game.bounty.get_bounty(Theft.JURISDICTION), 0, "the bounty clears")
	assert_eq(_player.inventory_component.inventory.gold, 60, "the fine (40) was spent")


func test_pay_fine_is_a_noop_when_nothing_is_owed() -> void:
	# The topic is always present; at zero owed it moves no state (the non-modal,
	# mutate-nothing dialogue culture).
	var panel := _open_panel()
	_player.inventory_component.add_gold(100)
	var settle := DialogueResponse.new()
	settle.pay_fine = true
	panel._apply_effects(settle)
	assert_eq(_player.inventory_component.inventory.gold, 100, "no fine spent when clean")


func test_pay_fine_refused_when_the_player_cannot_cover_it() -> void:
	_game.bounty.add_bounty(Theft.JURISDICTION, 40)
	var panel := _open_panel()
	_player.inventory_component.add_gold(10)  # short of the 40 fine
	var settle := DialogueResponse.new()
	settle.pay_fine = true
	panel._apply_effects(settle)
	assert_eq(_game.bounty.get_bounty(Theft.JURISDICTION), 40, "the debt stands")
	assert_eq(_player.inventory_component.inventory.gold, 10, "no partial payment")


func test_trade_topic_opens_the_barter_counter() -> void:
	# A merchant NPC's trade response (opens_barter) fires barter_requested;
	# the Npc closes dialogue and opens the BarterPanel over its live stock.
	var suddel: Npc = NPC_SCENE.instantiate()
	suddel.def = SUDDEL
	suddel.merchant_def = SUDDEL_MERCHANT
	add_child_autofree(suddel)
	suddel.interactable.interact(_player)
	_player.journal.learn_topic(&"trade")
	var panel: DialoguePanel = suddel._panel
	panel.show_topic(&"trade")
	await wait_process_frames(1)
	assert_null(suddel._panel, "the dialogue panel closed on the barter hand-off")
	assert_not_null(suddel._barter_panel, "the counter opened")
	assert_eq(
		suddel._barter_panel.buy_row_count(),
		SUDDEL_MERCHANT.stock.size(),
		"the counter shows the merchant's stock"
	)
	suddel._barter_panel.close()


func test_non_merchant_ignores_a_barter_response() -> void:
	# Swift has no merchant_def: a barter_requested would find nothing to open.
	var panel := _open_panel()
	panel.barter_requested.emit()
	assert_null(_npc._barter_panel, "no counter without a merchant_def")


func test_unanswerable_keyword_click_says_so() -> void:
	# Swift cannot answer suddel-only a_small_favor: clicking its keyword
	# appends a notice instead of a silent no-op.
	_player.journal.learn_topic(&"a_small_favor")
	var panel := _open_panel()
	panel._on_keyword_clicked("a_small_favor")
	assert_string_contains(
		panel.transcript.get_parsed_text(), "Swift has nothing to say about that."
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
