extends GutTest
## HudNotice queue, fade, and the no-double-notice rule (spec 006,
## acceptance criterion 7).

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const SWIFT := preload("res://data/npcs/swift.tres")

var _player: Player


func before_each() -> void:
	DialogueLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()


func test_show_notice_queues_labels() -> void:
	_player.show_notice("One.")
	_player.show_notice("Two.")
	assert_eq(_player.hud_notice.get_child_count(), 2, "several notices queue together")


func test_notices_fade_and_free() -> void:
	_player.hud_notice.display_seconds = 0.05
	_player.hud_notice.fade_seconds = 0.05
	_player.show_notice("Gone.")
	assert_eq(_player.hud_notice.get_child_count(), 1)
	await wait_seconds(0.5)
	assert_eq(_player.hud_notice.get_child_count(), 0, "notice frees after display + fade")


func test_dialogue_panel_effects_never_hud_notice() -> void:
	var npc: Npc = NPC_SCENE.instantiate()
	npc.def = SWIFT
	add_child_autofree(npc)
	npc.interactable.interact(_player)
	assert_gt(_player.journal.known_topics.size(), 0, "greeting effects ran through the panel")
	npc._panel.show_topic(&"scar_hounds")
	assert_true(_player.journal.has_entry(&"hounds_near_the_covers"), "the panel wrote the journal")
	assert_eq(
		_player.hud_notice.get_child_count(),
		0,
		"panel journal writes notice inline in the transcript — never on the HUD"
	)
