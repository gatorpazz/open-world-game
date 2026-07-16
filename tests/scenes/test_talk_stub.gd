extends GutTest
## Talk stub NPC (spec 003, acceptance criterion 6).

const TALK_STUB_SCENE := preload("res://scenes/world/talk_stub.tscn")


func _spawn_npc(npc_name: String) -> TalkStub:
	var npc: TalkStub = TALK_STUB_SCENE.instantiate()
	npc.npc_name = npc_name
	add_child_autofree(npc)
	return npc


func test_talk_emits_with_npc_name() -> void:
	var npc := _spawn_npc("Hunald")
	watch_signals(npc)
	npc.interactable.interact(self)
	assert_signal_emitted_with_parameters(npc, "talk_requested", ["Hunald"])


func test_prompt_uses_talk_verb_and_npc_name() -> void:
	var npc := _spawn_npc("Hunald")
	assert_eq(npc.interactable.get_prompt(), "Talk Hunald")
