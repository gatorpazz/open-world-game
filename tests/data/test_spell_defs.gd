extends GutTest
## Validates every SpellDef resource in data/spells/ (spec 008,
## acceptance criterion 10).

const DIR := "res://data/spells"
const SKILLS_DIR := "res://data/skills"
## Spec 008 ships 5 starter spells.
const EXPECTED_SPELL_COUNT := 5
## The licensing tiers of the_workings — the only v1 learning gates.
const VALID_MIN_SKILLS: Array[int] = [0, 25, 50]

var _defs: Array[SpellDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: SpellDef = load(DIR.path_join(file_name)) as SpellDef
		assert_not_null(def, "%s should load as a SpellDef" % file_name)
		if def != null:
			_defs.append(def)


func test_expected_spell_count() -> void:
	assert_eq(_defs.size(), EXPECTED_SPELL_COUNT)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: SpellDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_and_descriptions_are_non_empty() -> void:
	for def: SpellDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)
		assert_ne(def.description, "", "%s has a description" % def.id)


func test_skill_ids_are_magic_skills() -> void:
	for def: SpellDef in _defs:
		var skill := load(SKILLS_DIR.path_join("%s.tres" % def.skill_id)) as SkillDef
		assert_not_null(skill, "%s skill_id %s resolves to a SkillDef" % [def.id, def.skill_id])
		if skill != null:
			assert_eq(skill.archetype, &"magic", "%s school is a magic skill" % def.id)


func test_min_skill_is_a_licensing_tier() -> void:
	for def: SpellDef in _defs:
		assert_has(VALID_MIN_SKILLS, def.min_skill, "%s min_skill is a tier" % def.id)


func test_numeric_fields_are_in_sane_ranges() -> void:
	for def: SpellDef in _defs:
		assert_gt(def.mana_cost, 0.0, "%s mana_cost" % def.id)
		assert_gt(def.magnitude, 0.0, "%s magnitude" % def.id)
		assert_gt(def.cast_time, 0.0, "%s cast_time" % def.id)
		assert_gte(def.duration, 0.0, "%s duration" % def.id)
		assert_gte(def.cast_range, 0.0, "%s cast_range" % def.id)


func test_per_school_field_shapes() -> void:
	for def: SpellDef in _defs:
		match def.skill_id:
			&"evocation":
				assert_gt(def.cast_range, 0.0, "%s bolts have range" % def.id)
				assert_eq(def.duration, 0.0, "%s bolts are instant" % def.id)
			&"warding":
				assert_gt(def.duration, 0.0, "%s wards have a duration" % def.id)
				assert_eq(def.cast_range, 0.0, "%s wards are self-cast" % def.id)
			&"mending":
				assert_eq(def.cast_range, 0.0, "%s mends are self-cast" % def.id)
				assert_eq(def.duration, 0.0, "%s mends are instant" % def.id)
