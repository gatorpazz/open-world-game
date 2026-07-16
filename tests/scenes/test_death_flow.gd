extends GutTest
## Player death and reload (spec 004, acceptance criterion 8): overlay +
## pause at zero health; reload lands at "default" with full health and
## the SAME persistent CharacterSheet/Inventory instances.

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const MAIN_SCENE := "res://scenes/main.tscn"

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
	get_tree().paused = false
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.world_parent = _saved_world_parent
	_game.current_world = _saved_current_world
	_game.player = _saved_player


func test_zero_health_shows_overlay_and_pauses() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	var player: Player = _game.player
	assert_false(player.death_overlay.visible, "overlay hidden while alive")
	player.combat.hurt_box.take_hit(100000.0, _sandbox)
	assert_true(player.death_overlay.visible, "overlay shown on death")
	assert_true(get_tree().paused, "tree paused on death")


func test_reload_restores_health_and_keeps_identity_instances() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	var dead_player: Player = _game.player
	var world_before: Node = _game.current_world
	# Progress made before dying must survive the reload.
	dead_player.stats.gain_skill_xp(&"blades", 5)
	dead_player.inventory_component.add_item(IRON_SWORD)
	dead_player.combat.hurt_box.take_hit(100000.0, _sandbox)
	assert_eq(dead_player.stats.current_health, 0.0)
	dead_player.death_overlay._on_reload_pressed()
	await wait_process_frames(3)
	assert_false(get_tree().paused, "reload unpauses")
	assert_false(is_instance_valid(world_before), "world was rebuilt")
	var player: Player = _game.player
	assert_ne(player, dead_player, "a fresh player node was spawned")
	assert_same(player.stats.sheet, _game.character_sheet, "same CharacterSheet instance")
	assert_same(player.inventory_component.inventory, _game.inventory, "same Inventory instance")
	assert_eq(player.stats.sheet.skill_xp[&"blades"], 5, "pre-death skill xp kept")
	assert_eq(player.inventory_component.inventory.count_of(IRON_SWORD), 1, "pre-death loot kept")
	assert_almost_eq(
		player.stats.current_health,
		player.stats.sheet.get_max_health(),
		0.001,
		"current health re-derived to full on the fresh player"
	)


func test_reload_without_world_is_a_safe_noop() -> void:
	_game.current_world = null
	_game.reload_current_scene()  # must not crash
	await wait_process_frames(2)
	assert_null(_game.player)
