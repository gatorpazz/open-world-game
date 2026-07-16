extends GutTest
## Hinged and transition doors (spec 003, acceptance criteria 4 & 5).

const GameScript := preload("res://scripts/systems/game.gd")
const HINGED_SCENE := preload("res://scenes/world/hinged_door.tscn")
const FLAWED_GEM := preload("res://data/items/flawed_gem.tres")
const EXTERIOR := "res://scenes/debug/interaction_debug.tscn"

var _game: Node
var _sandbox: Node3D
var _saved_sheet: CharacterSheet
var _saved_inventory: Inventory
var _saved_world_parent: Node
var _saved_current_world: Node
var _saved_player: Player


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_sheet = _game.character_sheet
	_saved_inventory = _game.inventory
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


func after_each() -> void:
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.world_parent = _saved_world_parent
	_game.current_world = _saved_current_world
	_game.player = _saved_player


func _find_transition_door(world: Node) -> TransitionDoor:
	for node: Node in world.find_children("*", "StaticBody3D", true, false):
		if node is TransitionDoor:
			return node
	return null


func test_hinged_door_toggles_open_and_closed() -> void:
	var door: HingedDoor = HINGED_SCENE.instantiate()
	add_child_autofree(door)
	door.interactable.interact(self)
	assert_true(door.is_open, "first use opens")
	await wait_seconds(door.swing_seconds + 0.1)
	assert_almost_eq(door.rotation.y, deg_to_rad(door.open_angle_degrees), 0.01)
	door.interactable.interact(self)
	assert_false(door.is_open, "second use closes")
	await wait_seconds(door.swing_seconds + 0.1)
	assert_almost_eq(door.rotation.y, 0.0, 0.01)


func test_hinged_door_mid_swing_retoggle_does_not_wedge() -> void:
	var door: HingedDoor = HINGED_SCENE.instantiate()
	add_child_autofree(door)
	door.toggle()
	await wait_seconds(door.swing_seconds * 0.5)
	door.toggle()
	assert_false(door.is_open)
	await wait_seconds(door.swing_seconds + 0.1)
	assert_almost_eq(door.rotation.y, 0.0, 0.01)


func test_transition_round_trip_lands_at_named_spawns() -> void:
	_game.change_scene(EXTERIOR, &"default")
	await wait_process_frames(3)
	var exterior: Node = _game.current_world
	assert_not_null(_find_transition_door(exterior), "exterior has a load-door")
	_find_transition_door(exterior).interactable.interact(_game.player)
	await wait_process_frames(3)
	var interior: Node = _game.current_world
	assert_ne(interior, exterior, "load-door swaps the scene")
	var spawn_in := GameScript.find_spawn_point(interior, &"from_exterior")
	assert_almost_eq(_game.player.global_position, spawn_in.global_position, Vector3.ONE * 0.01)
	_find_transition_door(interior).interactable.interact(_game.player)
	await wait_process_frames(3)
	var exterior_again: Node = _game.current_world
	assert_ne(exterior_again, interior)
	var spawn_back := GameScript.find_spawn_point(exterior_again, &"from_interior")
	assert_almost_eq(_game.player.global_position, spawn_back.global_position, Vector3.ONE * 0.01)


func test_identity_persists_across_transition() -> void:
	# Criterion 5: fresh player node, same resource instances; xp granted and
	# items looted in scene A are intact in scene B.
	_game.change_scene(EXTERIOR, &"default")
	await wait_process_frames(3)
	var player_a: Player = _game.player
	var player_a_id := player_a.get_instance_id()
	player_a.stats.gain_skill_xp(&"blades", 100)
	var blades_level: int = _game.character_sheet.skills[&"blades"]
	var blades_xp: int = _game.character_sheet.skill_xp[&"blades"]
	player_a.inventory_component.add_item(FLAWED_GEM, 2)
	_find_transition_door(_game.current_world).interactable.interact(player_a)
	await wait_process_frames(3)
	var player_b: Player = _game.player
	assert_ne(
		player_b.get_instance_id(), player_a_id, "the player node is instanced fresh per scene"
	)
	assert_same(player_b.stats.sheet, _game.character_sheet)
	assert_same(player_b.inventory_component.inventory, _game.inventory)
	assert_eq(player_b.stats.sheet.skills[&"blades"], blades_level)
	assert_eq(player_b.stats.sheet.skill_xp[&"blades"], blades_xp)
	assert_eq(player_b.inventory_component.inventory.count_of(FLAWED_GEM), 2)
