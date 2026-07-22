extends GutTest
## Game-level save/load scene tests (spec 007, criteria 7, 8, and the scene
## half of 5). Runs against a scratch save_path so a developer's real
## user://save.json is never touched.

const RAT_PELT := preload("res://data/items/rat_pelt.tres")
const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SAVE_PATH := "user://test_save_007.json"

var _game: Node
var _sandbox: Node3D
var _saved_sheet: CharacterSheet
var _saved_inventory: Inventory
var _saved_journal: Journal
var _saved_faction_standing: FactionStanding
var _saved_stash: Inventory
var _saved_world_parent: Node
var _saved_current_world: Node
var _saved_player: Player
var _saved_save_path: String


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_sheet = _game.character_sheet
	_saved_inventory = _game.inventory
	_saved_journal = _game.journal
	_saved_faction_standing = _game.faction_standing
	_saved_stash = _game.stash
	_saved_world_parent = _game.world_parent
	_saved_current_world = _game.current_world
	_saved_player = _game.player
	_saved_save_path = _game.save_path
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
	_game.faction_standing = FactionStanding.new()
	_game.stash = Inventory.new()
	_game.save_path = TEST_SAVE_PATH
	_remove_scratch_file()


func after_each() -> void:
	_remove_scratch_file()
	_game.save_path = _saved_save_path
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.journal = _saved_journal
	_game.faction_standing = _saved_faction_standing
	_game.stash = _saved_stash
	_game.world_parent = _saved_world_parent
	_game.current_world = _saved_current_world
	_game.player = _saved_player


# --- Criterion 7: quicksave writes the file ---


func test_save_game_writes_file_and_flips_has_save() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	assert_false(_game.has_save(), "no save before the first quicksave")
	assert_true(_game.save_game())
	assert_true(_game.has_save())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE_PATH))
	assert_true(parsed is Dictionary, "the save is readable JSON")
	assert_eq(int((parsed as Dictionary)["save_version"]), SaveCodec.SAVE_VERSION)
	assert_eq((parsed as Dictionary)["scene_path"], MAIN_SCENE)
	assert_true((parsed as Dictionary).has("factions"), "the v2 payload carries a factions section")


func test_save_game_guard_refuses_without_world_or_player() -> void:
	assert_false(_game.save_game(), "nothing saveable before a world exists")
	assert_false(_game.has_save(), "the guard writes no file")


func test_quicksave_action_saves_and_notices() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	_game.player._unhandled_input(_action(&"quicksave"))
	assert_true(_game.has_save(), "F5 writes the save file")
	assert_eq(_game.player.hud_notice.get_child_count(), 1, "one 'Game saved.' notice queued")


func test_quickload_action_without_save_notices_failure() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	_game.player._unhandled_input(_action(&"quickload"))
	assert_eq(_game.player.hud_notice.get_child_count(), 1, "one 'No save to load.' notice queued")


# --- Criterion 8: load restores the world ---


func test_load_restores_scene_position_pools_and_identity() -> void:
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	var player: Player = _game.player
	player.stats.gain_skill_xp(&"security", 10)
	_game.inventory.add_item(RAT_PELT, 2)
	_game.journal.add_entry(&"save_point_entry")
	player.global_position = Vector3(5.0, 0.5, 4.0)
	player.stats.set_current_health(player.stats.current_health - 7.5)
	var saved_health: float = player.stats.current_health
	var sheet_at_save: CharacterSheet = _game.character_sheet
	assert_true(_game.save_game())

	player.stats.gain_skill_xp(&"security", 5)
	_game.inventory.add_item(RAT_PELT, 3)
	_game.journal.add_entry(&"post_save_entry")
	player.global_position = Vector3(-8.0, 0.5, 0.0)
	var world_before: Node = _game.current_world

	assert_true(_game.load_game())
	await wait_process_frames(3)

	assert_false(is_instance_valid(world_before), "a fresh world instance is entered")
	assert_ne(_game.character_sheet, sheet_at_save, "the restored sheet is a new instance")
	assert_eq(_game.character_sheet.skill_xp[&"security"], 10, "sheet values are the save point's")
	assert_eq(_game.inventory.count_of(RAT_PELT), 2, "inventory is the save point's")
	assert_true(_game.journal.has_entry(&"save_point_entry"))
	assert_false(_game.journal.has_entry(&"post_save_entry"), "the post-save entry is gone")
	assert_same(_game.player.journal, _game.journal, "the fresh player holds the restored identity")
	assert_almost_eq(
		_game.player.global_position,
		Vector3(5.0, 0.5, 4.0),
		Vector3.ONE * 0.1,
		"the player reappears where the save was made, not at the spawn marker"
	)
	assert_almost_eq(_game.player.stats.current_health, saved_health, 0.001)
	assert_lt(
		_game.player.stats.current_health,
		_game.character_sheet.get_max_health(),
		"pools restore to the saved value, not to max"
	)


# --- Spec 015 (scene half): faction standing round-trips ---


func test_load_restores_faction_standing() -> void:
	# Join before entering: reconcile on scene entry seeds the record from the
	# journal's joined_* entry (the additive contract).
	_game.journal.add_entry(&"joined_the_wardens")
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	assert_true(_game.faction_standing.is_member(&"wardens"), "join seeded on scene entry")
	# A reputation value the journal alone can't reconstruct — the thing the
	# save section exists to preserve.
	_game.faction_standing.adjust_reputation(&"wardens", 20)
	assert_true(_game.save_game())

	_game.faction_standing.adjust_reputation(&"wardens", 999)  # post-save drift, must be discarded

	assert_true(_game.load_game())
	await wait_process_frames(3)

	assert_true(_game.faction_standing.is_member(&"wardens"), "membership restored")
	assert_eq(
		_game.faction_standing.get_reputation(&"wardens"),
		20,
		"the saved reputation is restored — not the post-save drift, and reconcile did not reseed it"
	)


func test_load_restores_the_stash() -> void:
	# The stash (spec 016) is its own Game-owned save section — a stashed item
	# and its gold survive a save/load, and post-save drift is discarded.
	_game.change_scene(MAIN_SCENE, &"default")
	await wait_process_frames(3)
	_game.stash.add_gold(50)
	_game.stash.add_item(RAT_PELT, 2)
	assert_true(_game.save_game())

	_game.stash.add_gold(999)  # post-save drift, must be discarded

	assert_true(_game.load_game())
	await wait_process_frames(3)

	assert_eq(_game.stash.gold, 50, "the saved stash gold is restored, not the drift")
	assert_eq(_game.stash.count_of(RAT_PELT), 2, "stashed items are restored")


# --- Criterion 5 (scene half): refusal is atomic ---


func test_corrupt_save_refused_with_game_untouched() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var sheet_before: CharacterSheet = _game.character_sheet
	var inventory_before: Inventory = _game.inventory
	var journal_before: Journal = _game.journal

	assert_false(_game.load_game())
	await wait_process_frames(2)

	assert_same(_game.character_sheet, sheet_before, "identity untouched by a corrupt file")
	assert_same(_game.inventory, inventory_before)
	assert_same(_game.journal, journal_before)


func test_future_version_save_refused() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": SaveCodec.SAVE_VERSION + 1}))
	file.close()
	assert_false(_game.load_game(), "an unsupported save_version refuses the load")


func test_load_game_without_file_returns_false() -> void:
	assert_false(_game.has_save())
	assert_false(_game.load_game())


func _action(action_name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


func _remove_scratch_file() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
