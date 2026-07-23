class_name Journal
extends Resource
## The player's journal (spec 005): chronological journal entry ids plus the
## dialogue topics the player has learned. Pure data + pure logic — no
## signals, no node references (the Inventory pattern). Array order IS the
## chronology; entry_days (spec 020) records the circuit-day each entry was
## written (0 = pre-clock / unstamped).

@export var entries: Array[StringName] = []
## The circuit-day each entry was written, parallel to `entries` (spec 020).
@export var entry_days: Array[int] = []
@export var known_topics: Array[StringName] = []


## Appends the entry id, stamped with the current circuit-day (0 = unstamped).
## Returns false without mutating if already present.
func add_entry(id: StringName, day: int = 0) -> bool:
	if entries.has(id):
		return false
	entries.append(id)
	entry_days.append(day)
	return true


## The circuit-day the entry at `index` was written, or 0 when unstamped
## (a pre-020 save whose entries predate the clock).
func day_of(index: int) -> int:
	if index < 0 or index >= entry_days.size():
		return 0
	return entry_days[index]


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
