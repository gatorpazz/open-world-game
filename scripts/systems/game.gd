extends Node
## Autoload "Game" — the only sanctioned global (spec 003). Owns the player's
## persistent identity (CharacterSheet + Inventory, plus the Journal per
## spec 005) and performs spawn-point scene changes; the player NODE is
## instanced fresh per scene and the identity resources are injected into it.
## Save/load (spec 007) serializes what this node holds. No other global
## state goes here without a spec saying so.
##
## Deliberately no class_name: it would collide with the autoload name.
## Tests preload this script by path instead.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWN_GROUP := &"spawn_points"
const DEFAULT_SAVE_PATH := "user://save.json"
## The new-game starting world (spec 010): the player wakes in the bait
## square. main.tscn survives as the greybox test target.
const MAIN_SCENE_PATH := "res://scenes/world/bait_square.tscn"

var character_sheet: CharacterSheet
var inventory: Inventory
var journal: Journal

## Where save_game/load_game read and write. Tests point this at a scratch
## file so they never touch a real save.
var save_path := DEFAULT_SAVE_PATH

## Parent of world scenes. Tests point this at a sandbox node; scene swaps
## only ever free worlds parented here, so Game can never free the test runner.
var world_parent: Node
var current_world: Node = null
var player: Player = null


func _ready() -> void:
	character_sheet = StatsComponent.build_default_sheet(
		StatsComponent.DEFAULT_MAJOR_SKILLS.duplicate()
	)
	inventory = Inventory.new()
	journal = Journal.new()
	world_parent = get_tree().root
	_adopt_boot_scene.call_deferred()


## Morrowind-style load-door transition. Deferred: it is triggered from
## interaction signal chains inside the very scene about to be freed.
func change_scene(scene_path: String, spawn_point: StringName) -> void:
	_change_scene_now.call_deferred(scene_path, spawn_point)


## Death reload (spec 004): re-enter the current world at its default
## spawn. World state resets while the persistent identity survives.
## Since spec 007 the death overlay prefers load_game(); this remains
## the fallback when no save exists, and the F6 debug path.
func reload_current_scene() -> void:
	if current_world == null or current_world.scene_file_path.is_empty():
		push_warning("reload_current_scene: no reloadable current world")
		return
	change_scene(current_world.scene_file_path, &"default")


## New-game commit point (spec 009): adopts the sheet character creation
## built, resets the rest of the identity wholesale — a new game is a whole
## new identity — and enters the starting world. The default sheet built in
## _ready remains the F6 debug fallback.
func start_new_game(sheet: CharacterSheet) -> void:
	character_sheet = sheet
	inventory = Inventory.new()
	journal = Journal.new()
	change_scene(MAIN_SCENE_PATH, &"default")


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Quicksave (spec 007): snapshots the identity resources, the current
## scene, and the player's transform and pools into save_path as
## human-readable JSON. The caller shows any notice — Game stays UI-free.
func save_game() -> bool:
	if current_world == null or current_world.scene_file_path.is_empty() or player == null:
		push_warning("save_game: nothing saveable (no current world or player)")
		return false
	var state := SaveCodec.SaveState.new()
	state.scene_path = current_world.scene_file_path
	state.player_transform = player.global_transform
	state.head_pitch = player.head.rotation.x
	state.current_health = player.stats.current_health
	state.current_mana = player.stats.current_mana
	state.current_stamina = player.stats.current_stamina
	state.sheet = character_sheet
	state.inventory = inventory
	state.journal = journal
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("save_game: cannot open '%s' for writing" % save_path)
		return false
	file.store_string(JSON.stringify(SaveCodec.encode_save(state), "\t"))
	return true


## Load-last-save (spec 007). Decodes the whole file before touching any
## state — a missing, corrupt, or tampered save returns false with Game
## exactly as it was. The apply is deferred: callers fire from input
## handlers inside the very scene about to be freed.
func load_game() -> bool:
	if not has_save():
		push_warning("load_game: no save file at '%s'" % save_path)
		return false
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(save_path))
	if parse_error != OK or not json.data is Dictionary:
		push_warning("load_game: save file is not valid JSON")
		return false
	var balance := load(StatsComponent.BALANCE_PATH) as BalanceConfig
	var state := SaveCodec.decode_save(json.data as Dictionary, balance, ItemLibrary.get_items())
	if state == null:
		return false
	_apply_load.call_deferred(state)
	return true


## Instances a fresh player at the named spawn marker and injects the
## persistent identity — before add_child, so the player's components skip
## building defaults in _ready.
func spawn_player(world: Node, spawn_point: StringName) -> Player:
	var new_player: Player = PLAYER_SCENE.instantiate()
	new_player.setup_identity(character_sheet, inventory, journal)
	world.add_child(new_player)
	var marker := find_spawn_point(world, spawn_point)
	if marker != null:
		new_player.global_transform = marker.global_transform
	else:
		push_error("No spawn point '%s' in '%s'; spawning at origin." % [spawn_point, world.name])
	player = new_player
	return new_player


## The Marker3D in group "spawn_points" whose node name matches, or null.
## Searches the subtree, so it works on worlds not yet in the scene tree.
static func find_spawn_point(world: Node, spawn_point: StringName) -> Marker3D:
	for node: Node in world.find_children("*", "Marker3D", true, false):
		if node.is_in_group(SPAWN_GROUP) and node.name == spawn_point:
			return node as Marker3D
	return null


## F6 convention: every playable scene has a "default" spawn marker. If the
## scene we booted into has one, spawn the player there through the same
## injection path as a real transition. Scenes without one (2D debug scenes,
## the test runner) leave Game inert.
func _adopt_boot_scene() -> void:
	current_world = get_tree().current_scene
	if current_world == null:
		return
	if find_spawn_point(current_world, &"default") == null:
		return
	spawn_player(current_world, &"default")


## The commit point of a load: the decoded resources replace the identity,
## the saved world is re-entered (its JournalGates _ready against the
## restored journal — the 006 cell-reload model), and the exact transform
## and pools are applied in the same call stack, so the spawn-marker
## positioning in spawn_player cannot win over them.
func _apply_load(state: SaveCodec.SaveState) -> void:
	character_sheet = state.sheet
	inventory = state.inventory
	journal = state.journal
	_change_scene_now(state.scene_path, &"default")
	player.global_transform = state.player_transform
	player.head.rotation.x = state.head_pitch
	player.stats.set_current_health(state.current_health)
	player.stats.set_current_mana(state.current_mana)
	player.stats.set_current_stamina(state.current_stamina)


func _change_scene_now(scene_path: String, spawn_point: StringName) -> void:
	var next: Node = (load(scene_path) as PackedScene).instantiate()
	if current_world != null and current_world.get_parent() == world_parent:
		world_parent.remove_child(current_world)
		current_world.queue_free()
	world_parent.add_child(next)
	if world_parent == get_tree().root:
		get_tree().current_scene = next
	current_world = next
	spawn_player(next, spawn_point)
