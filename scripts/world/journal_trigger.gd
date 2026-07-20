class_name JournalTrigger
extends Area3D
## Location-arrival quest trigger (spec 006): a gated area that writes one
## journal entry when a qualifying player enters. Every quest trigger is a
## journal-entry grant, so idempotence rides Journal.add_entry — re-entry
## is a natural no-op. Which entry and which gates are scene-exported
## placement data (the WorldItem idiom: content refs in the scene,
## behavior in the script).

@export var journal_entry: StringName = &""
## All must be held for the trigger to arm.
@export var requires_journal: Array[StringName] = []
## None may be held.
@export var blocked_by_journal: Array[StringName] = []


func _ready() -> void:
	assert(journal_entry != &"", "JournalTrigger needs a journal_entry")
	body_entered.connect(try_trigger)


## The body_entered target, public so scene tests can drive it directly.
func try_trigger(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	if not _conditions_pass(player.journal):
		return
	if player.journal.add_entry(journal_entry):
		player.show_notice(HudNotice.JOURNAL_UPDATED)


func _conditions_pass(journal: Journal) -> bool:
	for entry: StringName in requires_journal:
		if not journal.has_entry(entry):
			return false
	for entry: StringName in blocked_by_journal:
		if journal.has_entry(entry):
			return false
	return true
