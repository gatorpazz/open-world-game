extends GutTest
## The player stash (spec 016, criterion 5, scene half): the deposit-capable
## ContainerPanel moves stacks both ways, and the StashContainer chest binds
## Game.stash. Standalone fixtures for the panel; the chest test touches the
## real Game autoload (saved and restored).

const CONTAINER_PANEL := preload("res://scenes/ui/container_panel.tscn")
const STASH_SCENE := preload("res://scenes/world/stash_container.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const RAT_PELT := preload("res://data/items/rat_pelt.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")

var _stats: StatsComponent
var _items: InventoryComponent
var _stash: Inventory
var _panel: ContainerPanel


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_items = InventoryComponent.new()
	_items.stats = _stats
	add_child_autofree(_items)
	_stash = Inventory.new()


func after_each() -> void:
	get_tree().paused = false


func _open_deposit_panel() -> void:
	_panel = CONTAINER_PANEL.instantiate() as ContainerPanel
	add_child_autofree(_panel)
	_panel.open(_stash, _items, "Stash", true)


func test_deposit_moves_a_player_stack_into_the_stash() -> void:
	_items.add_item(RAT_PELT, 3)
	_open_deposit_panel()
	_panel.taker_list.select(0)
	_panel.deposit_selected()
	assert_eq(_stash.count_of(RAT_PELT), 3, "the stash received the stack")
	assert_eq(_items.inventory.count_of(RAT_PELT), 0, "it left the player's pack")


func test_take_moves_a_stashed_stack_back_to_the_player() -> void:
	_stash.add_item(HEALING_DRAUGHT, 2)
	_open_deposit_panel()
	_panel.item_list.select(0)
	_panel.take_selected()
	assert_eq(_items.inventory.count_of(HEALING_DRAUGHT), 2, "the player took it back")
	assert_eq(_stash.count_of(HEALING_DRAUGHT), 0, "the stash gave it up")


func test_loot_containers_stay_take_only() -> void:
	# The default (allow_deposit false) hides the deposit affordances, so world
	# containers are unchanged by this spec.
	_items.add_item(RAT_PELT, 1)
	_panel = CONTAINER_PANEL.instantiate() as ContainerPanel
	add_child_autofree(_panel)
	_panel.open(_stash, _items, "Chest")
	assert_false(_panel.taker_list.visible, "no deposit list on a loot container")
	assert_false(_panel.deposit_button.visible, "no deposit button on a loot container")
	_panel.deposit_selected()
	assert_eq(_items.inventory.count_of(RAT_PELT), 1, "deposit is a no-op when not allowed")


func test_stash_chest_binds_game_stash_and_opens_in_deposit_mode() -> void:
	var game := get_node("/root/Game")
	var saved_stash: Inventory = game.stash
	game.stash = Inventory.new()
	game.stash.add_item(RAT_PELT, 1)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var chest: StashContainer = STASH_SCENE.instantiate()
	add_child_autofree(chest)

	chest.interactable.interact(player)
	var panel: ContainerPanel = chest._panel

	assert_not_null(panel, "the chest opened a panel")
	assert_same(panel._source, game.stash, "the panel's source IS Game.stash")
	assert_true(panel.deposit_button.visible, "the chest opens in deposit mode")
	assert_eq(panel.item_list.item_count, 1, "it shows the stashed item")
	panel.close()
	game.stash = saved_stash
