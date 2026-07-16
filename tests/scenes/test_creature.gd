extends GutTest
## Creature AI state machine, death, and loot (spec 004, criteria 6-7).

const CREATURE_SCENE := preload("res://scenes/creatures/creature.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MARSH_RAT := preload("res://data/creatures/marsh_rat.tres")
const BARROW_THRALL := preload("res://data/creatures/barrow_thrall.tres")
const RAT_PELT := preload("res://data/items/rat_pelt.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _cfg: BalanceConfig
var _root: Node3D


func before_each() -> void:
	_cfg = load(BALANCE_PATH) as BalanceConfig
	_root = Node3D.new()
	add_child_autofree(_root)
	_add_floor()


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	_root.add_child(floor_body)


func _spawn_creature(def: CreatureDef, at: Vector3 = Vector3.ZERO) -> Creature:
	var creature := CREATURE_SCENE.instantiate() as Creature
	creature.def = def
	creature.position = at
	_root.add_child(creature)
	return creature


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


func _dummy_target(at: Vector3) -> Node3D:
	var dummy := Node3D.new()
	dummy.position = at
	_root.add_child(dummy)
	return dummy


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


# --- AI states (criterion 6) ---


func test_spawns_idle() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	assert_eq(creature.state, Creature.State.IDLE)


func test_target_in_detect_radius_with_los_triggers_chase() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	creature.target = _dummy_target(Vector3(0, 0, -5))  # detect_radius 8
	await _ticks(3)
	assert_eq(creature.state, Creature.State.CHASE)


func test_target_beyond_detect_radius_is_ignored() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	creature.target = _dummy_target(Vector3(0, 0, -20))
	await _ticks(3)
	assert_ne(creature.state, Creature.State.CHASE)


func test_los_blocked_by_wall_stays_passive() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	_add_wall(-2.5)
	creature.target = _dummy_target(Vector3(0, 0, -5))
	await _ticks(5)
	assert_ne(creature.state, Creature.State.CHASE)


func test_attacks_target_in_reach_through_defense_pipeline() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0, 0, -1.0)  # inside attack_reach 1.2
	_root.add_child(player)
	player.set_physics_process(false)
	creature.target = player
	watch_signals(player.combat.hurt_box)
	await _ticks(8)
	# One hit only: attack_cooldown (1.2s) far exceeds the awaited frames.
	assert_signal_emit_count(player.combat.hurt_box, "hit_taken", 1)
	var max_health := player.stats.sheet.get_max_health()
	assert_almost_eq(player.stats.current_health, max_health - MARSH_RAT.damage, 0.001)


func test_gives_up_beyond_leash_and_heads_home_without_reaggro() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	creature.target = _dummy_target(Vector3(0, 0, -5))
	await _ticks(3)
	assert_eq(creature.state, Creature.State.CHASE)
	# Drag the chase far past the leash, prey still right next to it.
	creature.global_position = Vector3(MARSH_RAT.leash_radius + 2.0, 0, 0)
	creature.target.global_position = creature.global_position + Vector3(0, 0, -2)
	await _ticks(2)
	assert_eq(creature.state, Creature.State.WANDER)
	assert_eq(creature._wander_target, creature._home)
	await _ticks(2)
	assert_ne(creature.state, Creature.State.CHASE, "no re-aggro while beyond leash")


# --- Death & loot (criterion 7) ---


func test_death_emits_died_and_spawns_remains_with_exact_loot() -> void:
	var creature := _spawn_creature(MARSH_RAT)
	watch_signals(creature)
	creature.hurt_box.take_hit(1000.0, _root)
	assert_signal_emitted(creature, "died")
	var remains := _find_remains()
	assert_not_null(remains)
	if remains == null:
		return
	assert_eq(remains.display_name, "Marsh Rat Remains")
	assert_eq(remains.inventory.count_of(RAT_PELT), 1)
	assert_eq(remains.inventory.stacks.size(), 1, "nothing beyond the authored loot")
	await _ticks(1)
	assert_false(is_instance_valid(creature), "corpse node is freed")


func test_creature_armor_mitigates_incoming_damage() -> void:
	var creature := _spawn_creature(BARROW_THRALL)
	creature.hurt_box.take_hit(10.0, _root)
	var expected := BARROW_THRALL.max_health - CombatMath.armor_mitigation(10.0, 5, _cfg)
	assert_almost_eq(creature.health, expected, 0.001)
	assert_eq(creature.state, Creature.State.IDLE, "survives and is not dead")


func _find_remains() -> WorldContainer:
	for child: Node in _root.get_children():
		if child is WorldContainer:
			return child
	return null
