class_name DialogueTopicDef
extends Resource
## A shared conversation topic (spec 005). Content lives in
## data/dialogue/*.tres; any NPC with a matching response can discuss it.
## Responses are ordered and the first whose conditions pass wins — author
## specific responses first, unconditional fallbacks last.

## Reserved topic shown automatically when dialogue opens; never listed.
const GREETING_ID := &"greeting"

@export var id: StringName
@export var display_name: String
@export var responses: Array[DialogueResponse] = []
