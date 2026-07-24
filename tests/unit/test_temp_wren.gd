extends GutTest
## TEMP probe — Wren's three-versions in the live DialoguePanel.

const NPC_SCENE := preload("res://scenes/world/npc.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const WREN := preload("res://data/npcs/wren.tres")

var _player: Player
var _npc: Npc


func before_each() -> void:
	DialogueLibrary.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_npc = NPC_SCENE.instantiate()
	_npc.def = WREN
	add_child_autofree(_npc)


func after_each() -> void:
	get_tree().paused = false
	DialogueLibrary.reset()


func test_probe() -> void:
	_npc.interactable.interact(_player)
	var panel: DialoguePanel = _npc._panel
	gut.p("panel opened: %s" % (panel != null))
	gut.p("greeting: %s" % panel.transcript.get_parsed_text())
	gut.p("topic count: %d" % panel.topic_list.item_count)
	for i in panel.topic_list.item_count:
		gut.p("  topic[%d] = %s" % [i, panel.topic_list.get_item_text(i)])
	gut.p("knows the_three_versions: %s" % _player.journal.knows_topic(&"the_three_versions"))
	gut.p("knows the_folk_mark: %s" % _player.journal.knows_topic(&"the_folk_mark"))
	var before := panel.transcript.get_parsed_text().length()
	panel.show_topic(&"the_three_versions")
	gut.p("after click: %s" % panel.transcript.get_parsed_text().substr(before))
	assert_true(true)
