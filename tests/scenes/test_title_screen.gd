extends GutTest
## Title-screen flow (spec 009, criteria 8-10): Continue gating, the
## corrupt-save notice, the title/form state swap, boot inertness, and the
## created-sheet save round-trip. Uses the test_death_flow harness shape:
## snapshot/restore every Game field, sandbox world_parent, scratch save.

const TITLE_SCENE := preload("res://scenes/ui/title_screen.tscn")
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"
const SCRATCH_SAVE := "user://test_title_save.json"
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const CREATION_MAJORS: Array[StringName] = [
	&"ranged",
	&"alchemy",
	&"security",
	&"persuasion",
	&"light_armor",
]

var _game: Node
var _sandbox: Node3D
var _title: TitleScreen
var _saved_sheet: CharacterSheet
var _saved_inventory: Inventory
var _saved_journal: Journal
var _saved_world_parent: Node
var _saved_current_world: Node
var _saved_player: Player
var _saved_save_path: String


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_sheet = _game.character_sheet
	_saved_inventory = _game.inventory
	_saved_journal = _game.journal
	_saved_world_parent = _game.world_parent
	_saved_current_world = _game.current_world
	_saved_player = _game.player
	_saved_save_path = _game.save_path
	_sandbox = Node3D.new()
	add_child_autofree(_sandbox)
	_game.world_parent = _sandbox
	_game.current_world = null
	_game.player = null
	_game.save_path = SCRATCH_SAVE
	_remove_scratch()
	_game.character_sheet = StatsComponent.build_default_sheet(
		StatsComponent.DEFAULT_MAJOR_SKILLS.duplicate()
	)
	_game.inventory = Inventory.new()
	_game.journal = Journal.new()
	_title = TITLE_SCENE.instantiate() as TitleScreen
	add_child_autofree(_title)


func after_each() -> void:
	_remove_scratch()
	_game.character_sheet = _saved_sheet
	_game.inventory = _saved_inventory
	_game.journal = _saved_journal
	_game.world_parent = _saved_world_parent
	_game.current_world = _saved_current_world
	_game.player = _saved_player
	_game.save_path = _saved_save_path


func _remove_scratch() -> void:
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))


func _write_scratch(content: String) -> void:
	var file := FileAccess.open(SCRATCH_SAVE, FileAccess.WRITE)
	file.store_string(content)
	file.close()


# --- Title flow (criterion 8) ---


func test_continue_disabled_without_a_save_and_enabled_with_one() -> void:
	assert_true(_title.continue_button.disabled, "no file at save_path")
	_write_scratch("{}")
	_title._show_title()
	assert_false(_title.continue_button.disabled)


func test_corrupt_save_shows_the_notice_and_stays_on_the_title() -> void:
	_write_scratch("garbage, not json")
	_title._show_title()
	_title._on_continue_pressed()
	assert_true(_title.notice_label.visible)
	assert_null(_game.current_world, "no scene change happened")
	assert_null(_game.player)


func test_new_game_shows_the_form_and_cancel_returns_clean() -> void:
	_write_scratch("garbage, not json")
	_title._show_title()
	_title._on_continue_pressed()  # leave a stale notice up
	_title._on_new_game_pressed()
	assert_true(_title.creation_form.visible)
	assert_false(_title.title_column.visible)
	_title.creation_form.cancelled.emit()
	assert_true(_title.title_column.visible)
	assert_false(_title.creation_form.visible)
	assert_false(_title.notice_label.visible, "the stale notice cleared")


# --- Boot inertness (criterion 9) ---


func test_title_scene_holds_no_spawn_points() -> void:
	for node: Node in _title.find_children("*", "", true, false):
		assert_false(
			node.is_in_group(&"spawn_points"),
			"%s must not be a spawn point — boot must stay inert" % node.name
		)


func test_main_scene_boots_to_the_title_screen() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), TITLE_SCENE_PATH)


# --- Persistence (criterion 10) ---


func test_created_sheet_round_trips_through_save_and_load() -> void:
	var cfg := load(BALANCE_PATH) as BalanceConfig
	var created := StatsComponent.build_creation_sheet(CREATION_MAJORS, &"willpower")
	_game.start_new_game(created)
	await wait_process_frames(3)
	assert_true(_game.save_game())
	assert_true(_game.load_game())
	await wait_process_frames(3)
	assert_ne(_game.character_sheet, created, "the loaded sheet is a decoded copy")
	assert_eq(_game.character_sheet.attributes[&"willpower"], cfg.attribute_favored_start)
	assert_eq(_game.character_sheet.attributes[&"strength"], cfg.attribute_start)
	assert_eq(_game.character_sheet.major_skills, CREATION_MAJORS)
	assert_eq(SaveCodec.SAVE_VERSION, 2, "save schema is v2 as of the faction spec (015)")
