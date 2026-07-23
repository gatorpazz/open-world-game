class_name DialogueEvaluator
extends RefCounted
## Response selection and effect application for topic dialogue (spec 005).
## Static and pure — no scene-tree or signal dependencies (the CombatMath
## pattern) and fully deterministic, so unit tests need no injection hooks.


## What apply_effects actually changed, for UI notices. Lists only NEW
## learns and adds — repeats of known topics or held entries are omitted.
class EffectReport:
	var new_topics: Array[StringName] = []
	var journal_entry_added: StringName = &""


## True when every condition on the response passes for this NPC and
## player state. take_items is an implicit condition: the player must hold
## every stack (loose or equipped — remove_item drains both), so a shown
## response's effects can never fail. from_choice (spec 013) marks
## navigation that came from a choice press — the only way a choice_gated
## response becomes eligible.
static func matches(
	response: DialogueResponse,
	npc_id: StringName,
	journal: Journal,
	inventory: Inventory,
	from_choice: bool = false,
	bounty: int = 0,
	disposition: int = 0,
) -> bool:
	if response.choice_gated and not from_choice:
		return false
	if response.requires_bounty and bounty <= 0:
		return false
	if response.requires_disposition != 0 and disposition < response.requires_disposition:
		return false
	if response.npc_id != &"" and response.npc_id != npc_id:
		return false
	for topic_id: StringName in response.requires_topics:
		if not journal.knows_topic(topic_id):
			return false
	for entry_id: StringName in response.requires_journal:
		if not journal.has_entry(entry_id):
			return false
	for entry_id: StringName in response.blocked_by_journal:
		if journal.has_entry(entry_id):
			return false
	for stack: ItemStack in response.take_items:
		if inventory.count_of(stack.item) + inventory.count_equipped(stack.item) < stack.count:
			return false
	return true


## The first response in array order whose conditions pass, or null.
static func pick_response(
	topic: DialogueTopicDef,
	npc_id: StringName,
	journal: Journal,
	inventory: Inventory,
	from_choice: bool = false,
	bounty: int = 0,
	disposition: int = 0,
) -> DialogueResponse:
	for response: DialogueResponse in topic.responses:
		if matches(response, npc_id, journal, inventory, from_choice, bounty, disposition):
			return response
	return null


## Topics the player knows AND this NPC can answer, in discovery order.
## The reserved greeting topic is never listed.
static func available_topics(
	topics: Dictionary[StringName, DialogueTopicDef],
	npc_id: StringName,
	journal: Journal,
	inventory: Inventory,
	bounty: int = 0,
	disposition: int = 0,
) -> Array[DialogueTopicDef]:
	var available: Array[DialogueTopicDef] = []
	for topic_id: StringName in journal.known_topics:
		if topic_id == DialogueTopicDef.GREETING_ID or not topics.has(topic_id):
			continue
		var topic: DialogueTopicDef = topics[topic_id]
		if pick_response(topic, npc_id, journal, inventory, false, bounty, disposition) != null:
			available.append(topic)
	return available


## Applies a shown response's journal effects: learns every [[marked]]
## topic and adds the journal entry. Item effects (take_items/give_items)
## are deliberately NOT applied here — the caller routes them through
## InventoryComponent so the player-side signals (item_added, item_removed,
## encumbrance_changed) fire; a raw Inventory mutation would skip them.
## Callers only pass responses returned by pick_response, whose implicit
## take_items condition guarantees the exchange can never fail.
static func apply_effects(
	response: DialogueResponse, journal: Journal, day: int = 0
) -> EffectReport:
	var report := EffectReport.new()
	for topic_id: StringName in DialogueMarkup.extract_topic_ids(response.text):
		if journal.learn_topic(topic_id):
			report.new_topics.append(topic_id)
	if response.journal_entry != &"" and journal.add_entry(response.journal_entry, day):
		report.journal_entry_added = response.journal_entry
	return report
