class_name Creature
extends CharacterBody3D
## A def-driven melee creature (spec 004): one generic scene, many
## CreatureDefs. Plain-enum state machine — IDLE -> WANDER -> CHASE
## (detect radius + line of sight) -> ATTACK -> DEAD. Straight-line
## pursuit; navmesh pathing is backlog. On death the creature leaves a
## "<name> Remains" WorldContainer holding its authored loot.

signal died

enum State { IDLE, WANDER, CHASE, ATTACK, DEAD }

const BALANCE_PATH := "res://data/balance/balance_config.tres"
const CONTAINER_SCENE := preload("res://scenes/world/world_container.tscn")
## Creatures hunting the player (CHASE/ATTACK) join this group so rest (spec 020)
## can check for danger without any script reaching into creature state.
const HOSTILE_GROUP := &"hostile"
## Line-of-sight rays test world geometry (layer 1) only.
const LOS_MASK := 0b1
## Eye height for line-of-sight rays.
const EYE_OFFSET := Vector3(0, 0.5, 0)
## Close enough to a wander target to stop.
const ARRIVE_DISTANCE := 0.3

@export var def: CreatureDef
@export var config: BalanceConfig

var state: State = State.IDLE:
	set = _set_state
var health: float = 0.0
## The thing being hunted. Refreshed from Game.player when unset; tests
## assign it directly.
var target: Node3D = null

var _home: Vector3
var _wander_target: Vector3
var _idle_remaining := 0.0
var _cooldown_remaining := 0.0

@onready var hurt_box: HurtBox = $HurtBox


func _ready() -> void:
	assert(def != null, "Creature needs a CreatureDef")
	if config == null:
		config = load(BALANCE_PATH) as BalanceConfig
	health = def.max_health
	_home = global_position
	hurt_box.hit_taken.connect(_on_hit_taken)
	_enter_idle()


## State setter: keeps the HOSTILE_GROUP membership in lockstep with the state,
## so danger checks (spec 020 rest) are a group query, never a state reach-in.
func _set_state(value: State) -> void:
	state = value
	if value == State.CHASE or value == State.ATTACK:
		add_to_group(HOSTILE_GROUP)
	else:
		remove_from_group(HOSTILE_GROUP)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if target == null or not is_instance_valid(target):
		target = Game.player if is_instance_valid(Game.player) else null
	if not is_on_floor():
		velocity += get_gravity() * delta
	match state:
		State.IDLE:
			_tick_idle(delta)
		State.WANDER:
			_tick_wander()
		State.CHASE:
			_tick_chase()
		State.ATTACK:
			_tick_attack()
	move_and_slide()


func _tick_idle(delta: float) -> void:
	_stop()
	if _can_aggro():
		state = State.CHASE
		return
	_idle_remaining -= delta
	if _idle_remaining <= 0.0:
		_enter_wander()


func _tick_wander() -> void:
	if _can_aggro():
		state = State.CHASE
		return
	if _flat_distance_to(_wander_target) < ARRIVE_DISTANCE:
		_enter_idle()
		_stop()
		return
	_move_toward(_wander_target, def.move_speed * config.creature_wander_speed_multiplier)


func _tick_chase() -> void:
	if target == null or global_position.distance_to(_home) > def.leash_radius:
		_give_up()
		return
	if _flat_distance_to(target.global_position) <= def.attack_reach:
		state = State.ATTACK
		return
	_move_toward(target.global_position, def.move_speed)


func _tick_attack() -> void:
	_stop()
	if target == null:
		_give_up()
		return
	if _flat_distance_to(target.global_position) > def.attack_reach:
		state = State.CHASE
		return
	if _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = def.attack_cooldown
	# Deliberately coarser than the player's sweep: the creature is already
	# on top of its target, so it hits the HurtBox directly (spec 004).
	var hurt := _find_hurt_box(target)
	if hurt != null:
		hurt.take_hit(def.damage, self)


## Creature defense is just flat armor — no shield, no skills, no xp.
func _on_hit_taken(raw_damage: float, _attacker: Node3D) -> void:
	if state == State.DEAD:
		return
	health -= CombatMath.armor_mitigation(raw_damage, def.armor, config)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	collision_layer = 0
	hurt_box.collision_layer = 0
	died.emit()
	_spawn_remains()
	queue_free()


## Leaves the loot where the creature fell, reusing the 003 container —
## the existing panel is the whole loot UX. Empty loot still leaves
## remains: consistent, and it proves the pipeline.
func _spawn_remains() -> void:
	var remains := CONTAINER_SCENE.instantiate() as WorldContainer
	remains.display_name = "%s Remains" % def.display_name
	var loot_inventory := Inventory.new()
	for stack: ItemStack in def.loot:
		loot_inventory.add_item(stack.item, stack.count)
	remains.inventory = loot_inventory
	get_parent().add_child(remains)
	remains.global_position = global_position


## Aggro requires the target inside detect_radius with clear line of
## sight, AND the creature itself inside its leash — so a creature that
## gave up cannot instantly re-aggro on the way home.
func _can_aggro() -> bool:
	if target == null:
		return false
	if global_position.distance_to(_home) > def.leash_radius:
		return false
	if global_position.distance_to(target.global_position) > def.detect_radius:
		return false
	return _has_line_of_sight()


func _has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + EYE_OFFSET, target.global_position + EYE_OFFSET, LOS_MASK
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _enter_idle() -> void:
	state = State.IDLE
	_idle_remaining = randf_range(config.creature_idle_time_min, config.creature_idle_time_max)


func _enter_wander() -> void:
	state = State.WANDER
	var radius := config.creature_wander_radius
	_wander_target = _home + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))


func _give_up() -> void:
	state = State.WANDER
	_wander_target = _home


func _move_toward(point: Vector3, speed: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		_stop()
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _flat_distance_to(point: Vector3) -> float:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length()


static func _find_hurt_box(body: Node) -> HurtBox:
	for child: Node in body.get_children():
		if child is HurtBox:
			return child
	return null
