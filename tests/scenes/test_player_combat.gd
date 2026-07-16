extends GutTest
## Player melee: stamina/cooldown, sweep hit detection, defense pipeline,
## and skill xp (spec 004, acceptance criteria 3-5). Default sheet: majors
## include blades and block (25); attributes 30; light_armor is minor (5).

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const HUNTING_BOW := preload("res://data/items/hunting_bow.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const LEATHER_CUIRASS := preload("res://data/items/leather_cuirass.tres")
const IRON_HELM := preload("res://data/items/iron_helm.tres")

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
	# No floor in the test world and no real input: freeze movement and
	# drive cooldown/regen manually through _physics_process for determinism.
	_player.set_physics_process(false)
	_combat.set_physics_process(false)


func _equip(item: ItemDef) -> void:
	_player.inventory_component.add_item(item)
	assert_true(_player.inventory_component.equip(item), "equipped %s" % item.id)


## A creature-stand-in at z meters in front of the camera: solid body on
## the creatures layer (invisible to the sweep) carrying a HurtBox.
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


func _add_wall(z: float) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	wall.add_child(shape)
	wall.position = Vector3(0, 1.6, -z)
	_root.add_child(wall)


## Physics bodies only join the space on a physics tick.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


# --- Stamina & cooldown (criterion 3) ---


func test_swing_drains_stamina_by_weight_formula() -> void:
	_equip(IRON_SWORD)
	var before := _player.stats.current_stamina
	_combat.try_attack()
	var expected_cost := CombatMath.stamina_cost(IRON_SWORD.weight, _cfg)
	assert_almost_eq(before - _player.stats.current_stamina, expected_cost, 0.001)


func test_exhausted_attack_still_lands_at_reduced_damage() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(1.5)
	await _settle()
	_player.stats.set_current_stamina(0.0)
	_combat.try_attack()
	assert_signal_emit_count(hurt, "hit_taken", 1)
	var raw: float = get_signal_parameters(hurt, "hit_taken", 0)[0]
	assert_almost_eq(raw, CombatMath.attack_damage(IRON_SWORD.damage, 25, 30, true, _cfg), 0.001)


func test_stamina_regenerates_at_configured_rate_up_to_max() -> void:
	_player.stats.set_current_stamina(0.0)
	_combat._physics_process(1.0)
	assert_almost_eq(_player.stats.current_stamina, _cfg.stamina_regen_per_second, 0.001)
	_combat._physics_process(10000.0)
	assert_almost_eq(_player.stats.current_stamina, _player.stats.sheet.get_max_stamina(), 0.001)


func test_second_attack_within_swing_time_is_ignored() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(1.5)
	await _settle()
	var before := _player.stats.current_stamina
	_combat.try_attack()
	_combat.try_attack()
	assert_signal_emit_count(hurt, "hit_taken", 1)
	var expected_cost := CombatMath.stamina_cost(IRON_SWORD.weight, _cfg)
	assert_almost_eq(before - _player.stats.current_stamina, expected_cost, 0.001)


func test_cooldown_expires_after_swing_time() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(1.5)
	await _settle()
	_combat.try_attack()
	_combat._physics_process(IRON_SWORD.swing_time + 0.01)
	_combat.try_attack()
	assert_signal_emit_count(hurt, "hit_taken", 2)


func test_attack_without_weapon_is_noop() -> void:
	var hurt := _add_target(1.5)
	await _settle()
	var before := _player.stats.current_stamina
	_combat.try_attack()
	assert_signal_not_emitted(hurt, "hit_taken")
	assert_almost_eq(_player.stats.current_stamina, before, 0.001)


func test_attack_with_ranged_weapon_is_noop() -> void:
	_equip(HUNTING_BOW)
	var hurt := _add_target(1.0)
	await _settle()
	var before := _player.stats.current_stamina
	_combat.try_attack()
	assert_signal_not_emitted(hurt, "hit_taken")
	assert_almost_eq(_player.stats.current_stamina, before, 0.001)


# --- Hit detection (criterion 4) ---


func test_hit_within_reach_damages_exactly_once_with_formula_damage() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(1.5)
	await _settle()
	_combat.try_attack()
	assert_signal_emit_count(hurt, "hit_taken", 1)
	var raw: float = get_signal_parameters(hurt, "hit_taken", 0)[0]
	assert_almost_eq(raw, CombatMath.attack_damage(IRON_SWORD.damage, 25, 30, false, _cfg), 0.001)


func test_target_beyond_reach_is_untouched() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(4.0)  # face at 3.5m; reach 2.0 + sweep radius 0.4
	await _settle()
	_combat.try_attack()
	assert_signal_not_emitted(hurt, "hit_taken")


func test_wall_between_player_and_target_blocks_the_hit() -> void:
	_equip(IRON_SWORD)
	var hurt := _add_target(2.0)
	_add_wall(1.0)
	await _settle()
	_combat.try_attack()
	assert_signal_not_emitted(hurt, "hit_taken")


func test_only_nearest_of_two_targets_is_hit() -> void:
	_equip(IRON_SWORD)
	var near := _add_target(1.2)
	var far := _add_target(2.0)
	await _settle()
	_combat.try_attack()
	assert_signal_emit_count(near, "hit_taken", 1)
	assert_signal_not_emitted(far, "hit_taken")


# --- Skill xp and defense (criterion 5) ---


func test_connecting_hit_grants_weapon_skill_xp_whiff_grants_none() -> void:
	_equip(IRON_SWORD)
	_add_target(1.5)
	await _settle()
	_combat.try_attack()
	assert_eq(_player.stats.sheet.skill_xp[&"blades"], _cfg.xp_per_weapon_hit)
	_combat._physics_process(IRON_SWORD.swing_time + 0.01)
	_player.rotate_y(PI)  # face away: whiff
	_combat.try_attack()
	assert_eq(_player.stats.sheet.skill_xp[&"blades"], _cfg.xp_per_weapon_hit)


func test_blocked_hit_grants_block_xp_and_reduces_damage() -> void:
	_equip(WOODEN_SHIELD)
	_combat.block_roll_source = func() -> float: return 0.0
	var max_health := _player.stats.sheet.get_max_health()
	_player.combat.hurt_box.take_hit(10.0, _root)
	assert_eq(_player.stats.sheet.skill_xp[&"block"], _cfg.xp_per_block)
	var expected := CombatMath.resolve_defense(10.0, 5, true, 25, 0.0, _cfg).final_damage
	assert_almost_eq(_player.stats.current_health, max_health - expected, 0.001)


func test_unblocked_hit_grants_no_block_xp() -> void:
	_equip(WOODEN_SHIELD)
	_combat.block_roll_source = func() -> float: return 1.0
	_player.combat.hurt_box.take_hit(10.0, _root)
	assert_eq(_player.stats.sheet.skill_xp[&"block"], 0)


func test_hit_while_armored_grants_xp_to_each_distinct_armor_skill() -> void:
	_equip(LEATHER_CUIRASS)
	_equip(IRON_HELM)
	_player.combat.hurt_box.take_hit(10.0, _root)
	assert_eq(_player.stats.sheet.skill_xp[&"light_armor"], _cfg.xp_per_armor_hit)
	assert_eq(_player.stats.sheet.skill_xp[&"heavy_armor"], _cfg.xp_per_armor_hit)


func test_unarmored_hit_takes_raw_damage_and_grants_no_xp() -> void:
	var max_health := _player.stats.sheet.get_max_health()
	_player.combat.hurt_box.take_hit(10.0, _root)
	assert_almost_eq(_player.stats.current_health, max_health - 10.0, 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"block"], 0)
	assert_eq(_player.stats.sheet.skill_xp[&"heavy_armor"], 0)


func test_died_emitted_when_health_reaches_zero() -> void:
	watch_signals(_combat)
	_player.combat.hurt_box.take_hit(10000.0, _root)
	assert_eq(_player.stats.current_health, 0.0)
	assert_signal_emitted(_combat, "died")
