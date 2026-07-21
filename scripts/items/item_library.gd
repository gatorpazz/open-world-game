class_name ItemLibrary
extends RefCounted
## Cached id -> ItemDef lookup over data/items/ (spec 007). Loaded lazily
## on first use — the QuestLibrary/DialogueLibrary shape, byte for byte.
## Save decoding resolves item ids through this; the id == filename stem
## convention is enforced by tests/data/test_item_defs.gd.

const DIR := "res://data/items"

static var _items: Dictionary[StringName, ItemDef] = {}


static func get_items() -> Dictionary[StringName, ItemDef]:
	if _items.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var item := load(DIR.path_join(file_name)) as ItemDef
			if item != null:
				_items[item.id] = item
	return _items


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_items.clear()
