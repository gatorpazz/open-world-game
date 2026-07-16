class_name StatsComponent
extends Node
## Scene-tree wrapper around a CharacterSheet. Forwards mutations down to
## the sheet, emits all stats signals, and tracks current health/mana/stamina
## (clamped to [0, max]; clamped down when a max drops below current).

signal skill_leveled(skill_id: StringName, new_level: int)
signal leveled_up(new_level: int)
signal attribute_changed(attribute: StringName, new_value: int)
signal health_changed(current: float, max_value: float)
signal mana_changed(current: float, max_value: float)
signal stamina_changed(current: float, max_value: float)

const SKILLS_DIR := "res://data/skills"
const BALANCE_PATH := "res://data/balance/balance_config.tres"

@export var sheet: CharacterSheet
## Major skills used when no sheet is assigned and a default one is built.
## Character creation is a later spec; this is a placeholder loadout.
@export var default_major_skills: Array[StringName] = [
	&"blades", &"block", &"heavy_armor", &"evocation", &"sneak",
]

var current_health: float
var current_mana: float
var current_stamina: float


func _ready() -> void:
	if sheet == null:
		sheet = _build_default_sheet()
	current_health = sheet.get_max_health()
	current_mana = sheet.get_max_mana()
	current_stamina = sheet.get_max_stamina()


func gain_skill_xp(skill_id: StringName, amount: int) -> void:
	var level_before: int = sheet.level
	var levels_gained := sheet.gain_skill_xp(skill_id, amount)
	if levels_gained > 0:
		skill_leveled.emit(skill_id, sheet.skills[skill_id])
	if sheet.level > level_before:
		leveled_up.emit(sheet.level)


func spend_attribute_point(attribute: StringName) -> bool:
	var old_maxes := _snapshot_maxes()
	if not sheet.spend_attribute_point(attribute):
		return false
	attribute_changed.emit(attribute, sheet.attributes[attribute])
	_emit_derived_changes(old_maxes)
	return true


func set_attribute(attribute: StringName, value: int) -> void:
	var old_value: int = sheet.attributes[attribute]
	var old_maxes := _snapshot_maxes()
	sheet.set_attribute(attribute, value)
	if sheet.attributes[attribute] != old_value:
		attribute_changed.emit(attribute, sheet.attributes[attribute])
		_emit_derived_changes(old_maxes)


func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, sheet.get_max_health())
	health_changed.emit(current_health, sheet.get_max_health())


func set_current_mana(value: float) -> void:
	current_mana = clampf(value, 0.0, sheet.get_max_mana())
	mana_changed.emit(current_mana, sheet.get_max_mana())


func set_current_stamina(value: float) -> void:
	current_stamina = clampf(value, 0.0, sheet.get_max_stamina())
	stamina_changed.emit(current_stamina, sheet.get_max_stamina())


func _snapshot_maxes() -> Dictionary[StringName, float]:
	return {
		&"health": sheet.get_max_health(),
		&"mana": sheet.get_max_mana(),
		&"stamina": sheet.get_max_stamina(),
	}


## Emits changed signals for each derived stat whose max moved, clamping the
## current value down when its max dropped below it.
func _emit_derived_changes(old_maxes: Dictionary[StringName, float]) -> void:
	var max_health := sheet.get_max_health()
	if not is_equal_approx(max_health, old_maxes[&"health"]):
		current_health = minf(current_health, max_health)
		health_changed.emit(current_health, max_health)
	var max_mana := sheet.get_max_mana()
	if not is_equal_approx(max_mana, old_maxes[&"mana"]):
		current_mana = minf(current_mana, max_mana)
		mana_changed.emit(current_mana, max_mana)
	var max_stamina := sheet.get_max_stamina()
	if not is_equal_approx(max_stamina, old_maxes[&"stamina"]):
		current_stamina = minf(current_stamina, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)


func _build_default_sheet() -> CharacterSheet:
	var balance := load(BALANCE_PATH) as BalanceConfig
	var skill_ids: Array[StringName] = []
	for file_name: String in ResourceLoader.list_directory(SKILLS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var skill := load(SKILLS_DIR.path_join(file_name)) as SkillDef
		skill_ids.append(skill.id)
	var new_sheet := CharacterSheet.new()
	new_sheet.setup(skill_ids, default_major_skills, balance)
	return new_sheet
