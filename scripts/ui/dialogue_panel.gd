class_name DialoguePanel
extends CanvasLayer
## Topic-based conversation window (spec 005): a running transcript with
## clickable [[keyword]] highlights on the left, the available-topic list
## on the right. ContainerPanel lifecycle — the NPC instantiates it, open()
## injects data, close() frees — but unlike looting, dialogue PAUSES the
## tree (deliberate divergence: reading long text mid-combat is hostile to
## a text-rich pillar). The scene root is process_mode = ALWAYS.

signal closed

const NOTICE_COLOR := "#8a8a8a"

var _npc: NPCDef
var _journal: Journal
var _inventory_component: InventoryComponent
var _display_names: Dictionary[StringName, String] = {}
var _available: Array[DialogueTopicDef] = []

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var transcript: RichTextLabel = $Dim/Panel/Layout/Body/Transcript
@onready var topic_list: ItemList = $Dim/Panel/Layout/Body/Topics
@onready var goodbye_button: Button = $Dim/Panel/Layout/Buttons/Goodbye


func _ready() -> void:
	goodbye_button.pressed.connect(close)
	topic_list.item_clicked.connect(_on_topic_clicked)
	transcript.meta_clicked.connect(_on_keyword_clicked)


## Opens the conversation: greeting first, then the topic list. Operates on
## the player's own Journal and Inventory — injected, never read ambiently.
func open(npc: NPCDef, journal: Journal, inventory_component: InventoryComponent) -> void:
	_npc = npc
	_journal = journal
	_inventory_component = inventory_component
	var topics := DialogueLibrary.get_topics()
	for topic_id: StringName in topics:
		_display_names[topic_id] = topics[topic_id].display_name
	title_label.text = npc.display_name
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_topic(DialogueTopicDef.GREETING_ID)


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Speaks this NPC's response to the topic: renders it into the transcript,
## applies its effects, and rebuilds the topic list so keywords the player
## just read appear immediately. A topic this NPC cannot answer is a no-op.
func show_topic(topic_id: StringName) -> void:
	var topics := DialogueLibrary.get_topics()
	if not topics.has(topic_id):
		push_warning("show_topic: unknown topic '%s'" % topic_id)
		return
	var inventory := _inventory_component.inventory
	var response := DialogueEvaluator.pick_response(topics[topic_id], _npc.id, _journal, inventory)
	if response == null:
		return
	transcript.append_text(DialogueMarkup.to_bbcode(response.text, _display_names) + "\n\n")
	var report := DialogueEvaluator.apply_effects(response, _journal)
	_apply_item_effects(response)
	_append_notices(response, report)
	_rebuild_topic_list()


func _on_topic_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	show_topic(_available[index].id)


func _on_keyword_clicked(meta: Variant) -> void:
	show_topic(StringName(String(meta)))


## Item exchanges go through the component, not the raw Inventory, so the
## player-side signals fire (the ContainerPanel precedent). pick_response's
## implicit take_items condition guarantees the take succeeds.
func _apply_item_effects(response: DialogueResponse) -> void:
	for stack: ItemStack in response.take_items:
		_inventory_component.remove_item(stack.item, stack.count)
	for stack: ItemStack in response.give_items:
		_inventory_component.add_item(stack.item, stack.count)


func _rebuild_topic_list() -> void:
	_available = DialogueEvaluator.available_topics(
		DialogueLibrary.get_topics(), _npc.id, _journal, _inventory_component.inventory
	)
	topic_list.clear()
	for topic: DialogueTopicDef in _available:
		topic_list.add_item(topic.display_name)


func _append_notices(response: DialogueResponse, report: DialogueEvaluator.EffectReport) -> void:
	for topic_id: StringName in report.new_topics:
		_append_notice("New topic: %s." % _display_names.get(topic_id, String(topic_id)))
	if report.journal_entry_added != &"":
		_append_notice("Your journal has been updated.")
	for stack: ItemStack in response.take_items:
		_append_notice("Gave: %s x%d." % [stack.item.display_name, stack.count])
	for stack: ItemStack in response.give_items:
		_append_notice("Received: %s x%d." % [stack.item.display_name, stack.count])


func _append_notice(message: String) -> void:
	transcript.append_text("[color=%s](%s)[/color]\n" % [NOTICE_COLOR, message])
