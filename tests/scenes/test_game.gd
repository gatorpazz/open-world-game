extends GutTest
## Game autoload: persistent identity, spawn-point scene changes, and the
## encumbered-speed hookup (spec 003, criteria 5 & 7 support).

const GameScript := preload("res://scripts/systems/game.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SACK_OF_ORE := preload("res://data/items/sack_of_ore.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const MAIN_SCENE := "res://scenes/main.tscn"

var _game: Node
var _sandbox: Node3D
var _saved_sheet: CharacterSheet
var _saved_inventory: Inventory
var _saved_journal: Journal
var _saved_world_parent: Node
var _saved_current_world: Node
var _saved_player: Player


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_sheet = _game.character_sheet
	_saved_inventory = _game.inventory
	_saved_journal = _game.journal
	_saved_world_parent = _game.world_parent
	_saved_current_world = _game.current_world
	_saved_player = _game.player
	_sandbox = Node3D.new()
	add_child_autofree(_sandbox)
	_game.world_parent = _sandbox
	_game.current_world = null
	_game.player = null
	_game.character_sheet = StatsComponent.build_default_sheet(
		StatsComponent.DEFAULT_MAJOR_SKILLS.duplicate()
	)
	_game.inventory = Inventory.new()
	_game.journal = Journal.new()


func after_each() -> void:
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.journal = _saved_journal
	_game.world_parent = _saved_world_parent
	_game.current_world = _saved_current_world
	_game.player = _saved_player


func _make_world_with_marker(marker_name: StringName, at: Vector3) -> Node3D:
	var world := Node3D.new()
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.add_to_group(&"spawn_points")
	marker.position = at
	world.add_child(marker)
	return world


func test_autoload_registered_with_identity() -> void:
	assert_not_null(_game, "Game autoload should exist at /root/Game")
	assert_not_null(_game.character_sheet)
	assert_not_null(_game.inventory)
	assert_not_null(_game.journal)


func test_find_spawn_point_matches_name_and_group() -> void:
	var world := Node3D.new()
	autofree(world)
	var nested := Node3D.new()
	world.add_child(nested)
	var marker := Marker3D.new()
	marker.name = "entrance"
	marker.add_to_group(&"spawn_points")
	nested.add_child(marker)
	var ungrouped := Marker3D.new()
	ungrouped.name = "ungrouped"
	world.add_child(ungrouped)
	assert_eq(GameScript.find_spawn_point(world, &"entrance"), marker)
	assert_null(GameScript.find_spawn_point(world, &"missing"))
	assert_null(
		GameScript.find_spawn_point(world, &"ungrouped"),
		"a Marker3D outside the spawn_points group is not a spawn point"
	)


func test_spawn_player_places_at_marker_and_injects_identity() -> void:
	var world := _make_world_with_marker(&"entrance", Vector3(3.0, 0.0, -2.0))
	_sandbox.add_child(world)
	var player: Player = _game.spawn_player(world, &"entrance")
	assert_almost_eq(player.global_position, Vector3(3.0, 0.0, -2.0), Vector3.ONE * 0.001)
	assert_same(
		player.stats.sheet,
		_game.character_sheet,
		"spawned player shares the persistent CharacterSheet instance"
	)
	assert_same(
		player.inventory_component.inventory,
		_game.inventory,
		"spawned player shares the persistent Inventory instance"
	)
	assert_same(
		player.journal, _game.journal, "spawned player shares the persistent Journal instance"
	)


func test_journal_persists_across_scene_change() -> void:
	# Spec 005 criterion 9, mirroring 003 criterion 5 for the Journal.
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	_game.player.journal.learn_topic(&"lastdoor")
	_game.player.journal.add_entry(&"heard_of_the_stair")
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	assert_same(
		_game.player.journal,
		_game.journal,
		"the player's Journal after a transition is the same resource instance"
	)
	assert_true(_game.player.journal.knows_topic(&"lastdoor"))
	assert_true(_game.player.journal.has_entry(&"heard_of_the_stair"))


func test_change_scene_swaps_managed_world_and_spawns_player() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	var world_a: Node = _game.current_world
	assert_not_null(world_a)
	assert_eq(world_a.get_parent(), _sandbox)
	assert_not_null(_game.player)
	assert_same(_game.player.inventory_component.inventory, _game.inventory)
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	assert_false(is_instance_valid(world_a), "old managed world is freed on transition")
	assert_ne(_game.current_world, world_a)


func test_change_scene_leaves_unmanaged_world_alone() -> void:
	var foreign := Node3D.new()
	add_child_autofree(foreign)
	_game.current_world = foreign
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	assert_true(is_instance_valid(foreign), "a world not parented to world_parent is never freed")
	assert_eq(foreign.get_parent(), self)


func test_start_new_game_adopts_sheet_and_resets_identity() -> void:
	# Spec 009, criterion 7.
	var majors: Array[StringName] = [&"blades", &"block", &"evocation", &"mending", &"sneak"]
	var created := StatsComponent.build_creation_sheet(majors, &"intellect")
	var old_inventory: Inventory = _game.inventory
	var old_journal: Journal = _game.journal
	_game.start_new_game(created)
	await wait_process_frames(3)
	assert_same(_game.character_sheet, created, "the created sheet is adopted wholesale")
	assert_same(_game.player.stats.sheet, created, "the spawned player carries it")
	assert_ne(_game.inventory, old_inventory, "inventory resets to a fresh instance")
	assert_ne(_game.journal, old_journal, "journal resets to a fresh instance")
	assert_eq(_game.current_world.get_parent(), _sandbox, "entered the managed starting world")
	assert_almost_eq(
		_game.player.stats.current_mana, created.get_max_mana(), 0.001, "pools start full"
	)


func test_encumbered_player_moves_slower() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_almost_eq(player.get_move_speed(), player.speed, 0.001)
	var config := load(BALANCE_PATH) as BalanceConfig
	player.inventory_component.add_item(SACK_OF_ORE, 5)
	assert_true(
		player.inventory_component.is_encumbered(),
		"five sacks of ore exceed the default carry capacity"
	)
	assert_almost_eq(
		player.get_move_speed(), player.speed * config.encumbered_speed_multiplier, 0.001
	)
