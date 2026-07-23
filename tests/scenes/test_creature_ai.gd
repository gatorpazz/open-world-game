extends GutTest
## The two spec-024 AI additions: an ambient (non-hostile) creature never chases,
## and a ranged spitter hits from range without closing to melee. Reuses the
## spec-004 creature harness (a floor, creature.tscn, a HurtBox target).

const CREATURE_SCENE := preload("res://scenes/creatures/creature.tscn")
const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _root: Node3D


func before_each() -> void:
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


func _spawn_creature(def: CreatureDef) -> Creature:
	var creature := CREATURE_SCENE.instantiate() as Creature
	creature.def = def
	_root.add_child(creature)
	return creature


## A creature-layer body (0b100, invisible to the LOS ray) carrying a HurtBox.
func _target_body(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 0b100
	var body_shape := CollisionShape3D.new()
	body_shape.shape = BoxShape3D.new()
	body.add_child(body_shape)
	var hurt := HurtBox.new()
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = BoxShape3D.new()
	hurt.add_child(hurt_shape)
	body.add_child(hurt)
	body.position = at
	_root.add_child(body)
	return body


func _hurt_of(body: StaticBody3D) -> HurtBox:
	for child: Node in body.get_children():
		if child is HurtBox:
			return child
	return null


func _base_def() -> CreatureDef:
	var d := CreatureDef.new()
	d.id = &"test_creature"
	d.display_name = "Test Creature"
	d.max_health = 10.0
	d.damage = 4
	d.attack_reach = 1.5
	d.attack_cooldown = 0.1
	d.move_speed = 2.0
	d.detect_radius = 15.0
	d.leash_radius = 20.0
	return d


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_an_ambient_creature_never_chases() -> void:
	var def := _base_def()
	def.aggressive = false
	var creature := _spawn_creature(def)
	var body := _target_body(Vector3(0, 0, -3))  # in detect range, clear LOS
	creature.target = body
	await _ticks(12)

	assert_ne(creature.state, Creature.State.CHASE, "ambient never enters CHASE")
	assert_ne(creature.state, Creature.State.ATTACK, "ambient never attacks")
	assert_false(creature.is_in_group(&"hostile"), "ambient never joins the hostile group")


func test_a_ranged_spitter_hits_from_range_without_closing() -> void:
	var def := _base_def()
	def.attack_range = 8.0  # spits from up to 8m; melee reach is 1.5
	var creature := _spawn_creature(def)
	var body := _target_body(Vector3(0, 0, -6))  # inside spit range, well beyond melee
	var hurt := _hurt_of(body)
	watch_signals(hurt)
	creature.target = body
	await _ticks(20)

	assert_gt(get_signal_emit_count(hurt, "hit_taken"), 0, "the spitter hits from range")
	assert_gt(
		creature.global_position.distance_to(body.global_position),
		def.attack_reach,
		"it spat without closing to melee reach"
	)


func test_a_ranged_spitter_out_of_range_does_not_hit() -> void:
	var def := _base_def()
	def.attack_range = 8.0  # detect 15, so it aggros and chases from 12...
	var creature := _spawn_creature(def)
	var body := _target_body(Vector3(0, 0, -12))  # detected, but beyond spit range
	var hurt := _hurt_of(body)
	watch_signals(hurt)
	creature.target = body
	await _ticks(6)  # a few frames: it chases but is not yet within spit range

	assert_eq(get_signal_emit_count(hurt, "hit_taken"), 0, "no spit beyond attack_range")
