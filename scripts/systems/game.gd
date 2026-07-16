extends Node
## Autoload "Game" — the only sanctioned global (spec 003). Owns the player's
## persistent identity (CharacterSheet + Inventory) and performs spawn-point
## scene changes; the player NODE is instanced fresh per scene and the identity
## resources are injected into it. Save/load (spec 007) serializes what this
## node holds. No other global state goes here without a spec saying so.
##
## Deliberately no class_name: it would collide with the autoload name.
## Tests preload this script by path instead.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWN_GROUP := &"spawn_points"

var character_sheet: CharacterSheet
var inventory: Inventory

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
	world_parent = get_tree().root
	_adopt_boot_scene.call_deferred()


## Morrowind-style load-door transition. Deferred: it is triggered from
## interaction signal chains inside the very scene about to be freed.
func change_scene(scene_path: String, spawn_point: StringName) -> void:
	_change_scene_now.call_deferred(scene_path, spawn_point)


## Instances a fresh player at the named spawn marker and injects the
## persistent identity — before add_child, so the player's components skip
## building defaults in _ready.
func spawn_player(world: Node, spawn_point: StringName) -> Player:
	var new_player: Player = PLAYER_SCENE.instantiate()
	new_player.setup_identity(character_sheet, inventory)
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
