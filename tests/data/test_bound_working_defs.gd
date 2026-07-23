extends GutTest
## Smoke-validates the BoundWorkingDef type + BoundWorkingLibrary (spec 023,
## acceptance criterion 1). The per-def content invariants (trigger/effect/
## aspect resolution) land in commit 7 alongside the first defs; until then the
## library is empty by design.


func test_library_loads_and_is_empty_until_content() -> void:
	# Bumped to the real count in commit 7 when the first bound workings ship.
	assert_eq(BoundWorkingLibrary.get_workings().size(), 0, "no bound workings ship until commit 7")


func test_trigger_and_effect_vocabularies_are_defined() -> void:
	assert_has(BoundWorkingDef.TRIGGERS, &"constant", "constant is a trigger")
	assert_has(BoundWorkingDef.TRIGGERS, &"on_hit", "on_hit is a trigger")
	assert_has(BoundWorkingDef.TRIGGERS, &"on_use", "on_use is a trigger")
	for effect: StringName in [&"damage", &"heal", &"fortify", &"ward", &"resist"]:
		assert_has(BoundWorkingDef.EFFECTS, effect, "%s is an effect" % effect)


func test_a_fresh_def_is_an_unscaled_plain_charm() -> void:
	var def := BoundWorkingDef.new()
	assert_eq(def.skill_id, &"", "a fresh def has no aspect (flat magnitude)")
	assert_eq(def.subject, &"", "a fresh def fortifies nothing")
	assert_eq(def.magnitude, 0.0, "a fresh def has no magnitude")


func test_item_carries_an_optional_bound_working() -> void:
	var item := ItemDef.new()
	assert_null(item.bound_working, "a plain item carries no bound working")
	var working := BoundWorkingDef.new()
	item.bound_working = working
	assert_same(item.bound_working, working, "an item can carry a bound working")
