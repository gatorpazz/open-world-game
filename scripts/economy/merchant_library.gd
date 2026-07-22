class_name MerchantLibrary
extends RefCounted
## Cached id -> MerchantDef lookup over data/merchants/ (spec 016). Loaded lazily
## on first use — the ItemLibrary/FactionLibrary shape, byte for byte. The
## id == filename stem convention is enforced by tests/data/test_merchant_defs.gd.

const DIR := "res://data/merchants"

static var _merchants: Dictionary[StringName, MerchantDef] = {}


static func get_merchants() -> Dictionary[StringName, MerchantDef]:
	if _merchants.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var merchant := load(DIR.path_join(file_name)) as MerchantDef
			if merchant != null:
				_merchants[merchant.id] = merchant
	return _merchants


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_merchants.clear()
