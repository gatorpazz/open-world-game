class_name PlayerCasting
extends Node
## Player-side spellcasting (spec 008): skill-gated selection over the
## SpellLibrary, cast dispatch by school, cooldown, and use-based xp.
## Thin wrapper — formulas live in CombatMath, tunables in BalanceConfig,
## spell content in data/spells/. The castable list is derived from the
## sheet, never stored: no new Game state, nothing to save.

## Fires on every selection change, including refreshes; null when
## nothing is castable.
signal selected_spell_changed(spell: SpellDef)
## A spell newly entered the castable list (a licensing tier crossed).
signal spell_learned(spell: SpellDef)
## A cast was refused for lack of mana — nothing spent, no cooldown.
signal cast_failed
## A working was successfully cast (spec 018). Emitted after the mana spend and
## effect so the Player can run licensing/notice/enforcement — this node reads no
## Game state; it just reports the cast up (signals up, calls down).
signal working_cast(spell: SpellDef)

const BALANCE_PATH := "res://data/balance/balance_config.tres"

@export var stats: StatsComponent
@export var combat: PlayerCombat
@export var sweep: ShapeCast3D
@export var hurt_box: HurtBox
@export var config: BalanceConfig

var _castable: Array[SpellDef] = []
var _selected: SpellDef = null
var _cooldown_remaining := 0.0


func _ready() -> void:
	if config == null:
		config = load(BALANCE_PATH) as BalanceConfig
	sweep.enabled = false  # queried once per cast, not every frame
	sweep.collision_mask = SweepQuery.SWEEP_MASK
	sweep.collide_with_areas = true  # hurtboxes are areas
	(sweep.shape as SphereShape3D).radius = config.spell_sweep_radius
	sweep.add_exception(hurt_box)
	stats.skill_leveled.connect(_on_skill_leveled)
	_refresh_castable(false)


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


## The castable list, derived fresh each refresh: every spell whose school
## skill meets its min_skill, in deterministic (school, tier, id) order.
## Static and sheet-injected so the gate is unit-testable without a scene.
static func filter_castable(spells: Array[SpellDef], sheet: CharacterSheet) -> Array[SpellDef]:
	var castable: Array[SpellDef] = []
	for spell: SpellDef in spells:
		var level: int = sheet.skills.get(spell.skill_id, 0)
		if level >= spell.min_skill:
			castable.append(spell)
	castable.sort_custom(
		func(a: SpellDef, b: SpellDef) -> bool:
			if a.skill_id != b.skill_id:
				return String(a.skill_id) < String(b.skill_id)
			if a.min_skill != b.min_skill:
				return a.min_skill < b.min_skill
			return String(a.id) < String(b.id)
	)
	return castable


func get_selected() -> SpellDef:
	return _selected


func get_castable() -> Array[SpellDef]:
	return _castable


## Cycles the selection through the castable list, wrapping.
func cycle() -> void:
	if _castable.is_empty():
		return
	var index := _castable.find(_selected)
	_selected = _castable[(index + 1) % _castable.size()]
	selected_spell_changed.emit(_selected)


## Casts the selected spell that frame (the 004 immediate-hit precedent).
## No-op without a selection or during cooldown. Insufficient mana refuses
## without spending or cooling down (cast_failed); once committed, mana is
## always spent — a whiffed bolt still costs. Stamina plays no part.
func try_cast() -> void:
	if _selected == null or _cooldown_remaining > 0.0:
		return
	if stats.current_mana < _selected.mana_cost:
		cast_failed.emit()
		return
	_cooldown_remaining = _selected.cast_time
	stats.apply_mana_delta(-_selected.mana_cost)
	var skill_level: int = stats.sheet.skills.get(_selected.skill_id, 0)
	var power := CombatMath.spell_power(_selected.magnitude, skill_level, config)
	match _selected.skill_id:
		&"evocation":
			_cast_bolt(power)
		&"mending":
			_cast_mend(power)
		&"warding":
			_cast_ward(power)
		_:
			push_warning("no cast handler for school %s" % _selected.skill_id)
	working_cast.emit(_selected)


## Instant bolt: nearest HurtBox camera-forward within cast_range, walls
## block. Damage rides the target owner's normal defense pipeline. Xp only
## on a connect (the 004 connect-to-earn precedent).
func _cast_bolt(power: float) -> void:
	var target := SweepQuery.nearest_hurt_box(sweep, _selected.cast_range)
	if target == null:
		return  # whiffed: mana already spent
	target.take_hit(power, owner as Node3D)
	stats.gain_skill_xp(_selected.skill_id, config.xp_per_cast)


## Instant self-heal, clamped by StatsComponent. Xp only when health was
## actually below max — a full-health cast still spends.
func _cast_mend(power: float) -> void:
	var below_max := stats.current_health < stats.sheet.get_max_health()
	stats.apply_health_delta(power)
	if below_max:
		stats.gain_skill_xp(_selected.skill_id, config.xp_per_cast)


## Raises the ward through PlayerCombat (the defense owner). The effect
## always applies, so the cast always earns.
func _cast_ward(power: float) -> void:
	combat.apply_ward(power, _selected.duration)
	stats.gain_skill_xp(_selected.skill_id, config.xp_per_cast)


func _on_skill_leveled(_skill_id: StringName, _new_level: int) -> void:
	_refresh_castable(true)


## Re-derives the castable list from the sheet. Selection is kept by id
## when it survives the refresh; newly castable spells announce when
## announce is true (level-ups, not the initial build).
func _refresh_castable(announce: bool) -> void:
	var known: Dictionary[StringName, bool] = {}
	for spell: SpellDef in _castable:
		known[spell.id] = true
	var all_spells: Array[SpellDef] = []
	var library := SpellLibrary.get_spells()
	for spell_id: StringName in library:
		all_spells.append(library[spell_id])
	_castable = filter_castable(all_spells, stats.sheet)
	if announce:
		for spell: SpellDef in _castable:
			if not known.has(spell.id):
				spell_learned.emit(spell)
	var selected_id: StringName = _selected.id if _selected != null else &""
	_selected = null
	for spell: SpellDef in _castable:
		if spell.id == selected_id:
			_selected = spell
			break
	if _selected == null and not _castable.is_empty():
		_selected = _castable[0]
	selected_spell_changed.emit(_selected)
