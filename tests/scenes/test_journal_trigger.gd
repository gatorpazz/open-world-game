extends GutTest
## JournalTrigger gating and idempotence (spec 006, acceptance criterion 4,
## minus notices — those land with HudNotice).

const TRIGGER_SCENE := preload("res://scenes/world/journal_trigger.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func _spawn_trigger(entry: StringName) -> JournalTrigger:
	var trigger: JournalTrigger = TRIGGER_SCENE.instantiate()
	trigger.journal_entry = entry
	add_child_autofree(trigger)
	return trigger


func test_qualifying_player_adds_the_entry_once() -> void:
	var trigger := _spawn_trigger(&"arrived")
	trigger.try_trigger(_player)
	assert_true(_player.journal.has_entry(&"arrived"))
	trigger.try_trigger(_player)
	assert_eq(_player.journal.entries.count(&"arrived"), 1, "re-entry is a silent no-op")


func test_requires_journal_arms_the_trigger() -> void:
	var trigger := _spawn_trigger(&"arrived")
	trigger.requires_journal = [&"sent_here"] as Array[StringName]
	trigger.try_trigger(_player)
	assert_false(_player.journal.has_entry(&"arrived"), "unarmed until the required entry is held")
	_player.journal.add_entry(&"sent_here")
	trigger.try_trigger(_player)
	assert_true(_player.journal.has_entry(&"arrived"))


func test_blocked_by_journal_disarms_the_trigger() -> void:
	var trigger := _spawn_trigger(&"arrived")
	trigger.blocked_by_journal = [&"too_late"] as Array[StringName]
	_player.journal.add_entry(&"too_late")
	trigger.try_trigger(_player)
	assert_false(_player.journal.has_entry(&"arrived"), "a held blocker disarms the trigger")


func test_non_player_bodies_are_ignored() -> void:
	var trigger := _spawn_trigger(&"arrived")
	var stranger := Node3D.new()
	autofree(stranger)
	trigger.try_trigger(stranger)
	assert_eq(_player.journal.entries.size(), 0)


func test_body_entered_signal_is_wired() -> void:
	var trigger := _spawn_trigger(&"arrived")
	trigger.body_entered.emit(_player)
	assert_true(_player.journal.has_entry(&"arrived"), "_ready connects body_entered")
