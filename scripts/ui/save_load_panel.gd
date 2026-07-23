class_name SaveLoadPanel
extends CanvasLayer
## The save/load slot menu (spec 025), on the JournalPanel pause-lifecycle. Lists
## SaveSlots (quicksave + the numbered manuals) with their metadata; in SAVE mode
## a row writes that slot, in LOAD mode it emits load_requested so the owner (the
## pause menu / title screen) performs the scene-freeing load and closes us.

signal closed
signal load_requested(slot_id: StringName)

enum Mode { SAVE, LOAD }

## Prettified per-slot display names.
const SLOT_NAMES: Dictionary[StringName, String] = {
	&"quicksave": "Quicksave",
	&"slot_1": "Slot 1",
	&"slot_2": "Slot 2",
	&"slot_3": "Slot 3",
	&"slot_4": "Slot 4",
	&"slot_5": "Slot 5",
	&"slot_6": "Slot 6",
}

var _mode: Mode = Mode.LOAD

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var slot_list: ItemList = $Dim/Panel/Layout/Slots
@onready var primary_button: Button = $Dim/Panel/Layout/Buttons/Primary
@onready var delete_button: Button = $Dim/Panel/Layout/Buttons/Delete
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(close)
	slot_list.item_activated.connect(primary_action)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Consume it so a pause menu hosting this sub-panel does not also close.
		get_viewport().set_input_as_handled()
		close()


func open(mode: Mode) -> void:
	_mode = mode
	var label := "Save" if mode == Mode.SAVE else "Load"
	title_label.text = label
	primary_button.text = label
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func refresh() -> void:
	slot_list.clear()
	for row: Dictionary in SaveSlots.list_slots(Game.saves_dir):
		slot_list.add_item(_row_label(row))


## The slot rows, in menu order (= SaveSlots.SLOT_IDS).
func slot_count() -> int:
	return SaveSlots.SLOT_IDS.size()


func slot_id_at(index: int) -> StringName:
	return SaveSlots.SLOT_IDS[index]


func row_label(index: int) -> String:
	return _row_label(SaveSlots.list_slots(Game.saves_dir)[index])


## Acts on the slot at index: SAVE writes it (and refreshes); LOAD emits
## load_requested for a filled slot. False on a no-op (a bad index, or an empty
## slot in LOAD mode). The primary button and row activation route here.
func primary_action(index: int) -> bool:
	if index < 0 or index >= slot_count():
		return false
	var slot_id := slot_id_at(index)
	if _mode == Mode.SAVE:
		var ok := Game.save_game(slot_id)
		refresh()
		return ok
	if not SaveSlots.exists(Game.saves_dir, slot_id):
		return false
	load_requested.emit(slot_id)
	return true


func delete_slot(index: int) -> bool:
	if index < 0 or index >= slot_count():
		return false
	SaveSlots.delete(Game.saves_dir, slot_id_at(index))
	refresh()
	return true


func _selected_index() -> int:
	var selected := slot_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func _on_primary_pressed() -> void:
	primary_action(_selected_index())


func _on_delete_pressed() -> void:
	delete_slot(_selected_index())


func _row_label(row: Dictionary) -> String:
	var slot_name: String = SLOT_NAMES.get(row["id"], String(row["id"]))
	if not row["filled"]:
		return "%s — (empty)" % slot_name
	var meta: Dictionary = row["meta"]
	if meta.is_empty():
		return "%s — saved game" % slot_name  # a legacy quicksave carries no metadata
	return (
		"%s — Day %d · bell %d · %s · Lv %d · %s"
		% [
			slot_name,
			int(meta.get("day", 0)),
			int(meta.get("bell", 0)),
			_place(String(meta.get("scene", ""))),
			int(meta.get("level", 1)),
			_played(float(meta.get("playtime", 0.0))),
		]
	)


## A scene path prettified to a place name: "res://scenes/world/lastdoor.tscn"
## -> "Lastdoor".
static func _place(scene_path: String) -> String:
	if scene_path.is_empty():
		return "Nowhere"
	return scene_path.get_file().get_basename().capitalize()


## Seconds -> "2h 14m" / "14m" / "0m".
static func _played(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	return "%dh %dm" % [hours, minutes] if hours > 0 else "%dm" % minutes
