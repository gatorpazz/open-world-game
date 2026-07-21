extends GutTest
## Unit tests for the skill-gated learning filter (spec 008, criterion 2).
## PlayerCasting.filter_castable is static and sheet-injected — no scene.


func _spell(id: String, school: String, min_skill: int) -> SpellDef:
	var spell := SpellDef.new()
	spell.id = StringName(id)
	spell.skill_id = StringName(school)
	spell.min_skill = min_skill
	return spell


func _sheet(evocation: int, mending: int, warding: int) -> CharacterSheet:
	var sheet := StatsComponent.build_default_sheet(StatsComponent.DEFAULT_MAJOR_SKILLS)
	sheet.skills[&"evocation"] = evocation
	sheet.skills[&"mending"] = mending
	sheet.skills[&"warding"] = warding
	return sheet


func test_includes_exactly_spells_at_or_above_the_gate() -> void:
	var spells: Array[SpellDef] = [
		_spell("a_bolt", "evocation", 0),
		_spell("b_bolt", "evocation", 50),
		_spell("a_mend", "mending", 0),
		_spell("a_ward", "warding", 25),
	]
	var castable := PlayerCasting.filter_castable(spells, _sheet(25, 5, 5))
	var ids: Array[StringName] = []
	for spell: SpellDef in castable:
		ids.append(spell.id)
	assert_eq(ids, [&"a_bolt", &"a_mend"] as Array[StringName])


func test_level_reaching_threshold_adds_the_spell() -> void:
	var spells: Array[SpellDef] = [_spell("a_ward", "warding", 25)]
	assert_eq(PlayerCasting.filter_castable(spells, _sheet(25, 5, 24)).size(), 0)
	assert_eq(PlayerCasting.filter_castable(spells, _sheet(25, 5, 25)).size(), 1)


func test_order_is_school_then_tier_then_id() -> void:
	var spells: Array[SpellDef] = [
		_spell("z_ward", "warding", 0),
		_spell("a_ward", "warding", 25),
		_spell("b_mend", "mending", 0),
		_spell("a_bolt", "evocation", 0),
	]
	var castable := PlayerCasting.filter_castable(spells, _sheet(100, 100, 100))
	var ids: Array[StringName] = []
	for spell: SpellDef in castable:
		ids.append(spell.id)
	assert_eq(ids, [&"a_bolt", &"b_mend", &"z_ward", &"a_ward"] as Array[StringName])
