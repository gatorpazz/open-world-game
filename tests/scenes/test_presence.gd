extends GutTest
## Presence-lite (spec 020, acceptance criterion 4): a scheduled Npc shows/hides
## across its bell-window and flips on a rollover; an unscheduled Npc is always
## present. Runs against the real Game.clock, saved and restored.

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")

var _game: Node
var _saved_clock: WorldClock
var _root: Node3D


func before_each() -> void:
	_game = get_node("/root/Game")
	_saved_clock = _game.clock
	_game.clock = WorldClock.new()
	_root = Node3D.new()
	add_child_autofree(_root)


func after_each() -> void:
	_game.clock = _saved_clock


func _scheduled_npc(from_bell: int, to_bell: int) -> Npc:
	var schedule := NPCSchedule.new()
	schedule.present_from_bell = from_bell
	schedule.present_to_bell = to_bell
	var def := NPCDef.new()
	def.id = &"test_npc"
	def.display_name = "Test NPC"
	def.schedule = schedule
	var npc := NPC_SCENE.instantiate() as Npc
	npc.def = def
	_root.add_child(npc)
	return npc


func test_scheduled_npc_is_present_inside_the_window() -> void:
	_game.clock.bell = 5.0  # inside 2..8
	var npc := _scheduled_npc(2, 8)
	assert_true(npc.visible, "at post inside the window")
	assert_false(npc.collision.disabled, "and interactable")


func test_scheduled_npc_is_absent_outside_the_window() -> void:
	_game.clock.bell = 10.0  # outside 2..8
	var npc := _scheduled_npc(2, 8)
	assert_false(npc.visible, "shuttered outside the window")
	assert_true(npc.collision.disabled, "and not interactable")


func test_presence_flips_on_a_bell_rollover() -> void:
	_game.clock.bell = 5.0
	var npc := _scheduled_npc(2, 8)
	assert_true(npc.visible, "present at bell 5")
	_game.clock.bell = 9.0
	_game.time_changed.emit(_game.clock.get_day(), _game.clock.get_bell())
	assert_false(npc.visible, "the counter shutters when the bell crosses out")


func test_unscheduled_npc_is_always_present() -> void:
	_game.clock.bell = 11.0
	var npc := NPC_SCENE.instantiate() as Npc
	npc.def = SWIFT  # no schedule
	_root.add_child(npc)
	assert_true(npc.visible, "an unscheduled NPC is always at post")
	assert_false(npc.collision.disabled)
