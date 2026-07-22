extends GutTest
## The witness primitive (spec 017, acceptance criterion 2): the pure
## detection-radius curve, and is_witnessed over a built scene with real
## line-of-sight rays — the creature-test scaffold (floor, walls, tree).

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _root: Node3D


func before_each() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_root = Node3D.new()
	add_child_autofree(_root)
	_add_floor()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	_root.add_child(floor_body)


## A wall tall and wide enough to break eye-height line of sight at z.
func _add_wall(z: float) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1, z)
	_root.add_child(wall)


func _spawn_npc(at: Vector3) -> Npc:
	var npc := NPC_SCENE.instantiate() as Npc
	npc.def = SWIFT
	npc.position = at
	_root.add_child(npc)
	return npc


func _actor(at: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.position = at
	_root.add_child(actor)
	return actor


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


# --- The pure detection radius ---


func test_radius_shrinks_as_skill_rises() -> void:
	var novice := WitnessQuery.detection_radius(_config.sneak_skill_min, false, _config)
	var master := WitnessQuery.detection_radius(_config.sneak_skill_max, false, _config)
	assert_lt(master, novice, "a skilled sneak is seen from closer")


func test_radius_shrinks_when_crouched() -> void:
	var upright := WitnessQuery.detection_radius(40, false, _config)
	var crouched := WitnessQuery.detection_radius(40, true, _config)
	assert_lt(crouched, upright, "crouching shrinks the sight circle")


# --- is_witnessed over a built scene ---


func test_npc_in_range_with_clear_los_witnesses() -> void:
	_spawn_npc(Vector3.ZERO)
	var actor := _actor(Vector3(0, 0, -3))  # within base radius 12
	await _settle()
	assert_true(WitnessQuery.is_witnessed(actor, _root, _config.sneak_skill_min, false, _config))


func test_a_wall_between_blocks_the_witness() -> void:
	_spawn_npc(Vector3.ZERO)
	var actor := _actor(Vector3(0, 0, -3))
	_add_wall(-1.5)
	await _settle()
	assert_false(WitnessQuery.is_witnessed(actor, _root, _config.sneak_skill_min, false, _config))


func test_actor_beyond_the_radius_is_unseen() -> void:
	_spawn_npc(Vector3.ZERO)
	var actor := _actor(Vector3(0, 0, -50))
	await _settle()
	assert_false(WitnessQuery.is_witnessed(actor, _root, _config.sneak_skill_min, false, _config))


func test_a_crouched_master_slips_past_where_an_upright_novice_is_caught() -> void:
	# At 5m the novice's full radius sees; the master's crouched radius (~1.8m
	# with the shipped tunables) does not.
	_spawn_npc(Vector3.ZERO)
	var actor := _actor(Vector3(0, 0, -5))
	await _settle()
	assert_true(
		WitnessQuery.is_witnessed(actor, _root, _config.sneak_skill_min, false, _config),
		"upright novice at 5m is caught"
	)
	assert_false(
		WitnessQuery.is_witnessed(actor, _root, _config.sneak_skill_max, true, _config),
		"crouched master at 5m slips past"
	)
