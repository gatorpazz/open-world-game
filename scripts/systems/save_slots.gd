class_name SaveSlots
extends RefCounted
## Save slots (spec 025): a reserved quicksave slot + numbered manual slots under
## a saves directory. Each slot file wraps the versioned SaveCodec payload in a
## metadata header — {"meta": {...}, "save": <payload>}. read_payload tolerates a
## legacy bare file (an old user://save.json) via data.get("save", data), so
## pre-025 saves still load. Static helpers over a base dir; Game holds the dir
## (tests point it at a scratch dir, the save_path precedent).

const QUICKSAVE := &"quicksave"
## quicksave + slot_1..slot_6, in menu order.
const SLOT_IDS: Array[StringName] = [
	&"quicksave",
	&"slot_1",
	&"slot_2",
	&"slot_3",
	&"slot_4",
	&"slot_5",
	&"slot_6",
]


static func slot_path(dir: String, slot_id: StringName) -> String:
	return dir.path_join("%s.json" % slot_id)


static func exists(dir: String, slot_id: StringName) -> bool:
	return FileAccess.file_exists(slot_path(dir, slot_id))


## Writes a slot: the versioned payload wrapped under a metadata header. Creates
## the saves directory on first write. False on a file error.
static func write(dir: String, slot_id: StringName, meta: Dictionary, payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(slot_path(dir, slot_id), FileAccess.WRITE)
	if file == null:
		push_warning("SaveSlots.write: cannot open '%s'" % slot_path(dir, slot_id))
		return false
	file.store_string(JSON.stringify({"meta": meta, "save": payload}, "\t"))
	return true


## The versioned payload of a slot, or {} when absent/corrupt. A legacy bare file
## (no meta/save wrapper) returns its whole dict — data.get("save", data).
static func read_payload(dir: String, slot_id: StringName) -> Dictionary:
	var data := _read_file(dir, slot_id)
	if data.is_empty():
		return {}
	var payload: Variant = data.get("save", data)
	return payload if payload is Dictionary else {}


## The metadata header of a slot, or {} when absent/legacy/corrupt.
static func read_meta(dir: String, slot_id: StringName) -> Dictionary:
	var meta: Variant = _read_file(dir, slot_id).get("meta")
	return meta if meta is Dictionary else {}


## Every slot in menu order, each with whether it is filled and its metadata.
static func list_slots(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot_id: StringName in SLOT_IDS:
		out.append({"id": slot_id, "filled": exists(dir, slot_id), "meta": read_meta(dir, slot_id)})
	return out


static func delete(dir: String, slot_id: StringName) -> void:
	if exists(dir, slot_id):
		DirAccess.remove_absolute(slot_path(dir, slot_id))


## The most-recently-written slot id (by file modification time), or &"" when no
## slot exists — the title's one-click Continue target (spec 025).
static func most_recent(dir: String) -> StringName:
	var best := &""
	var best_time := -1
	for slot_id: StringName in SLOT_IDS:
		if not exists(dir, slot_id):
			continue
		var modified := FileAccess.get_modified_time(slot_path(dir, slot_id))
		if modified >= best_time:
			best_time = modified
			best = slot_id
	return best


## One-time back-compat: an old bare save.json is moved into the quicksave slot
## if that slot is empty. read_payload's bare-file fallback then loads it; its
## metadata reads empty (a legacy save carries none). Idempotent.
static func adopt_legacy(dir: String, legacy_path: String) -> void:
	if exists(dir, QUICKSAVE) or not FileAccess.file_exists(legacy_path):
		return
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.rename_absolute(legacy_path, slot_path(dir, QUICKSAVE))


static func _read_file(dir: String, slot_id: StringName) -> Dictionary:
	if not exists(dir, slot_id):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(slot_path(dir, slot_id))) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
