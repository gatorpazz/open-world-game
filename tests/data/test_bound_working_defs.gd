extends GutTest
## Validates every BoundWorkingDef in data/bound_workings/ (spec 023, acceptance
## criterion 1): unique ids matching filenames, known trigger+effect, resolvable
## aspect skill_id / fortify subject, and the effect-field invariants.

const DIR := "res://data/bound_workings"
const SKILLS_DIR := "res://data/skills"
## Spec 023 ships 3 bound workings (one per hook).
const EXPECTED_COUNT := 3

var _defs: Array[BoundWorkingDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var def: BoundWorkingDef = load(DIR.path_join(file_name)) as BoundWorkingDef
		assert_not_null(def, "%s should load as a BoundWorkingDef" % file_name)
		if def != null:
			_defs.append(def)


func _skill_exists(skill_id: StringName) -> bool:
	return ResourceLoader.exists(SKILLS_DIR.path_join("%s.tres" % skill_id))


func test_expected_count() -> void:
	assert_eq(_defs.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding bound workings")


func test_library_sees_every_def() -> void:
	assert_eq(BoundWorkingLibrary.get_workings().size(), _defs.size(), "the library loads them all")


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for def: BoundWorkingDef in _defs:
		assert_ne(def.id, &"", "%s has an id" % def.resource_path)
		assert_false(seen.has(def.id), "id %s is unique" % def.id)
		seen[def.id] = true
		var file_stem := def.resource_path.get_file().get_basename()
		assert_eq(String(def.id), file_stem, "id matches filename for %s" % def.resource_path)


func test_display_names_and_descriptions_are_non_empty() -> void:
	for def: BoundWorkingDef in _defs:
		assert_ne(def.display_name, "", "%s has a display name" % def.id)
		assert_ne(def.description, "", "%s has a description" % def.id)


func test_trigger_and_effect_are_known() -> void:
	for def: BoundWorkingDef in _defs:
		assert_has(BoundWorkingDef.TRIGGERS, def.trigger, "%s trigger is known" % def.id)
		assert_has(BoundWorkingDef.EFFECTS, def.effect, "%s effect is known" % def.id)


func test_aspect_skill_resolves_when_set() -> void:
	for def: BoundWorkingDef in _defs:
		if def.skill_id == &"":
			continue
		assert_true(_skill_exists(def.skill_id), "%s skill_id %s resolves" % [def.id, def.skill_id])


func test_effect_field_invariants() -> void:
	for def: BoundWorkingDef in _defs:
		match def.effect:
			&"fortify":
				assert_ne(def.subject, &"", "%s fortify names a subject" % def.id)
				assert_true(_skill_exists(def.subject), "%s subject resolves" % def.id)
			&"damage", &"heal":
				assert_ne(def.skill_id, &"", "%s (%s) names an aspect skill" % [def.id, def.effect])
			_:
				assert_eq(def.subject, &"", "%s: only fortify names a subject" % def.id)


func test_magnitudes_are_positive() -> void:
	for def: BoundWorkingDef in _defs:
		assert_gt(def.magnitude, 0.0, "%s magnitude is positive" % def.id)
		assert_gte(def.duration, 0.0, "%s duration is non-negative" % def.id)


func test_the_vocabularies_are_defined() -> void:
	assert_has(BoundWorkingDef.TRIGGERS, &"constant", "constant is a trigger")
	assert_has(BoundWorkingDef.TRIGGERS, &"on_hit", "on_hit is a trigger")
	assert_has(BoundWorkingDef.TRIGGERS, &"on_use", "on_use is a trigger")
