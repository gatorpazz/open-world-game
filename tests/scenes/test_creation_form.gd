extends GutTest
## Creation form: data-driven population, selection gating, confirm, and
## the derived-stats preview (spec 009, criteria 3-6). Standalone — no
## Game involvement.

const FORM_SCENE := preload("res://scenes/ui/creation_form.tscn")
const BALANCE_PATH := "res://data/balance/balance_config.tres"
const FIVE_MAJORS: Array[StringName] = [
	&"blades",
	&"block",
	&"evocation",
	&"mending",
	&"sneak",
]

var _cfg: BalanceConfig
var _form: CreationForm


func before_each() -> void:
	_cfg = load(BALANCE_PATH) as BalanceConfig
	_form = FORM_SCENE.instantiate() as CreationForm
	add_child_autofree(_form)
	watch_signals(_form)


func _pick_five() -> void:
	for skill_id: StringName in FIVE_MAJORS:
		assert_true(_form.toggle_major(skill_id), "picked %s" % skill_id)


func _column_toggles(column_index: int) -> Array[Button]:
	var toggles: Array[Button] = []
	var column := _form.skill_columns.get_child(column_index)
	for child: Node in column.get_children():
		if child is Button:
			toggles.append(child)
	return toggles


# --- Population (criterion 3) ---


func test_builds_twelve_toggles_in_three_archetype_columns() -> void:
	assert_eq(_form.skill_columns.get_child_count(), 3)
	var total := 0
	for i: int in 3:
		var toggles := _column_toggles(i)
		assert_eq(toggles.size(), 4, "column %d holds 4 skills" % i)
		total += toggles.size()
		for button: Button in toggles:
			assert_true(button.toggle_mode)
			assert_ne(button.text, "", "labels come from display_name")
	assert_eq(total, 12)


func test_builds_seven_favored_options_from_attribute_names() -> void:
	assert_eq(_form.favored_row.get_child_count(), CharacterSheet.ATTRIBUTE_NAMES.size())


# --- Selection gating (criterion 4) ---


func test_can_confirm_only_at_exactly_five_majors_plus_favored() -> void:
	assert_false(_form.can_confirm(), "empty form")
	_pick_five()
	assert_false(_form.can_confirm(), "five majors but no favored pick")
	_form.set_favored(&"endurance")
	assert_true(_form.can_confirm())
	assert_true(_form.toggle_major(&"blades"), "deselect drops to four")
	assert_false(_form.can_confirm(), "favored but only four majors")


func test_sixth_major_is_refused_and_unchecked_buttons_disable() -> void:
	_pick_five()
	assert_false(_form.toggle_major(&"alchemy"), "a sixth pick is refused")
	assert_false(_form.toggle_major(&"nonsense"), "an unknown id is refused")
	for i: int in 3:
		for button: Button in _column_toggles(i):
			assert_eq(
				button.disabled,
				not button.button_pressed,
				"at five, exactly the unchecked toggles are disabled"
			)
	assert_true(_form.toggle_major(&"sneak"), "deselecting still works")
	for i: int in 3:
		for button: Button in _column_toggles(i):
			assert_false(button.disabled, "under five, everything re-enables")


func test_set_favored_replaces_previous_pick() -> void:
	_pick_five()
	_form.set_favored(&"strength")
	_form.set_favored(&"intellect")
	assert_true(_form.can_confirm())
	_form.confirm()
	var sheet: CharacterSheet = get_signal_parameters(_form, "confirmed", 0)[0]
	assert_eq(sheet.attributes[&"strength"], _cfg.attribute_start, "old favor reverted")
	assert_eq(sheet.attributes[&"intellect"], _cfg.attribute_favored_start)


# --- Confirm (criterion 5) ---


func test_valid_confirm_emits_once_with_the_chosen_sheet() -> void:
	_pick_five()
	_form.set_favored(&"endurance")
	_form.confirm()
	assert_signal_emit_count(_form, "confirmed", 1)
	var sheet: CharacterSheet = get_signal_parameters(_form, "confirmed", 0)[0]
	assert_eq(sheet.attributes[&"endurance"], _cfg.attribute_favored_start)
	assert_eq(sheet.skills[&"blades"], _cfg.skill_start_major)
	assert_eq(sheet.skills[&"alchemy"], _cfg.skill_start_minor)


func test_invalid_confirm_emits_nothing() -> void:
	_form.confirm()
	assert_signal_not_emitted(_form, "confirmed")


# --- Preview (criterion 6) ---


func test_preview_reflects_the_favored_pick_from_balance_values() -> void:
	var unfavored := _form.preview_sheet().get_max_health()
	assert_almost_eq(
		unfavored, _cfg.health_base + _cfg.attribute_start * _cfg.health_per_endurance, 0.001
	)
	_form.set_favored(&"endurance")
	var favored := _form.preview_sheet().get_max_health()
	assert_almost_eq(
		favored, _cfg.health_base + _cfg.attribute_favored_start * _cfg.health_per_endurance, 0.001
	)
	assert_ne(_form.preview_label.text, "", "the preview label renders")
