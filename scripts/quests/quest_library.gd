class_name QuestLibrary
extends RefCounted
## Cached id -> QuestDef lookup over data/quests/ (spec 006). Loaded lazily
## on first use — the DialogueLibrary shape, byte for byte.

const DIR := "res://data/quests"

static var _quests: Dictionary[StringName, QuestDef] = {}


static func get_quests() -> Dictionary[StringName, QuestDef]:
	if _quests.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var quest := load(DIR.path_join(file_name)) as QuestDef
			if quest != null:
				_quests[quest.id] = quest
	return _quests


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_quests.clear()
