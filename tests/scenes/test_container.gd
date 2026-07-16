extends GutTest
## Lootable containers and the transfer panel (spec 003, criterion 3).
## Panel methods are driven directly — no mouse simulation.

const CONTAINER_SCENE := preload("res://scenes/world/world_container.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const MANA_DRAUGHT := preload("res://data/items/mana_draught.tres")

var _player: Player
var _container: WorldContainer


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_container = CONTAINER_SCENE.instantiate()
	_container.display_name = "Worn Chest"
	var stocked := Inventory.new()
	stocked.add_item(IRON_SWORD, 1)
	stocked.add_item(MANA_DRAUGHT, 3)
	_container.inventory = stocked
	add_child_autofree(_container)


func _open_panel() -> ContainerPanel:
	_container.interactable.interact(_player)
	return _container._panel


func test_take_moves_a_single_stack() -> void:
	var panel := _open_panel()
	panel.item_list.select(1)
	panel.take_selected()
	assert_eq(_player.inventory_component.inventory.count_of(MANA_DRAUGHT), 3)
	assert_eq(_container.inventory.count_of(MANA_DRAUGHT), 0)
	assert_eq(_container.inventory.count_of(IRON_SWORD), 1,
			"untaken stack stays in the container")
	assert_eq(panel.item_list.item_count, 1, "list refreshes after a take")


func test_take_all_empties_the_container() -> void:
	var panel := _open_panel()
	panel.take_all()
	assert_eq(_player.inventory_component.inventory.count_of(IRON_SWORD), 1)
	assert_eq(_player.inventory_component.inventory.count_of(MANA_DRAUGHT), 3)
	assert_true(_container.inventory.stacks.is_empty())
	assert_eq(panel.item_list.item_count, 0)


func test_contents_persist_across_close_and_reopen() -> void:
	var inventory_before: Inventory = _container.inventory
	var panel := _open_panel()
	panel.item_list.select(0)
	panel.take_selected()
	panel.close()
	await wait_process_frames(1)
	var reopened := _open_panel()
	assert_not_null(reopened, "container reopens after close")
	assert_same(_container.inventory, inventory_before,
			"container keeps the same Inventory instance while the scene is loaded")
	assert_eq(reopened.item_list.item_count, 1)
	assert_eq(_container.inventory.count_of(MANA_DRAUGHT), 3)


func test_double_interact_does_not_open_second_panel() -> void:
	var panel := _open_panel()
	_container.interactable.interact(_player)
	assert_eq(_container._panel, panel, "interacting while open is a no-op")
	assert_eq(_container.get_children().filter(
			func(child: Node) -> bool: return child is ContainerPanel).size(), 1)


func test_prompt_uses_container_display_name() -> void:
	assert_eq(_container.interactable.get_prompt(), "Open Worn Chest")


func test_take_with_no_selection_is_noop() -> void:
	var panel := _open_panel()
	panel.take_selected()
	assert_eq(panel.item_list.item_count, 2)
	assert_true(_player.inventory_component.inventory.stacks.is_empty())
