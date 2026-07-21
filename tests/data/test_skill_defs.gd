extends GutTest
## Validates every SkillDef resource in data/skills/ (spec 001, criterion 5).

const SKILLS_DIR := "res://data/skills"
const EXPECTED_SKILL_COUNT := 12
const VALID_ATTRIBUTES: Array[StringName] = [
	&"strength",
	&"endurance",
	&"agility",
	&"speed",
	&"intellect",
	&"willpower",
	&"presence",
]

var _skills: Array[SkillDef] = []


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(SKILLS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var skill: SkillDef = load(SKILLS_DIR.path_join(file_name)) as SkillDef
		assert_not_null(skill, "%s should load as a SkillDef" % file_name)
		if skill != null:
			_skills.append(skill)


func test_exactly_twelve_skills() -> void:
	assert_eq(_skills.size(), EXPECTED_SKILL_COUNT)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for skill: SkillDef in _skills:
		assert_ne(skill.id, &"", "%s has an id" % skill.resource_path)
		assert_false(seen.has(skill.id), "id %s is unique" % skill.id)
		seen[skill.id] = true
		var file_stem := skill.resource_path.get_file().get_basename()
		assert_eq(String(skill.id), file_stem, "id matches filename for %s" % skill.resource_path)


func test_display_names_are_non_empty() -> void:
	for skill: SkillDef in _skills:
		assert_ne(skill.display_name, "", "%s has a display name" % skill.id)


func test_governing_attributes_are_valid() -> void:
	for skill: SkillDef in _skills:
		assert_has(
			VALID_ATTRIBUTES,
			skill.governing_attribute,
			"%s governing attribute is valid" % skill.id
		)


func test_archetypes_are_valid() -> void:
	for skill: SkillDef in _skills:
		assert_has(SkillDef.ARCHETYPES, skill.archetype, "%s archetype is valid" % skill.id)
