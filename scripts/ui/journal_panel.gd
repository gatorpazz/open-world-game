class_name JournalPanel
extends CanvasLayer
## The journal reader (spec 005) with the Chronicle | Quests toggle
## (spec 006). Chronicle: chronological entries, oldest first, rendered
## from JournalEntryDefs resolved by id convention. Quests: quests grouped
## Active - Completed - Failed (empty groups hidden), each quest's reached
## stages in stage order under its display_name — the same entry texts,
## read as stories. Pauses the tree like the dialogue panel. Plain text —
## keyword markup in journal entries is backlog.

signal closed

enum View { CHRONICLE, QUESTS }

const ENTRY_DIR := "res://data/journal"
const GROUP_ORDER: Array[QuestEvaluator.Status] = [
	QuestEvaluator.Status.ACTIVE,
	QuestEvaluator.Status.COMPLETED,
	QuestEvaluator.Status.FAILED,
]
const GROUP_TITLES: Dictionary[QuestEvaluator.Status, String] = {
	QuestEvaluator.Status.ACTIVE: "Active",
	QuestEvaluator.Status.COMPLETED: "Completed",
	QuestEvaluator.Status.FAILED: "Failed",
}

var _journal: Journal
var _view: View = View.CHRONICLE

@onready var entries_label: RichTextLabel = $Dim/Panel/Layout/Entries
@onready var chronicle_button: Button = $Dim/Panel/Layout/Views/Chronicle
@onready var quests_button: Button = $Dim/Panel/Layout/Views/Quests
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	close_button.pressed.connect(close)
	chronicle_button.pressed.connect(set_view.bind(View.CHRONICLE))
	quests_button.pressed.connect(set_view.bind(View.QUESTS))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		close()


func open(journal: Journal) -> void:
	_journal = journal
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_view(View.CHRONICLE)


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func set_view(view: View) -> void:
	_view = view
	chronicle_button.disabled = view == View.CHRONICLE
	quests_button.disabled = view == View.QUESTS
	_rebuild()


func _rebuild() -> void:
	entries_label.clear()
	if _view == View.QUESTS:
		_rebuild_quests()
	else:
		_rebuild_chronicle()


func _rebuild_chronicle() -> void:
	if _journal.entries.is_empty():
		entries_label.append_text("[i]The journal is empty.[/i]")
		return
	for index: int in _journal.entries.size():
		var id := _journal.entries[index]
		var def := _load_entry(id)
		if def == null:
			continue
		entries_label.append_text("[b]Entry %d[/b] — %s\n\n" % [index + 1, def.text])


func _rebuild_quests() -> void:
	var quests: Array[QuestDef] = []
	for quest: QuestDef in QuestLibrary.get_quests().values():
		quests.append(quest)
	var groups := QuestEvaluator.group_by_status(quests, _journal)
	var rendered_any := false
	for status: QuestEvaluator.Status in GROUP_ORDER:
		var group: Array[QuestDef] = groups[status]
		if group.is_empty():
			continue
		rendered_any = true
		entries_label.append_text("[b]%s[/b]\n\n" % GROUP_TITLES[status])
		for quest: QuestDef in group:
			entries_label.append_text("[u]%s[/u]\n" % quest.display_name)
			for stage: QuestStage in QuestEvaluator.reached_stages(quest, _journal):
				var def := _load_entry(stage.journal_entry)
				if def == null:
					continue
				entries_label.append_text("%s\n\n" % def.text)
	if not rendered_any:
		entries_label.append_text("[i]No quests yet.[/i]")


func _load_entry(id: StringName) -> JournalEntryDef:
	var def := load(ENTRY_DIR.path_join(String(id) + ".tres")) as JournalEntryDef
	if def == null:
		# Unreachable with validated data; guard kept for runtime safety.
		push_warning("journal entry '%s' has no JournalEntryDef" % id)
	return def
