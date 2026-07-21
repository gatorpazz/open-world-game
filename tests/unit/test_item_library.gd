extends GutTest
## Unit tests for ItemLibrary (spec 007, criterion 6).


func before_each() -> void:
	ItemLibrary.reset()


func after_all() -> void:
	ItemLibrary.reset()


func test_loads_every_item_keyed_by_id() -> void:
	var items := ItemLibrary.get_items()
	var file_count := 0
	for file_name: String in ResourceLoader.list_directory(ItemLibrary.DIR):
		if file_name.ends_with(".tres"):
			file_count += 1
	assert_eq(items.size(), file_count, "one entry per data file")
	for item_id: StringName in items:
		assert_eq(items[item_id].id, item_id, "keyed by the item's own id")


func test_items_are_the_canonical_cached_loads() -> void:
	var items := ItemLibrary.get_items()
	for item_id: StringName in items:
		var direct := load(ItemLibrary.DIR.path_join("%s.tres" % item_id)) as ItemDef
		assert_same(items[item_id], direct, "library item is the cached canonical load")


func test_caches_between_calls_and_reset_clears() -> void:
	var first := ItemLibrary.get_items()
	assert_same(first, ItemLibrary.get_items(), "second call returns the cache")
	ItemLibrary.reset()
	assert_eq(first.size(), 0, "reset clears the shared dictionary")
