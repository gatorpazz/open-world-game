class_name SaveCodec
extends RefCounted
## Pure dict <-> resource codecs for the save payload (spec 007). All static,
## no scene tree, no disk: decodes receive their resolvers (the BalanceConfig,
## the id -> ItemDef map) as parameters. Every JSON type coercion lives here —
## JSON.parse_string returns String keys and float numbers, so decodes rebuild
## typed dictionaries and arrays explicitly. Malformed shapes return null
## behind push_warning guards; unknown item ids and equipment slots are
## skipped with a warning so a content rename never bricks a save.

## Bumped to 2 by the faction spec (015): "factions" section + first migration.
## Bumped to 3 by the barter spec (016): a "stash" section (the Game-owned
## player bank) + v2 -> v3 migration seeding an empty stash.
## Bumped to 4 by the crime spec (017): a "bounty" section (the per-jurisdiction
## legal debt) + v3 -> v4 migration seeding an empty ledger.
## Bumped to 5 by the magic-v2 spec (018): a "notice" section (the never-clearing
## regard ledger) + v4 -> v5 migration seeding notice 0.
## Bumped to 6 by the clock spec (020): a "clock" section (circuit-day + bell) +
## v5 -> v6 migration seeding a start time.
## Bumped to 7 by the persuasion spec (019): a "disposition" section (the per-NPC
## modifier ledger) + v6 -> v7 migration seeding an empty ledger.
## Bumped to 8 by the save-furniture spec (025): a top-level "playtime" scalar
## (real seconds played) + v7 -> v8 migration seeding 0. Migrations chain (a v1
## save runs v1 -> v2 -> ... -> v8).
const SAVE_VERSION := 8

const _SHEET_KEYS: Array[String] = [
	"attributes",
	"skills",
	"skill_xp",
	"major_skills",
	"level",
	"unspent_attribute_points",
	"major_level_ups",
]
const _ROOT_KEYS: Array[String] = [
	"save_version",
	"scene_path",
	"player",
	"sheet",
	"inventory",
	"journal",
	"factions",
	"stash",
	"bounty",
	"notice",
	"clock",
	"disposition",
	"playtime",
]
const _PLAYER_KEYS: Array[String] = [
	"transform",
	"head_pitch",
	"current_health",
	"current_mana",
	"current_stamina",
]
const _TRANSFORM_FLOATS := 12


## Everything one save holds, in both directions: built by Game at save
## time, returned whole by decode_save — or not at all (null), never half.
class SaveState:
	var scene_path: String
	var player_transform: Transform3D
	var head_pitch: float
	var current_health: float
	var current_mana: float
	var current_stamina: float
	var sheet: CharacterSheet
	var inventory: Inventory
	var journal: Journal
	var faction_standing: FactionStanding
	## The Game-owned player bank (spec 016) — the Inventory shape again, its
	## own save section.
	var stash: Inventory
	## The per-jurisdiction bounty ledger (spec 017), its own save section.
	var bounty: BountyLedger
	## The never-clearing notice ledger (spec 018), its own save section.
	var notice: NoticeLedger
	## The in-game clock (spec 020), its own save section.
	var clock: WorldClock
	## The per-NPC disposition modifier ledger (spec 019), its own save section.
	var disposition: DispositionLedger
	## Total real seconds played (spec 025) — a top-level scalar, not a section.
	var playtime: float


static func encode_save(state: SaveState) -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"scene_path": state.scene_path,
		"player":
		{
			"transform": transform_to_array(state.player_transform),
			"head_pitch": state.head_pitch,
			"current_health": state.current_health,
			"current_mana": state.current_mana,
			"current_stamina": state.current_stamina,
		},
		"sheet": sheet_to_dict(state.sheet),
		"inventory": inventory_to_dict(state.inventory),
		"journal": journal_to_dict(state.journal),
		"factions": factions_to_dict(state.faction_standing),
		"stash": inventory_to_dict(state.stash),
		"bounty": bounty_to_dict(state.bounty),
		"notice": notice_to_dict(state.notice),
		"clock": clock_to_dict(state.clock),
		"disposition": disposition_to_dict(state.disposition),
		"playtime": state.playtime,
	}


## Validates and rebuilds a full SaveState, or returns null — atomic by
## design, so a caller never applies half a save. The save_version equality
## check is the future migration hook; the scene_path allow-list is the
## security boundary (a tampered save must never load outside res://).
static func decode_save(
	data: Dictionary,
	balance: BalanceConfig,
	items: Dictionary[StringName, ItemDef],
	factions: Dictionary[StringName, FactionDef]
) -> SaveState:
	# Version is handled BEFORE the section check so an older save can be
	# migrated up (a migration adds the sections a newer version expects).
	if not (
		data.has("save_version") and (data["save_version"] is float or data["save_version"] is int)
	):
		push_warning("decode_save: malformed save_version")
		return null
	var version := int(data["save_version"])
	if version > SAVE_VERSION:
		push_warning("decode_save: unsupported save_version %d" % version)
		return null
	if version < SAVE_VERSION:
		data = _migrated(data, version, factions)
		if data.is_empty():
			push_warning("decode_save: no migration path from save_version %d" % version)
			return null
	if not data.has_all(_ROOT_KEYS):
		push_warning("decode_save: missing sections")
		return null
	if not data["scene_path"] is String:
		push_warning("decode_save: malformed scene_path")
		return null
	var scene_path := data["scene_path"] as String
	if not _is_scene_path(scene_path) or not ResourceLoader.exists(scene_path):
		push_warning("decode_save: scene_path '%s' refused" % scene_path)
		return null
	if not _is_player_dict(data["player"]):
		push_warning("decode_save: malformed player section")
		return null
	var sections_are_dicts := (
		data["sheet"] is Dictionary
		and data["inventory"] is Dictionary
		and data["journal"] is Dictionary
		and data["factions"] is Dictionary
		and data["stash"] is Dictionary
		and data["bounty"] is Dictionary
		and data["notice"] is Dictionary
		and data["clock"] is Dictionary
		and data["disposition"] is Dictionary
	)
	if not sections_are_dicts:
		push_warning("decode_save: malformed identity sections")
		return null
	if not (data["playtime"] is float or data["playtime"] is int):
		push_warning("decode_save: malformed playtime")
		return null
	var sheet := sheet_from_dict(data["sheet"] as Dictionary, balance)
	var inventory := inventory_from_dict(data["inventory"] as Dictionary, items)
	var journal := journal_from_dict(data["journal"] as Dictionary)
	var faction_standing := factions_from_dict(data["factions"] as Dictionary)
	var stash := inventory_from_dict(data["stash"] as Dictionary, items)
	var bounty := bounty_from_dict(data["bounty"] as Dictionary)
	var notice := notice_from_dict(data["notice"] as Dictionary)
	var clock := clock_from_dict(data["clock"] as Dictionary)
	var disposition := disposition_from_dict(data["disposition"] as Dictionary)
	if (
		sheet == null
		or inventory == null
		or journal == null
		or faction_standing == null
		or stash == null
		or bounty == null
		or notice == null
		or clock == null
		or disposition == null
	):
		return null
	var player := data["player"] as Dictionary
	var state := SaveState.new()
	state.scene_path = scene_path
	state.player_transform = transform_from_array(player["transform"] as Array)
	state.head_pitch = float(player["head_pitch"])
	state.current_health = float(player["current_health"])
	state.current_mana = float(player["current_mana"])
	state.current_stamina = float(player["current_stamina"])
	state.sheet = sheet
	state.inventory = inventory
	state.journal = journal
	state.faction_standing = faction_standing
	state.stash = stash
	state.bounty = bounty
	state.notice = notice
	state.clock = clock
	state.disposition = disposition
	state.playtime = float(data["playtime"])
	return state


## Flattens a Transform3D to 12 floats: basis x/y/z axes, then origin.
static func transform_to_array(transform: Transform3D) -> Array:
	var values: Array[float] = []
	for axis: Vector3 in [
		transform.basis.x, transform.basis.y, transform.basis.z, transform.origin
	]:
		values.append(axis.x)
		values.append(axis.y)
		values.append(axis.z)
	return values


## Rebuilds a Transform3D from 12 floats; the basis is orthonormalized to
## kill JSON double -> 32-bit float drift. Callers validate the array shape.
static func transform_from_array(values: Array) -> Transform3D:
	var basis := Basis(
		Vector3(values[0], values[1], values[2]),
		Vector3(values[3], values[4], values[5]),
		Vector3(values[6], values[7], values[8])
	)
	var origin := Vector3(values[9], values[10], values[11])
	return Transform3D(basis.orthonormalized(), origin)


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
		stacks.append({"item": String(stack.item.id), "count": stack.count, "stolen": stack.stolen})
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
		# Optional — pre-017 saves have no stolen key; those stacks decode clean.
		stack.stolen = bool(stack_data.get("stolen", false))
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
		"entry_days": journal.entry_days.duplicate(),
		"known_topics": _array_to_strings(journal.known_topics),
	}


## Rebuilds a journal; array order is preserved (order IS chronology).
## entry_days (spec 020) is optional — a pre-020 save has none, so its entries
## back-fill to day 0 (unstamped) and stay aligned for future add_entry calls.
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
	var days: Array[int] = []
	if data.has("entry_days") and data["entry_days"] is Array:
		for value: Variant in data["entry_days"] as Array:
			days.append(int(value))
	while days.size() < journal.entries.size():
		days.append(0)  # pre-020 entries are unstamped
	journal.entry_days = days
	return journal


static func factions_to_dict(standing: FactionStanding) -> Dictionary:
	return {
		"reputation": _ids_to_strings(standing.reputation),
		"rank": _ids_to_strings(standing.rank),
	}


## Rebuilds the faction standing (spec 015): two id -> int maps, coerced from
## JSON's String keys / float numbers like the sheet's dictionaries. Null on
## any malformed shape.
static func factions_from_dict(data: Dictionary) -> FactionStanding:
	var shape_valid := (
		data.has_all(["reputation", "rank"])
		and _is_id_number_dict(data["reputation"])
		and _is_id_number_dict(data["rank"])
	)
	if not shape_valid:
		push_warning("factions_from_dict: malformed shape")
		return null
	var standing := FactionStanding.new()
	standing.reputation = _strings_to_id_ints(data["reputation"])
	standing.rank = _strings_to_id_ints(data["rank"])
	return standing


static func bounty_to_dict(ledger: BountyLedger) -> Dictionary:
	return {"bounty": _ids_to_strings(ledger.bounty)}


## Rebuilds the bounty ledger (spec 017): one jurisdiction -> int map, coerced
## from JSON's String keys / float numbers like the faction maps. Null on any
## malformed shape.
static func bounty_from_dict(data: Dictionary) -> BountyLedger:
	if not (data.has("bounty") and _is_id_number_dict(data["bounty"])):
		push_warning("bounty_from_dict: malformed shape")
		return null
	var ledger := BountyLedger.new()
	ledger.bounty = _strings_to_id_ints(data["bounty"])
	return ledger


static func disposition_to_dict(ledger: DispositionLedger) -> Dictionary:
	return {"modifier": _ids_to_strings(ledger.modifier)}


## Rebuilds the disposition ledger (spec 019): one npc_id -> int modifier map,
## coerced from JSON's String keys / float numbers like the bounty map. Null on
## any malformed shape.
static func disposition_from_dict(data: Dictionary) -> DispositionLedger:
	if not (data.has("modifier") and _is_id_number_dict(data["modifier"])):
		push_warning("disposition_from_dict: malformed shape")
		return null
	var ledger := DispositionLedger.new()
	ledger.modifier = _strings_to_id_ints(data["modifier"])
	return ledger


static func notice_to_dict(ledger: NoticeLedger) -> Dictionary:
	return {"notice": ledger.notice}


## Rebuilds the notice ledger (spec 018): a single int, coerced from JSON's
## float. Null on any malformed shape.
static func notice_from_dict(data: Dictionary) -> NoticeLedger:
	if not (data.has("notice") and (data["notice"] is float or data["notice"] is int)):
		push_warning("notice_from_dict: malformed shape")
		return null
	var ledger := NoticeLedger.new()
	ledger.notice = int(data["notice"])
	return ledger


static func clock_to_dict(clock: WorldClock) -> Dictionary:
	return {"day": clock.day, "bell": clock.bell}


## Rebuilds the clock (spec 020): an int day + a float bell, coerced from JSON's
## floats. Null on any malformed shape.
static func clock_from_dict(data: Dictionary) -> WorldClock:
	var shape_valid := (
		data.has_all(["day", "bell"])
		and (data["day"] is float or data["day"] is int)
		and (data["bell"] is float or data["bell"] is int)
	)
	if not shape_valid:
		push_warning("clock_from_dict: malformed shape")
		return null
	var clock := WorldClock.new()
	clock.day = int(data["day"])
	clock.bell = float(data["bell"])
	return clock


## Upgrades an older save dict to the current version, or returns {} when no
## path exists. Migrations run in sequence: a v1 save chains v1 -> v2 -> v3 ->
## v4, each step adding the sections its target version expects.
static func _migrated(
	data: Dictionary, version: int, factions: Dictionary[StringName, FactionDef]
) -> Dictionary:
	var result := data
	var current := version
	if current == 1:
		result = _migrate_v1_to_v2(result, factions)
		current = 2
	if current == 2:
		result = _migrate_v2_to_v3(result)
		current = 3
	if current == 3:
		result = _migrate_v3_to_v4(result)
		current = 4
	if current == 4:
		result = _migrate_v4_to_v5(result)
		current = 5
	if current == 5:
		result = _migrate_v5_to_v6(result)
		current = 6
	if current == 6:
		result = _migrate_v6_to_v7(result)
		current = 7
	if current == 7:
		result = _migrate_v7_to_v8(result)
		current = 8
	if current != SAVE_VERSION:
		return {}
	return result


## v1 had no factions section. Seed it from the joined_* journal entries the
## same way runtime reconcile does — a v1 save is a v2 save whose faction
## records were never seeded. The journal itself is untouched.
static func _migrate_v1_to_v2(
	data: Dictionary, factions: Dictionary[StringName, FactionDef]
) -> Dictionary:
	var standing := FactionStanding.new()
	FactionRules.reconcile(standing, _migration_journal_entries(data), factions)
	data["factions"] = factions_to_dict(standing)
	data["save_version"] = 2
	return data


## v2 had no stash section. Seed an empty player bank — a v2 save is a v3 save
## whose stash was never opened. The rest of the payload is untouched.
static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	data["stash"] = inventory_to_dict(Inventory.new())
	data["save_version"] = 3
	return data


## v3 had no bounty section. Seed an empty ledger — a v3 save is a v4 save whose
## player never committed a witnessed crime. The rest of the payload is
## untouched.
static func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	data["bounty"] = bounty_to_dict(BountyLedger.new())
	data["save_version"] = 4
	return data


## v4 had no notice section. Seed a clean ledger — a v4 save is a v5 save whose
## player never drew unlicensed regard. The rest of the payload is untouched.
static func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	data["notice"] = notice_to_dict(NoticeLedger.new())
	data["save_version"] = 5
	return data


## v5 had no clock section. Seed a start time — a v5 save is a v6 save that
## predates the bells. The rest of the payload is untouched.
static func _migrate_v5_to_v6(data: Dictionary) -> Dictionary:
	data["clock"] = clock_to_dict(WorldClock.new())
	data["save_version"] = 6
	return data


## v6 had no disposition section. Seed an empty ledger — a v6 save is a v7 save
## whose player never moved a stranger's regard. The rest is untouched.
static func _migrate_v6_to_v7(data: Dictionary) -> Dictionary:
	data["disposition"] = disposition_to_dict(DispositionLedger.new())
	data["save_version"] = 7
	return data


## v7 had no playtime. Seed 0 — a v7 save is a v8 save whose clock was never
## totted up in real seconds. The rest is untouched.
static func _migrate_v7_to_v8(data: Dictionary) -> Dictionary:
	data["playtime"] = 0.0
	data["save_version"] = 8
	return data


## Best-effort read of the journal's entry ids from a raw save dict, for
## migration only — malformed or missing shapes yield an empty list rather
## than failing (the full journal validation happens later in decode).
static func _migration_journal_entries(data: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (data.has("journal") and data["journal"] is Dictionary):
		return result
	var journal := data["journal"] as Dictionary
	if not (journal.has("entries") and journal["entries"] is Array):
		return result
	for value: Variant in journal["entries"] as Array:
		if value is String:
			result.append(StringName(value as String))
	return result


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


## The security boundary for the scene changer: res:// only (never user://)
## and a scene extension, so a tampered save cannot smuggle a non-scene
## resource into load().instantiate(). Extension check over a
## ResourceLoader type hint — hints are ignored for already-cached files.
static func _is_scene_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	return path.ends_with(".tscn") or path.ends_with(".scn")


static func _is_player_dict(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var player := value as Dictionary
	if not player.has_all(_PLAYER_KEYS):
		return false
	if not _is_number_array(player["transform"], _TRANSFORM_FLOATS):
		return false
	for key: String in ["head_pitch", "current_health", "current_mana", "current_stamina"]:
		if not (player[key] is float or player[key] is int):
			return false
	return true


static func _is_number_array(value: Variant, expected_size: int) -> bool:
	if not value is Array or (value as Array).size() != expected_size:
		return false
	for entry: Variant in value as Array:
		if not (entry is float or entry is int):
			return false
	return true


static func _is_stack_dict(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var entry := value as Dictionary
	if not entry.has_all(["item", "count"]):
		return false
	return entry["item"] is String and (entry["count"] is float or entry["count"] is int)
