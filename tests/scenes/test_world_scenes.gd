extends GutTest
## World-scene lint (spec 010, criterion 6): every shipped world scene
## instantiates, has a default spawn marker, and every door, trigger,
## gate, item, and NPC reference resolves. Scenes are instantiated
## WITHOUT entering the tree, so JournalGates don't prune their children
## before the walk.

const GameScript := preload("res://scripts/systems/game.gd")
const WORLD_DIR := "res://scenes/world"
## Reusable prefabs, not places — excluded from world-scene checks.
const PREFABS: Array[String] = [
	"hinged_door.tscn",
	"journal_trigger.tscn",
	"npc.tscn",
	"transition_door.tscn",
	"world_container.tscn",
	"world_item.tscn",
]

var _scenes: Dictionary[String, Node] = {}


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(WORLD_DIR):
		if not file_name.ends_with(".tscn") or PREFABS.has(file_name):
			continue
		var packed := load(WORLD_DIR.path_join(file_name)) as PackedScene
		assert_not_null(packed, "%s loads as a PackedScene" % file_name)
		if packed != null:
			_scenes[file_name] = packed.instantiate()


func after_all() -> void:
	for file_name: String in _scenes:
		_scenes[file_name].free()


func _walk(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_walk(child, out)


func test_every_world_scene_has_a_default_spawn() -> void:
	assert_gt(_scenes.size(), 0, "world scenes exist")
	for file_name: String in _scenes:
		assert_not_null(
			GameScript.find_spawn_point(_scenes[file_name], &"default"),
			"%s has a default spawn marker" % file_name
		)


func test_transition_doors_resolve_target_scene_and_marker() -> void:
	for file_name: String in _scenes:
		var nodes: Array[Node] = []
		_walk(_scenes[file_name], nodes)
		for node: Node in nodes:
			var door := node as TransitionDoor
			if door == null:
				continue
			assert_true(
				ResourceLoader.exists(door.target_scene),
				"%s: %s target scene exists" % [file_name, door.name]
			)
			if not ResourceLoader.exists(door.target_scene):
				continue
			var target := (load(door.target_scene) as PackedScene).instantiate()
			assert_not_null(
				GameScript.find_spawn_point(target, door.spawn_point),
				"%s: %s spawn '%s' exists in target" % [file_name, door.name, door.spawn_point]
			)
			target.free()


func test_journal_references_resolve() -> void:
	for file_name: String in _scenes:
		var nodes: Array[Node] = []
		_walk(_scenes[file_name], nodes)
		for node: Node in nodes:
			var ids: Array[StringName] = []
			if node is JournalTrigger:
				var trigger := node as JournalTrigger
				ids.append(trigger.journal_entry)
				ids.append_array(trigger.requires_journal)
				ids.append_array(trigger.blocked_by_journal)
			elif node is JournalGate:
				var gate := node as JournalGate
				ids.append_array(gate.requires_journal)
				ids.append_array(gate.blocked_by_journal)
			elif node is WorldItem:
				var world_item := node as WorldItem
				assert_not_null(world_item.item, "%s: %s has an item" % [file_name, node.name])
				if world_item.journal_entry != &"":
					ids.append(world_item.journal_entry)
			for id: StringName in ids:
				assert_true(
					ResourceLoader.exists("res://data/journal/%s.tres" % id),
					"%s: %s journal id '%s' resolves" % [file_name, node.name, id]
				)


func test_npc_defs_resolve() -> void:
	for file_name: String in _scenes:
		var nodes: Array[Node] = []
		_walk(_scenes[file_name], nodes)
		for node: Node in nodes:
			var npc := node as Npc
			if npc == null:
				continue
			assert_not_null(npc.def, "%s: %s has a def" % [file_name, node.name])
			if npc.def != null:
				assert_true(
					ResourceLoader.exists("res://data/npcs/%s.tres" % npc.def.id),
					"%s: %s def '%s' resolves" % [file_name, node.name, npc.def.id]
				)
