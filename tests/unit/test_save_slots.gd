extends GutTest
## SaveSlots (spec 025, acceptance criterion 1): the wrapped slot file format,
## metadata, list/delete, legacy bare-file back-compat, and legacy adoption.
## Runs against a scratch saves directory.

const DIR := "user://test_save_slots"
const LEGACY := "user://test_legacy_save.json"


func before_each() -> void:
	_clear()


func after_each() -> void:
	_clear()


func _clear() -> void:
	for slot_id: StringName in SaveSlots.SLOT_IDS:
		SaveSlots.delete(DIR, slot_id)
	if FileAccess.file_exists(LEGACY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY))


func _write_raw(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func test_write_then_read_payload_and_meta() -> void:
	var meta := {"day": 4, "level": 3, "scene": "res://scenes/world/lastdoor.tscn"}
	var payload := {"save_version": 8, "hello": "world"}
	assert_true(SaveSlots.write(DIR, &"slot_1", meta, payload))
	assert_true(SaveSlots.exists(DIR, &"slot_1"))
	assert_eq(SaveSlots.read_payload(DIR, &"slot_1").get("hello"), "world", "payload recovered")
	assert_eq(int(SaveSlots.read_meta(DIR, &"slot_1").get("day")), 4, "meta recovered")


func test_list_slots_reports_filled_and_empty() -> void:
	SaveSlots.write(DIR, &"slot_2", {}, {"save_version": 8})
	var slots := SaveSlots.list_slots(DIR)
	assert_eq(slots.size(), SaveSlots.SLOT_IDS.size(), "one row per slot id")
	for row: Dictionary in slots:
		if row["id"] == &"slot_2":
			assert_true(row["filled"], "slot_2 is filled")
		else:
			assert_false(row["filled"], "%s is empty" % row["id"])


func test_delete_clears_a_slot() -> void:
	SaveSlots.write(DIR, &"slot_3", {}, {"save_version": 8})
	SaveSlots.delete(DIR, &"slot_3")
	assert_false(SaveSlots.exists(DIR, &"slot_3"))


func test_read_payload_tolerates_a_legacy_bare_file() -> void:
	# A pre-025 save is a bare payload — no meta/save wrapper.
	_write_raw(
		SaveSlots.slot_path(DIR, &"quicksave"), JSON.stringify({"save_version": 7, "legacy": true})
	)
	assert_true(
		SaveSlots.read_payload(DIR, &"quicksave").get("legacy", false), "the bare payload loads"
	)
	assert_eq(SaveSlots.read_meta(DIR, &"quicksave").size(), 0, "a legacy file carries no meta")


func test_adopt_legacy_moves_the_old_save_into_quicksave() -> void:
	_write_raw(LEGACY, JSON.stringify({"save_version": 6}))

	SaveSlots.adopt_legacy(DIR, LEGACY)

	assert_true(SaveSlots.exists(DIR, &"quicksave"), "the legacy save became the quicksave slot")
	assert_false(FileAccess.file_exists(LEGACY), "the legacy file was moved, not copied")

	# Idempotent: a second call with a fresh legacy file does not overwrite.
	_write_raw(LEGACY, "{}")
	SaveSlots.adopt_legacy(DIR, LEGACY)
	assert_eq(
		int(SaveSlots.read_payload(DIR, &"quicksave").get("save_version")), 6, "quicksave unchanged"
	)
