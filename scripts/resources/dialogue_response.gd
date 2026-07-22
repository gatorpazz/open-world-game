class_name DialogueResponse
extends Resource
## One conditional answer inside a DialogueTopicDef (spec 005) — always a
## sub-resource in the topic's .tres, never a standalone file. Conditions
## AND together; a response with every condition empty is an unconditional
## fallback. take_items is both an effect and an implicit condition: the
## response is only offered while the player holds the items, so effects
## can never fail once a response is shown.

## Conditions. Empty npc_id means any NPC. blocked_by_journal is the
## negative gate (spec 006): the response matches only while the journal
## holds NONE of the listed entries — cross-NPC branch exclusion.
## choice_gated (spec 013) hides the response from topic and keyword
## clicks: it is eligible only when navigation came from a choice press.
@export var npc_id: StringName = &""
@export var requires_topics: Array[StringName] = []
@export var requires_journal: Array[StringName] = []
@export var blocked_by_journal: Array[StringName] = []
@export var take_items: Array[ItemStack] = []
@export var choice_gated: bool = false

## Effects. [[topic_id]] markup in text unlocks topics when displayed.
## choices (spec 013) makes this response a prompt: the replies render as
## buttons after it is spoken. A choice_gated commit targeted by a
## same-topic prompt sits immediately BEFORE that prompt in `responses`,
## so from_choice picks the commit and normal clicks fall through.
@export_multiline var text: String
@export var journal_entry: StringName = &""
@export var give_items: Array[ItemStack] = []
## Coin paid to the player (spec 016) — the gold quest reward. 0 = none.
@export var give_gold: int = 0
@export var choices: Array[DialogueChoice] = []
## Barter entry (spec 016): a spoken response with this set opens the NPC's
## merchant counter (the panel is a separate window, so the DialoguePanel
## emits barter_requested and the Npc opens it). Only meaningful on an Npc
## whose scene carries a merchant_def; a no-op otherwise.
@export var opens_barter: bool = false
## Warden confrontation (spec 017): a spoken response with this set settles the
## player's standing bounty — spends the fine and clears the ledger, or reports
## that nothing is owed / can't be covered. The "pay" branch of pay-or-refuse.
@export var pay_fine: bool = false


## True when every condition field is empty — an always-available fallback.
## Responses after one of these in the same topic are unreachable. A
## choice_gated response is conditional by definition (spec 013).
func is_unconditional() -> bool:
	return (
		npc_id == &""
		and requires_topics.is_empty()
		and requires_journal.is_empty()
		and blocked_by_journal.is_empty()
		and take_items.is_empty()
		and not choice_gated
	)
