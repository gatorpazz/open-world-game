class_name DialogueChoice
extends Resource
## One player-voiced reply on a choice prompt (spec 013) — always a
## sub-resource inside a DialogueResponse's `choices`, never a standalone
## file (the ItemStack pattern). A choice carries no conditions and no
## effects: effects stay on responses, and per-choice conditions are spec
## 019's extension point. Pressing it speaks the line and navigates to
## `topic`, evaluated with from_choice = true so choice_gated commits
## become eligible.

## The player's spoken line, rendered as a button. Plain text — no
## [[markup]]; player lines never unlock topics (validator-enforced).
@export_multiline var text: String
## Topic the NPC answers next. Empty = a dismissal line: the prompt
## lapses with no state change and re-presents on re-ask.
@export var topic: StringName = &""
