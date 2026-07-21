class_name PlayerCombat
extends Node
## Player-side combat (spec 004): melee swings (cooldown, stamina, sweep,
## weapon xp) and defense (passive block + armor). Spec 008 adds mana
## regen and the ward pool — a timed absorb that soaks after block and
## armor, before health. Thin wrapper — every formula lives in CombatMath,
## every tunable in BalanceConfig.

signal died
signal ward_changed(current: float, max_value: float)

const BALANCE_PATH := "res://data/balance/balance_config.tres"

@export var stats: StatsComponent
@export var inventory_component: InventoryComponent
@export var sweep: ShapeCast3D
@export var hurt_box: HurtBox
@export var config: BalanceConfig

## Injected block-roll source for deterministic tests; gameplay uses randf.
var block_roll_source: Callable = Callable()

var _cooldown_remaining := 0.0
var _ward_pool := 0.0
var _ward_max := 0.0
var _ward_seconds := 0.0


func _ready() -> void:
	if config == null:
		config = load(BALANCE_PATH) as BalanceConfig
	sweep.enabled = false  # queried once per swing, not every frame
	sweep.collision_mask = SweepQuery.SWEEP_MASK
	sweep.collide_with_areas = true  # hurtboxes are areas
	(sweep.shape as SphereShape3D).radius = config.melee_sweep_radius
	sweep.add_exception(hurt_box)
	hurt_box.hit_taken.connect(_on_hit_taken)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if stats.current_stamina < stats.sheet.get_max_stamina():
		stats.apply_stamina_delta(config.stamina_regen_per_second * delta)
	if stats.current_mana < stats.sheet.get_max_mana():
		stats.apply_mana_delta(config.mana_regen_per_second * delta)
	if _ward_seconds > 0.0:
		_ward_seconds -= delta
		if _ward_seconds <= 0.0:
			_clear_ward()


## A melee swing. No-op without a melee weapon or during cooldown; once
## off cooldown the swing always happens — empty stamina only weakens it
## (exhausted_damage_multiplier), never prevents it.
func try_attack() -> void:
	var weapon := inventory_component.get_equipped_weapon()
	if weapon == null or weapon.skill_id == &"ranged":
		return
	if _cooldown_remaining > 0.0:
		return
	_cooldown_remaining = weapon.swing_time
	var cost := CombatMath.stamina_cost(weapon.weight, config)
	var exhausted := stats.current_stamina < cost
	stats.apply_stamina_delta(-cost)
	var target := SweepQuery.nearest_hurt_box(sweep, weapon.reach)
	if target == null:
		return  # whiffed: nothing in reach, or something solid was nearer
	var raw := CombatMath.attack_damage(
		weapon.damage,
		stats.sheet.skills[weapon.skill_id],
		stats.sheet.attributes[&"strength"],
		exhausted,
		config
	)
	target.take_hit(raw, owner as Node3D)
	stats.gain_skill_xp(weapon.skill_id, config.xp_per_weapon_hit)


func get_ward() -> float:
	return _ward_pool


func get_ward_seconds() -> float:
	return _ward_seconds


## Raises a ward (spec 008): a temporary pool soaking incoming damage
## after block and armor, before health. Recasting replaces the pool and
## the timer outright — no stacking.
func apply_ward(amount: float, duration: float) -> void:
	_ward_pool = amount
	_ward_max = amount
	_ward_seconds = duration
	ward_changed.emit(_ward_pool, _ward_max)


## Defense pipeline for anything that hits the player: passive block
## (shield + Block skill), then armor, then the ward pool. Grants
## block/armor xp, applies the health delta, and reports death.
func _on_hit_taken(raw_damage: float, _attacker: Node3D) -> void:
	var result := CombatMath.resolve_defense(
		raw_damage,
		inventory_component.get_total_armor_rating(),
		inventory_component.get_equipped_shield() != null,
		stats.sheet.skills[&"block"],
		_block_roll(),
		config
	)
	if result.blocked:
		stats.gain_skill_xp(&"block", config.xp_per_block)
	for skill_id: StringName in inventory_component.get_equipped_armor_skill_ids():
		stats.gain_skill_xp(skill_id, config.xp_per_armor_hit)
	var damage := result.final_damage
	if _ward_pool > 0.0:
		var absorbed := CombatMath.ward_absorb(damage, _ward_pool)
		_ward_pool -= absorbed
		damage -= absorbed
		ward_changed.emit(_ward_pool, _ward_max)
	stats.apply_health_delta(-damage)
	if stats.current_health <= 0.0:
		died.emit()


func _block_roll() -> float:
	if block_roll_source.is_valid():
		return block_roll_source.call()
	return randf()


func _clear_ward() -> void:
	_ward_pool = 0.0
	_ward_max = 0.0
	_ward_seconds = 0.0
	ward_changed.emit(0.0, 0.0)
