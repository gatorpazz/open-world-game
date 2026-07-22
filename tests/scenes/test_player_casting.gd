extends GutTest
## Player casting: selection/cycling, the mana gate and cooldown, bolt
## delivery, mending, warding dispatch, and learn announcements (spec 008,
## criteria 3-5 and 8). Default sheet: evocation major (25), mending and
## warding minor (5); max mana 45; max health 65.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CREATURE_SCENE := preload("res://scenes/creatures/creature.tscn")
const STAIR_DROWNED := preload("res://data/creatures/stair_drowned.tres")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const MINOR_BOLT := preload("res://data/spells/minor_bolt.tres")
const MINOR_MEND := preload("res://data/spells/minor_mend.tres")
const LESSER_WARD := preload("res://data/spells/lesser_ward.tres")

var _cfg: BalanceConfig
var _root: Node3D
var _player: Player
var _casting: PlayerCasting


func before_each() -> void:
	SpellLibrary.reset()
	_cfg = load(BALANCE_PATH) as BalanceConfig
	_root = Node3D.new()
	add_child_autofree(_root)
	_player = PLAYER_SCENE.instantiate() as Player
	_root.add_child(_player)
	_casting = _player.casting
	# No floor and no real input: freeze movement and drive cooldowns
	# manually through _physics_process for determinism.
	_player.set_physics_process(false)
	_player.combat.set_physics_process(false)
	_casting.set_physics_process(false)


func _select(spell_id: StringName) -> void:
	for i: int in _casting.get_castable().size():
		if _casting.get_selected().id == spell_id:
			return
		_casting.cycle()
	fail_test("spell %s is not castable" % spell_id)


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


# --- Selection & cycling (criterion 3) ---


func test_castable_list_derives_from_sheet_with_default_selection() -> void:
	var ids: Array[StringName] = []
	for spell: SpellDef in _casting.get_castable():
		ids.append(spell.id)
	assert_eq(ids, [&"minor_bolt", &"minor_mend", &"lesser_ward"] as Array[StringName])
	assert_eq(_casting.get_selected().id, &"minor_bolt")


func test_cycle_wraps_through_the_castable_list() -> void:
	_casting.cycle()
	assert_eq(_casting.get_selected().id, &"minor_mend")
	_casting.cycle()
	assert_eq(_casting.get_selected().id, &"lesser_ward")
	_casting.cycle()
	assert_eq(_casting.get_selected().id, &"minor_bolt")


# --- Mana gate & cooldown (criterion 3) ---


func test_committed_cast_spends_mana_and_starts_cooldown() -> void:
	var max_mana := _player.stats.sheet.get_max_mana()
	_casting.try_cast()  # whiffs (no target) but commits
	assert_almost_eq(_player.stats.current_mana, max_mana - MINOR_BOLT.mana_cost, 0.001)
	_casting.try_cast()  # inside cast_time: ignored
	assert_almost_eq(_player.stats.current_mana, max_mana - MINOR_BOLT.mana_cost, 0.001)
	_casting._physics_process(MINOR_BOLT.cast_time + 0.01)
	_casting.try_cast()
	assert_almost_eq(_player.stats.current_mana, max_mana - 2.0 * MINOR_BOLT.mana_cost, 0.001)


func test_insufficient_mana_fails_without_spending_or_cooldown() -> void:
	watch_signals(_casting)
	_player.stats.set_current_mana(MINOR_BOLT.mana_cost - 1.0)
	_casting.try_cast()
	assert_signal_emitted(_casting, "cast_failed")
	assert_almost_eq(_player.stats.current_mana, MINOR_BOLT.mana_cost - 1.0, 0.001)
	# No cooldown was started: a refill casts immediately.
	_player.stats.set_current_mana(MINOR_BOLT.mana_cost)
	_casting.try_cast()
	assert_almost_eq(_player.stats.current_mana, 0.0, 0.001)


func test_empty_stamina_never_affects_casting() -> void:
	var max_mana := _player.stats.sheet.get_max_mana()
	_player.stats.set_current_stamina(0.0)
	_casting.try_cast()
	assert_almost_eq(_player.stats.current_mana, max_mana - MINOR_BOLT.mana_cost, 0.001)


# --- Evocation (criterion 4) ---


func test_bolt_hits_nearest_target_once_with_scaled_power_and_earns_xp() -> void:
	var near := _add_target(5.0)
	var far := _add_target(8.0)
	await _settle()
	_casting.try_cast()
	assert_signal_emit_count(near, "hit_taken", 1)
	assert_signal_not_emitted(far, "hit_taken")
	var raw: float = get_signal_parameters(near, "hit_taken", 0)[0]
	assert_almost_eq(raw, CombatMath.spell_power(MINOR_BOLT.magnitude, 25, _cfg), 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"evocation"], _cfg.xp_per_cast)


func test_bolt_beyond_range_whiffs_but_still_spends() -> void:
	var max_mana := _player.stats.sheet.get_max_mana()
	var hurt := _add_target(MINOR_BOLT.cast_range + 2.0)
	await _settle()
	_casting.try_cast()
	assert_signal_not_emitted(hurt, "hit_taken")
	assert_almost_eq(_player.stats.current_mana, max_mana - MINOR_BOLT.mana_cost, 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"evocation"], 0)


func test_wall_between_player_and_target_blocks_the_bolt() -> void:
	var hurt := _add_target(5.0)
	_add_wall(2.0)
	await _settle()
	_casting.try_cast()
	assert_signal_not_emitted(hurt, "hit_taken")


func test_bolt_damage_rides_creature_armor_mitigation() -> void:
	var creature := CREATURE_SCENE.instantiate() as Creature
	creature.def = STAIR_DROWNED
	# Raised so its hurtbox capsule (top y+1.2) crosses the camera-height
	# beam at 1.6 — no floor exists in the test world to stand on anyway.
	creature.position = Vector3(0, 0.5, -5)
	_root.add_child(creature)
	creature.set_physics_process(false)
	await _settle()
	_casting.try_cast()
	var power := CombatMath.spell_power(MINOR_BOLT.magnitude, 25, _cfg)
	var expected := (
		STAIR_DROWNED.max_health - CombatMath.armor_mitigation(power, STAIR_DROWNED.armor, _cfg)
	)
	assert_almost_eq(creature.health, expected, 0.001)


# --- Mending (criterion 5) ---


func test_mend_heals_scaled_clamped_with_xp_only_below_max() -> void:
	_select(&"minor_mend")
	var max_health := _player.stats.sheet.get_max_health()
	_player.stats.set_current_health(50.0)
	_casting.try_cast()
	var power := CombatMath.spell_power(MINOR_MEND.magnitude, 5, _cfg)
	assert_almost_eq(_player.stats.current_health, 50.0 + power, 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"mending"], _cfg.xp_per_cast)
	# At full health the cast still spends but earns nothing.
	_player.stats.set_current_health(max_health)
	_casting._physics_process(MINOR_MEND.cast_time + 0.01)
	var mana_before := _player.stats.current_mana
	_casting.try_cast()
	assert_almost_eq(_player.stats.current_health, max_health, 0.001)
	assert_almost_eq(_player.stats.current_mana, mana_before - MINOR_MEND.mana_cost, 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"mending"], _cfg.xp_per_cast)


# --- Warding dispatch (criterion 6 owns the pool itself) ---


func test_ward_cast_raises_scaled_pool_and_earns_xp() -> void:
	_select(&"lesser_ward")
	watch_signals(_player.combat)
	_casting.try_cast()
	var power := CombatMath.spell_power(LESSER_WARD.magnitude, 5, _cfg)
	var params: Array = get_signal_parameters(_player.combat, "ward_changed", 0)
	assert_almost_eq(params[0] as float, power, 0.001)
	assert_almost_eq(params[1] as float, power, 0.001)
	assert_eq(_player.stats.sheet.skill_xp[&"warding"], _cfg.xp_per_cast)


# --- Learning (criteria 2-3) & transience (criterion 8) ---


func test_skill_crossing_a_tier_announces_the_new_working() -> void:
	watch_signals(_casting)
	_player.stats.gain_skill_xp(&"warding", 1000000)
	assert_signal_emitted(_casting, "spell_learned")
	var learned: SpellDef = get_signal_parameters(_casting, "spell_learned", 0)[0]
	assert_eq(learned.id, &"greater_ward")
	assert_eq(_casting.get_castable().size(), 4)
	assert_eq(_casting.get_selected().id, &"minor_bolt", "selection survives the refresh")


func test_casting_adds_no_player_save_state() -> void:
	# Selection and ward live on player nodes and rebuild on scene load;
	# the sheet's skills already persist via 007. Casting joined nothing to
	# the payload — the version is 2 as of the faction spec (015), not casting.
	assert_eq(SaveCodec.SAVE_VERSION, 2)
