class_name JournalPanel
extends CanvasLayer
## The journal reader (spec 005): chronological entries, oldest first,
## rendered from JournalEntryDefs resolved by id convention. Pauses the
## tree like the dialogue panel (scene root is process_mode = ALWAYS, so
## it keeps processing and J-to-close works while paused). Plain text —
## keyword markup in journal entries is backlog.

signal closed

const ENTRY_DIR := "res://data/journal"

var _journal: Journal

@onready var entries_label: RichTextLabel = $Dim/Panel/Layout/Entries
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		close()


func open(journal: Journal) -> void:
	_journal = journal
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func _rebuild() -> void:
	entries_label.clear()
	if _journal.entries.is_empty():
		entries_label.append_text("[i]The journal is empty.[/i]")
		return
	for index: int in _journal.entries.size():
		var id := _journal.entries[index]
		var def := load(ENTRY_DIR.path_join(String(id) + ".tres")) as JournalEntryDef
		if def == null:
			# Unreachable with validated data; guard kept for runtime safety.
			push_warning("journal entry '%s' has no JournalEntryDef" % id)
			continue
		entries_label.append_text("[b]Entry %d[/b] — %s\n\n" % [index + 1, def.text])
