extends GutTest
## EnchantRules math (spec 023, acceptance criterion 2): magnitude scaling (aspect
## vs flat) and the constant-charm aggregation over equipped items.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _sheet: CharacterSheet


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig


func before_each() -> void:
	_sheet = CharacterSheet.new()
	_sheet.skills = {&"evocation": 50, &"warding": 0, &"blades": 20}


func _working(
	trigger: StringName, effect: StringName, magnitude: float, skill_id := &"", subject := &""
) -> BoundWorkingDef:
	var w := BoundWorkingDef.new()
	w.trigger = trigger
	w.effect = effect
	w.magnitude = magnitude
	w.skill_id = skill_id
	w.subject = subject
	return w


func _item(working: BoundWorkingDef) -> ItemDef:
	var item := ItemDef.new()
	item.bound_working = working
	return item


func test_magnitude_scales_with_the_aspect_skill() -> void:
	var w := _working(&"on_hit", &"damage", 10.0, &"evocation")
	var low := EnchantRules.magnitude(w, 0, _config)
	var high := EnchantRules.magnitude(w, 100, _config)
	assert_gt(high, low, "a higher aspect skill discharges harder")


func test_magnitude_is_flat_for_an_unscaled_charm() -> void:
	var w := _working(&"constant", &"fortify", 5.0, &"", &"blades")
	assert_eq(EnchantRules.magnitude(w, 0, _config), 5.0, "no aspect ⇒ flat base")
	assert_eq(EnchantRules.magnitude(w, 100, _config), 5.0, "skill does not scale a hearth-charm")


func test_triggers_predicate() -> void:
	var worn := _item(_working(&"constant", &"resist", 3.0))
	assert_true(EnchantRules.triggers(worn, &"constant"), "matches its trigger")
	assert_false(EnchantRules.triggers(worn, &"on_hit"), "not another trigger")
	assert_false(EnchantRules.triggers(ItemDef.new(), &"constant"), "a plain item triggers nothing")
	assert_false(EnchantRules.triggers(null, &"constant"), "null triggers nothing")


func test_constant_bonus_sums_matching_effect() -> void:
	var equipped: Array[ItemDef] = [
		_item(_working(&"constant", &"resist", 3.0)),
		_item(_working(&"constant", &"resist", 4.0)),
		_item(_working(&"constant", &"ward", 5.0)),  # wrong effect
	]
	var resist := EnchantRules.constant_bonus(equipped, &"resist", &"", _sheet, _config)
	assert_eq(resist, 7.0, "sums only the two resist charms")


func test_constant_bonus_ignores_non_constant_and_plain_items() -> void:
	var equipped: Array[ItemDef] = [
		_item(_working(&"on_hit", &"resist", 9.0)),  # wrong trigger
		ItemDef.new(),  # plain
		_item(_working(&"constant", &"resist", 2.0)),
	]
	var resist := EnchantRules.constant_bonus(equipped, &"resist", &"", _sheet, _config)
	assert_eq(resist, 2.0, "only the constant charm counts")


func test_fortify_bonus_matches_the_subject() -> void:
	var equipped: Array[ItemDef] = [
		_item(_working(&"constant", &"fortify", 5.0, &"", &"blades")),
		_item(_working(&"constant", &"fortify", 8.0, &"", &"security")),  # wrong subject
	]
	var blades := EnchantRules.constant_bonus(equipped, &"fortify", &"blades", _sheet, _config)
	assert_eq(blades, 5.0, "only the blades charm lifts blades")
