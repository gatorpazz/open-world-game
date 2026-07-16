class_name DialogueLibrary
extends RefCounted
## Cached id -> DialogueTopicDef lookup over data/dialogue/ (spec 005).
## Loaded lazily on first use; fine at this content scale (an index file
## is the upgrade path if the folder ever grows into the hundreds).

const DIR := "res://data/dialogue"

static var _topics: Dictionary[StringName, DialogueTopicDef] = {}


static func get_topics() -> Dictionary[StringName, DialogueTopicDef]:
	if _topics.is_empty():
		for file_name: String in ResourceLoader.list_directory(DIR):
			if not file_name.ends_with(".tres"):
				continue
			var topic := load(DIR.path_join(file_name)) as DialogueTopicDef
			if topic != null:
				_topics[topic.id] = topic
	return _topics


## Clears the cache so tests can reload from disk.
static func reset() -> void:
	_topics.clear()
