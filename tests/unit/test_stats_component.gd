extends GutTest
## Tests for StatsComponent signals and current-pool clamping (spec 001).
## Uses the real balance config: attribute start 30 -> max health 65,
## max mana 45, max stamina 60.

const MAJOR := &"blades"
const MINOR := &"security"

var _component: StatsComponent


func before_each() -> void:
	_component = StatsComponent.new()
	add_child_autofree(_component)
	watch_signals(_component)


func test_builds_default_sheet_with_full_pools() -> void:
	assert_not_null(_component.sheet)
	assert_eq(_component.sheet.skills.size(), 12)
	assert_almost_eq(_component.current_health, 65.0, 0.001)
	assert_almost_eq(_component.current_mana, 45.0, 0.001)
	assert_almost_eq(_component.current_stamina, 60.0, 0.001)


func test_skill_leveled_signal() -> void:
	_component.gain_skill_xp(MINOR, 35)
	assert_signal_emitted_with_parameters(_component, "skill_leveled", [MINOR, 6])


func test_no_skill_leveled_signal_below_threshold() -> void:
	_component.gain_skill_xp(MINOR, 10)
	assert_signal_not_emitted(_component, "skill_leveled")


func test_leveled_up_signal_after_ten_major_level_ups() -> void:
	for i: int in range(10):
		_component.gain_skill_xp(MAJOR, _component.sheet.xp_required(MAJOR))
	assert_signal_emitted_with_parameters(_component, "leveled_up", [2])
	assert_signal_emit_count(_component, "leveled_up", 1)


func test_spend_attribute_point_emits_attribute_and_derived_signals() -> void:
	_component.sheet.unspent_attribute_points = 3
	assert_true(_component.spend_attribute_point(&"endurance"))
	assert_signal_emitted_with_parameters(_component, "attribute_changed", [&"endurance", 31])
	# Endurance feeds health and stamina; current values stay, maxes grow.
	assert_signal_emitted_with_parameters(_component, "health_changed", [65.0, 66.5])
	assert_signal_emitted_with_parameters(_component, "stamina_changed", [60.0, 60.5])
	assert_signal_not_emitted(_component, "mana_changed", "endurance does not affect mana")


func test_refused_spend_emits_nothing() -> void:
	assert_false(_component.spend_attribute_point(&"endurance"))
	assert_signal_not_emitted(_component, "attribute_changed")
	assert_signal_not_emitted(_component, "health_changed")


func test_current_health_clamps_down_when_max_drops() -> void:
	_component.set_attribute(&"endurance", 10)
	# Max health drops 65 -> 35; current must clamp down with it.
	assert_almost_eq(_component.current_health, 35.0, 0.001)
	assert_signal_emitted_with_parameters(_component, "health_changed", [35.0, 35.0])


func test_current_setters_clamp_to_valid_range() -> void:
	_component.set_current_health(-10.0)
	assert_almost_eq(_component.current_health, 0.0, 0.001)
	_component.set_current_health(9999.0)
	assert_almost_eq(_component.current_health, 65.0, 0.001)
	assert_signal_emitted(_component, "health_changed")


func test_set_attribute_to_same_value_emits_nothing() -> void:
	_component.set_attribute(&"strength", 30)
	assert_signal_not_emitted(_component, "attribute_changed")
	assert_signal_not_emitted(_component, "stamina_changed")
