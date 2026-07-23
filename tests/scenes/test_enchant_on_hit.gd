extends GutTest
## On-hit bound-working discharge (spec 023, acceptance criterion 3): an
## enchanted weapon lands its ordinary hit AND a second aspect-scaled discharge
## into the same target; a plain weapon discharges nothing. Reuses the spec-004
## melee harness (a creature-layer body carrying a HurtBox in reach).

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const IRON_SWORD := preload("res://data/items/iron_sword.tres")

var _cfg: BalanceConfig
var _root: Node3D
var _player: Player
var _combat: PlayerCombat


func before_each() -> void:
	_cfg = load(BALANCE_PATH) as BalanceConfig
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate() as Player
	_root.add_child(_player)
	_combat = _player.combat
	_player.set_physics_process(false)
	_combat.set_physics_process(false)


func _equip(item: ItemDef) -> void:
	_player.inventory_component.add_item(item)
	assert_true(_player.inventory_component.equip(item), "equipped %s" % item.id)


func _add_target(z: float) -> HurtBox:
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
	body.position = Vector3(0, 1.6, -z)
	_root.add_child(body)
	watch_signals(hurt)
	return hurt


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _flame_blade() -> WeaponDef:
	var working := BoundWorkingDef.new()
	working.id = &"test_flame_charm"
	working.trigger = &"on_hit"
	working.effect = &"damage"
	working.skill_id = &"evocation"
	working.magnitude = 8.0
	var w := WeaponDef.new()
	w.id = &"test_flame_blade"
	w.display_name = "Test Flame Blade"
	w.damage = 10
	w.skill_id = &"blades"
	w.weight = 5.0
	w.reach = 2.0
	w.swing_time = 1.0
	w.bound_working = working
	return w


func test_on_hit_working_discharges_into_the_target() -> void:
	var blade := _flame_blade()
	_equip(blade)
	var hurt := _add_target(1.0)
	await _settle()

	_combat.try_attack()

	assert_signal_emit_count(hurt, "hit_taken", 2, "the weapon hit then the discharge")
	var discharge: float = get_signal_parameters(hurt, "hit_taken", 1)[0]
	var skill: int = _player.stats.sheet.skills.get(&"evocation", 0)
	var expected := EnchantRules.magnitude(blade.bound_working, skill, _cfg)
	assert_almost_eq(discharge, expected, 0.01, "the discharge is the aspect-scaled magnitude")


func test_a_plain_weapon_discharges_nothing() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(1.0)
	await _settle()

	_combat.try_attack()

	assert_signal_emit_count(hurt, "hit_taken", 1, "a plain weapon lands one hit, no discharge")


func test_a_non_damage_on_hit_working_discharges_nothing() -> void:
	# The on-hit hook is outward-damage only; a mis-triggered non-damage working
	# is a no-op (the effect != damage guard).
	var blade := _flame_blade()
	blade.bound_working.effect = &"ward"
	_equip(blade)
	var hurt := _add_target(1.0)
	await _settle()

	_combat.try_attack()

	assert_signal_emit_count(hurt, "hit_taken", 1, "a non-damage working does not discharge")
