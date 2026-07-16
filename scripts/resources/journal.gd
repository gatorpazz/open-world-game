class_name Journal
extends Resource
## The player's journal (spec 005): chronological journal entry ids plus the
## dialogue topics the player has learned. Pure data + pure logic — no
## signals, no node references (the Inventory pattern). Array order IS the
## chronology; day stamps wait for an in-game clock.

@export var entries: Array[StringName] = []
@export var known_topics: Array[StringName] = []


## Appends the entry id. Returns false without mutating if already present.
func add_entry(id: StringName) -> bool:
	if entries.has(id):
		return false
	entries.append(id)
	return true


func has_entry(id: StringName) -> bool:
	return entries.has(id)


## Learns the topic id. Returns false without mutating if already known.
func learn_topic(id: StringName) -> bool:
	if known_topics.has(id):
		return false
	known_topics.append(id)
	return true


func knows_topic(id: StringName) -> bool:
	return known_topics.has(id)
