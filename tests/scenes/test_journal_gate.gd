extends GutTest
## JournalGate load-time evaluation (spec 006, acceptance criterion 5).
## Gates free themselves — children and all — when conditions fail; a fresh
## instance after a journal change is the scene-reload proxy.


func _gate_with_body(
	requires: Array[StringName], blocked: Array[StringName], journal: Journal
) -> JournalGate:
	var gate := JournalGate.new()
	gate.requires_journal = requires
	gate.blocked_by_journal = blocked
	gate.journal_override = journal
	var body := StaticBody3D.new()
	body.name = "Prop"
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	gate.add_child(body)
	add_child_autofree(gate)
	return gate


func test_requires_unmet_frees_the_subtree() -> void:
	var gate := _gate_with_body([&"done"] as Array[StringName], [], Journal.new())
	var body: Node = gate.get_node("Prop")
	await wait_process_frames(2)
	assert_false(is_instance_valid(gate), "gate freed when requires_journal unmet")
	assert_false(is_instance_valid(body), "the subtree — and its collision — is gone")


func test_requires_met_keeps_the_subtree() -> void:
	var journal := Journal.new()
	journal.add_entry(&"done")
	var gate := _gate_with_body([&"done"] as Array[StringName], [], journal)
	await wait_process_frames(2)
	assert_true(is_instance_valid(gate))
	assert_not_null(gate.get_node_or_null("Prop"))


func test_blocked_held_frees_the_subtree() -> void:
	var journal := Journal.new()
	journal.add_entry(&"cleared")
	var gate := _gate_with_body([], [&"cleared"] as Array[StringName], journal)
	await wait_process_frames(2)
	assert_false(is_instance_valid(gate), "gate freed when a blocker is held")


func test_blocked_unheld_keeps_the_subtree() -> void:
	var gate := _gate_with_body([], [&"cleared"] as Array[StringName], Journal.new())
	await wait_process_frames(2)
	assert_true(is_instance_valid(gate))


func test_reads_game_journal_when_no_override() -> void:
	var saved: Journal = Game.journal
	Game.journal = Journal.new()
	var gate := JournalGate.new()
	gate.requires_journal = [&"done"] as Array[StringName]
	add_child_autofree(gate)
	await wait_process_frames(2)
	assert_false(is_instance_valid(gate), "without an override the gate reads Game.journal")
	Game.journal = saved


func test_fresh_instance_reevaluates_after_journal_change() -> void:
	var journal := Journal.new()
	var before := _gate_with_body([&"done"] as Array[StringName], [], journal)
	await wait_process_frames(2)
	assert_false(is_instance_valid(before), "first visit: condition unmet, subtree gone")
	journal.add_entry(&"done")
	var after := _gate_with_body([&"done"] as Array[StringName], [], journal)
	await wait_process_frames(2)
	assert_true(is_instance_valid(after), "re-entering the scene re-instances and re-evaluates")
