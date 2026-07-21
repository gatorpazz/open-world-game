extends GutTest
## Unit tests for SpellLibrary (spec 008).


func before_each() -> void:
	SpellLibrary.reset()


func after_all() -> void:
	SpellLibrary.reset()


func test_loads_every_spell_keyed_by_id() -> void:
	var spells := SpellLibrary.get_spells()
	var file_count := 0
	for file_name: String in ResourceLoader.list_directory(SpellLibrary.DIR):
		if file_name.ends_with(".tres"):
			file_count += 1
	assert_eq(spells.size(), file_count, "one entry per data file")
	for spell_id: StringName in spells:
		assert_eq(spells[spell_id].id, spell_id, "keyed by the spell's own id")


func test_spells_are_the_canonical_cached_loads() -> void:
	var spells := SpellLibrary.get_spells()
	for spell_id: StringName in spells:
		var direct := load(SpellLibrary.DIR.path_join("%s.tres" % spell_id)) as SpellDef
		assert_same(spells[spell_id], direct, "library spell is the cached canonical load")


func test_caches_between_calls_and_reset_clears() -> void:
	var first := SpellLibrary.get_spells()
	assert_same(first, SpellLibrary.get_spells(), "second call returns the cache")
	SpellLibrary.reset()
	assert_eq(first.size(), 0, "reset clears the shared dictionary")
