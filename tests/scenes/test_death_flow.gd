extends GutTest
## Player death and reload (spec 004, acceptance criterion 8; amended by
## spec 007, criterion 9): overlay + pause at zero health; with a save the
## button restores the save point, without one it falls back to the 004
## reload — "default" spawn, full health, the SAME persistent instances.

const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SAVE_PATH := "user://test_death_007.json"
const TEST_SAVES_DIR := "user://test_death_saves"

var _game: Node
var _sandbox: Node3D
var _saved_sheet: CharacterSheet
var _saved_inventory: Inventory
var _saved_journal: Journal
var _saved_world_parent: Node
var _saved_current_world: Node
var _saved_player: Player
var _saved_save_path: String
var _saved_saves_dir: String


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_sheet = _game.character_sheet
	_saved_inventory = _game.inventory
	_saved_journal = _game.journal
	_saved_world_parent = _game.world_parent
	_saved_current_world = _game.current_world
	_saved_player = _game.player
	_saved_save_path = _game.save_path
	_saved_saves_dir = _game.saves_dir
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
	# A scratch path with no file: the fallback tests must never see a
	# developer's real save, and the save-present test writes only here.
	_game.save_path = TEST_SAVE_PATH
	_game.saves_dir = TEST_SAVES_DIR
	_remove_scratch_file()


func after_each() -> void:
	get_tree().paused = false
	_remove_scratch_file()
	_game.save_path = _saved_save_path
	_game.saves_dir = _saved_saves_dir
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.journal = _saved_journal
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


func test_death_button_loads_last_save_when_one_exists() -> void:
	# Spec 007 criterion 9: the save-present path.
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	var dead_player: Player = _game.player
	dead_player.global_position = Vector3(4.0, 0.5, 3.0)
	dead_player.stats.set_current_health(dead_player.stats.current_health - 5.0)
	var saved_health: float = dead_player.stats.current_health
	assert_true(_game.save_game())
	var sheet_at_save: CharacterSheet = _game.character_sheet
	dead_player.combat.hurt_box.take_hit(100000.0, _sandbox)
	assert_true(dead_player.death_overlay.visible)
	dead_player.death_overlay._on_reload_pressed()
	await wait_process_frames(3)
	assert_false(get_tree().paused, "the button unpauses")
	assert_ne(_game.character_sheet, sheet_at_save, "identity restored from disk, a new instance")
	assert_almost_eq(
		_game.player.global_position,
		Vector3(4.0, 0.5, 3.0),
		Vector3.ONE * 0.1,
		"death lands at the save point, not the default spawn"
	)
	assert_almost_eq(
		_game.player.stats.current_health, saved_health, 0.001, "pools are the save point's"
	)


func _remove_scratch_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	for slot_id: StringName in SaveSlots.SLOT_IDS:
		SaveSlots.delete(TEST_SAVES_DIR, slot_id)
