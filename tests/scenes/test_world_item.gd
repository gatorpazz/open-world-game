extends GutTest
## World item pickups (spec 003, acceptance criterion 2).

const WORLD_ITEM_SCENE := preload("res://scenes/world/world_item.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const FLAWED_GEM := preload("res://data/items/flawed_gem.tres")
const SACK_OF_ORE := preload("res://data/items/sack_of_ore.tres")

var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func _spawn_world_item(item: ItemDef, count: int) -> WorldItem:
	var world_item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	world_item.item = item
	world_item.count = count
	add_child_autofree(world_item)
	return world_item


func test_pickup_adds_exact_item_and_count() -> void:
	var world_item := _spawn_world_item(FLAWED_GEM, 3)
	watch_signals(_player.inventory_component)
	world_item.interactable.interact(_player)
	assert_eq(_player.inventory_component.inventory.count_of(FLAWED_GEM), 3)
	assert_signal_emitted_with_parameters(
		_player.inventory_component, "item_added", [FLAWED_GEM, 3]
	)


func test_pickup_frees_the_node() -> void:
	var world_item := _spawn_world_item(FLAWED_GEM, 1)
	world_item.interactable.interact(_player)
	await wait_process_frames(1)
	assert_false(is_instance_valid(world_item), "picked-up WorldItem is freed")


func test_ore_pickup_flips_encumbrance_and_slows_movement() -> void:
	# Full 001→002→003 integration: weight over capacity flips the flag
	# and the player's move speed drops by the balance multiplier.
	var world_item := _spawn_world_item(SACK_OF_ORE, 5)
	var unencumbered_speed := _player.get_move_speed()
	watch_signals(_player.inventory_component)
	world_item.interactable.interact(_player)
	assert_true(_player.inventory_component.is_encumbered())
	assert_signal_emitted(_player.inventory_component, "encumbrance_changed")
	assert_lt(_player.get_move_speed(), unencumbered_speed)


func test_prompt_uses_item_display_name() -> void:
	var world_item := _spawn_world_item(SACK_OF_ORE, 1)
	assert_eq(world_item.interactable.get_prompt(), "Take %s" % SACK_OF_ORE.display_name)


func test_pickup_adds_journal_entry_once() -> void:
	var world_item := _spawn_world_item(FLAWED_GEM, 1)
	world_item.journal_entry = &"found_the_gem"
	world_item.interactable.interact(_player)
	assert_true(_player.journal.has_entry(&"found_the_gem"), "document pickup writes the journal")


func test_pickup_without_journal_entry_leaves_journal_untouched() -> void:
	var world_item := _spawn_world_item(FLAWED_GEM, 1)
	world_item.interactable.interact(_player)
	assert_eq(_player.journal.entries.size(), 0, 'default &"" adds nothing')


func test_non_player_interaction_is_ignored() -> void:
	var world_item := _spawn_world_item(FLAWED_GEM, 1)
	var stranger := Node.new()
	autofree(stranger)
	world_item.interactable.interact(stranger)
	await wait_process_frames(1)
	assert_true(is_instance_valid(world_item), "only a Player can take a WorldItem")
