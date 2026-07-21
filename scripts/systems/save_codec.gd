class_name SaveCodec
extends RefCounted
## Pure dict <-> resource codecs for the save payload (spec 007). All static,
## no scene tree, no disk: decodes receive their resolvers (the BalanceConfig,
## the id -> ItemDef map) as parameters. Every JSON type coercion lives here —
## JSON.parse_string returns String keys and float numbers, so decodes rebuild
## typed dictionaries and arrays explicitly. Malformed shapes return null
## behind push_warning guards; unknown item ids and equipment slots are
## skipped with a warning so a content rename never bricks a save.

const SAVE_VERSION := 1

const _SHEET_KEYS: Array[String] = [
	"attributes",
	"skills",
	"skill_xp",
	"major_skills",
	"level",
	"unspent_attribute_points",
	"major_level_ups",
]


static func sheet_to_dict(sheet: CharacterSheet) -> Dictionary:
	return {
		"attributes": _ids_to_strings(sheet.attributes),
		"skills": _ids_to_strings(sheet.skills),
		"skill_xp": _ids_to_strings(sheet.skill_xp),
		"major_skills": _array_to_strings(sheet.major_skills),
		"level": sheet.level,
		"unspent_attribute_points": sheet.unspent_attribute_points,
		"major_level_ups": sheet.major_level_ups,
	}


## Rebuilds a sheet from payload data; config is reassigned from the given
## balance, never read from the save. Null on any malformed shape.
static func sheet_from_dict(data: Dictionary, balance: BalanceConfig) -> CharacterSheet:
	if not data.has_all(_SHEET_KEYS):
		push_warning("sheet_from_dict: missing fields")
		return null
	var sections_valid := (
		_is_id_number_dict(data["attributes"])
		and _is_id_number_dict(data["skills"])
		and _is_id_number_dict(data["skill_xp"])
		and _is_string_array(data["major_skills"])
		and (data["level"] is float or data["level"] is int)
		and (data["unspent_attribute_points"] is float or data["unspent_attribute_points"] is int)
		and (data["major_level_ups"] is float or data["major_level_ups"] is int)
	)
	if not sections_valid:
		push_warning("sheet_from_dict: malformed fields")
		return null
	var sheet := CharacterSheet.new()
	sheet.config = balance
	sheet.attributes = _strings_to_id_ints(data["attributes"])
	sheet.skills = _strings_to_id_ints(data["skills"])
	sheet.skill_xp = _strings_to_id_ints(data["skill_xp"])
	sheet.major_skills = _strings_to_id_array(data["major_skills"])
	sheet.level = int(data["level"])
	sheet.unspent_attribute_points = int(data["unspent_attribute_points"])
	sheet.major_level_ups = int(data["major_level_ups"])
	return sheet


static func inventory_to_dict(inventory: Inventory) -> Dictionary:
	var stacks: Array[Dictionary] = []
	for stack: ItemStack in inventory.stacks:
		stacks.append({"item": String(stack.item.id), "count": stack.count})
	var equipment := {}
	for slot: StringName in inventory.equipment:
		equipment[String(slot)] = String(inventory.equipment[slot].id)
	return {"gold": inventory.gold, "stacks": stacks, "equipment": equipment}


## Rebuilds an inventory, resolving item ids through the given map. Fields
## are assigned directly — the save was produced by the equip/add rules, so
## decode trusts it rather than replaying them. Null on malformed shape;
## unknown item ids and slots skip that stack/slot with a warning.
static func inventory_from_dict(
	data: Dictionary, items: Dictionary[StringName, ItemDef]
) -> Inventory:
	var shape_valid := (
		data.has_all(["gold", "stacks", "equipment"])
		and (data["gold"] is float or data["gold"] is int)
		and data["stacks"] is Array
		and data["equipment"] is Dictionary
	)
	if not shape_valid:
		push_warning("inventory_from_dict: malformed shape")
		return null
	var stacks: Array[ItemStack] = []
	for raw_stack: Variant in data["stacks"] as Array:
		if not _is_stack_dict(raw_stack):
			push_warning("inventory_from_dict: malformed stack entry")
			return null
		var stack_data := raw_stack as Dictionary
		var item_id := StringName(stack_data["item"] as String)
		if not items.has(item_id):
			push_warning("inventory_from_dict: unknown item '%s' skipped" % item_id)
			continue
		var stack := ItemStack.new()
		stack.item = items[item_id]
		stack.count = int(stack_data["count"])
		stacks.append(stack)
	var equipment: Dictionary[StringName, ItemDef] = {}
	var raw_equipment := data["equipment"] as Dictionary
	for raw_slot: Variant in raw_equipment:
		if not (raw_slot is String and raw_equipment[raw_slot] is String):
			push_warning("inventory_from_dict: malformed equipment entry")
			return null
		var slot := StringName(raw_slot as String)
		var item_id := StringName(raw_equipment[raw_slot] as String)
		if not Inventory.EQUIPMENT_SLOTS.has(slot):
			push_warning("inventory_from_dict: unknown slot '%s' skipped" % slot)
			continue
		if not items.has(item_id):
			push_warning("inventory_from_dict: unknown item '%s' skipped" % item_id)
			continue
		equipment[slot] = items[item_id]
	var inventory := Inventory.new()
	inventory.gold = int(data["gold"])
	inventory.stacks = stacks
	inventory.equipment = equipment
	return inventory


static func journal_to_dict(journal: Journal) -> Dictionary:
	return {
		"entries": _array_to_strings(journal.entries),
		"known_topics": _array_to_strings(journal.known_topics),
	}


## Rebuilds a journal; array order is preserved (order IS chronology).
## Null on any malformed shape.
static func journal_from_dict(data: Dictionary) -> Journal:
	var shape_valid := (
		data.has_all(["entries", "known_topics"])
		and _is_string_array(data["entries"])
		and _is_string_array(data["known_topics"])
	)
	if not shape_valid:
		push_warning("journal_from_dict: malformed shape")
		return null
	var journal := Journal.new()
	journal.entries = _strings_to_id_array(data["entries"])
	journal.known_topics = _strings_to_id_array(data["known_topics"])
	return journal


static func _ids_to_strings(source: Dictionary[StringName, int]) -> Dictionary:
	var result := {}
	for key: StringName in source:
		result[String(key)] = source[key]
	return result


static func _array_to_strings(source: Array[StringName]) -> Array:
	var result: Array[String] = []
	for value: StringName in source:
		result.append(String(value))
	return result


static func _strings_to_id_ints(raw: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for key: Variant in raw:
		result[StringName(key as String)] = int(raw[key])
	return result


static func _strings_to_id_array(raw: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in raw:
		result.append(StringName(value as String))
	return result


static func _is_id_number_dict(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value as Dictionary:
		if not key is String:
			return false
		var entry: Variant = (value as Dictionary)[key]
		if not (entry is float or entry is int):
			return false
	return true


static func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value as Array:
		if not entry is String:
			return false
	return true


static func _is_stack_dict(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var entry := value as Dictionary
	if not entry.has_all(["item", "count"]):
		return false
	return entry["item"] is String and (entry["count"] is float or entry["count"] is int)
