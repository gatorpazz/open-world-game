extends GutTest
## Validates every DialogueTopicDef resource in data/dialogue/ (spec 005,
## acceptance criterion 12). This suite is the quality gate the Phase 3
## bulk-generation pipeline runs against: malformed content fails here.

const DIR := "res://data/dialogue"
const NPC_DIR := "res://data/npcs"
const JOURNAL_DIR := "res://data/journal"
const EXPECTED_COUNT := 22

var _topics: Array[DialogueTopicDef] = []
var _topic_ids: Dictionary[StringName, bool] = {}
var _markup_regex := RegEx.create_from_string(DialogueMarkup.MARKUP_PATTERN)


func before_all() -> void:
	for file_name: String in ResourceLoader.list_directory(DIR):
		if not file_name.ends_with(".tres"):
			continue
		var topic: DialogueTopicDef = load(DIR.path_join(file_name)) as DialogueTopicDef
		assert_not_null(topic, "%s should load as a DialogueTopicDef" % file_name)
		if topic != null:
			_topics.append(topic)
			_topic_ids[topic.id] = true


func _assert_resolves(id: StringName, dir: String, type_name: String, context: String) -> void:
	var resource: Resource = load(dir.path_join(String(id) + ".tres"))
	assert_not_null(resource, "%s: id '%s' resolves to a %s" % [context, id, type_name])


func test_expected_count() -> void:
	assert_eq(_topics.size(), EXPECTED_COUNT, "update EXPECTED_COUNT when adding topics")


func test_give_gold_is_never_negative() -> void:
	# give_gold is a reward effect (spec 016) — content must never encode a
	# negative "reward" the pay-out path would silently subtract.
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			assert_gte(response.give_gold, 0, "%s: a give_gold reward is never negative" % topic.id)


func test_ids_are_unique_and_match_filenames() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for topic: DialogueTopicDef in _topics:
		assert_ne(topic.id, &"", "%s has an id" % topic.resource_path)
		assert_false(seen.has(topic.id), "id %s is unique" % topic.id)
		seen[topic.id] = true
		var file_stem := topic.resource_path.get_file().get_basename()
		assert_eq(String(topic.id), file_stem, "id matches filename for %s" % topic.resource_path)


func test_display_names_are_non_empty() -> void:
	for topic: DialogueTopicDef in _topics:
		assert_ne(topic.display_name, "", "%s has a display name" % topic.id)


func test_every_topic_has_at_least_one_response() -> void:
	for topic: DialogueTopicDef in _topics:
		assert_gt(topic.responses.size(), 0, "%s has responses" % topic.id)


func test_lore_sources_present_except_greeting() -> void:
	for topic: DialogueTopicDef in _topics:
		if topic.id == DialogueTopicDef.GREETING_ID:
			continue
		assert_gt(topic.lore_sources.size(), 0, "%s cites at least one lore source" % topic.id)
		for source: StringName in topic.lore_sources:
			assert_ne(source, &"", "%s has no empty lore_sources id" % topic.id)


func test_responses_are_well_formed() -> void:
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			assert_not_null(response, "%s responses are DialogueResponses" % topic.id)
			if response == null:
				continue
			assert_ne(response.text, "", "%s response has text" % topic.id)
			if response.npc_id != &"":
				_assert_resolves(response.npc_id, NPC_DIR, "NPCDef", String(topic.id))
			for required: StringName in response.requires_topics:
				_assert_resolves(required, DIR, "DialogueTopicDef", String(topic.id))
			for entry: StringName in response.requires_journal:
				_assert_resolves(entry, JOURNAL_DIR, "JournalEntryDef", String(topic.id))
			for entry: StringName in response.blocked_by_journal:
				_assert_resolves(entry, JOURNAL_DIR, "JournalEntryDef", String(topic.id))
			if response.journal_entry != &"":
				_assert_resolves(
					response.journal_entry, JOURNAL_DIR, "JournalEntryDef", String(topic.id)
				)
			for stack: ItemStack in response.give_items + response.take_items:
				assert_not_null(stack, "%s item stacks are ItemStacks" % topic.id)
				if stack == null:
					continue
				assert_not_null(stack.item, "%s item stack has an item" % topic.id)
				assert_gt(stack.count, 0, "%s item stack count is positive" % topic.id)
			for choice: DialogueChoice in response.choices:
				assert_not_null(choice, "%s choices are DialogueChoices" % topic.id)
				if choice == null:
					continue
				assert_ne(choice.text, "", "%s choice has a player line" % topic.id)
				assert_false(
					choice.text.contains("[") or choice.text.contains("]"),
					(
						(
							"%s: player lines are plain text — no [[markup]] (one unlock "
							+ "mechanism) and no brackets at all (rendered raw into BBCode)"
						)
						% topic.id
					)
				)
				assert_eq(
					DialogueMarkup.extract_topic_ids(choice.text).size(),
					0,
					"%s: player lines never unlock topics" % topic.id
				)
				if choice.topic != &"":
					_assert_resolves(choice.topic, DIR, "DialogueTopicDef", String(topic.id))


func test_markup_resolves_and_parses_cleanly() -> void:
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			for marked: StringName in DialogueMarkup.extract_topic_ids(response.text):
				assert_true(
					_topic_ids.has(marked),
					"%s: [[%s]] resolves to an existing topic" % [topic.id, marked]
				)
			var stripped := _markup_regex.sub(response.text, "", true)
			assert_false(
				stripped.contains("[[") or stripped.contains("]]"),
				"%s: no stray or malformed [[markup]] in: %s" % [topic.id, response.text]
			)


func test_no_response_follows_an_unconditional_one() -> void:
	for topic: DialogueTopicDef in _topics:
		for index: int in range(topic.responses.size() - 1):
			assert_false(
				topic.responses[index].is_unconditional(),
				(
					"%s: response %d is unconditional, making later ones unreachable"
					% [topic.id, index]
				)
			)


func test_choice_prompts_offer_a_real_decision() -> void:
	# Director ruling (spec 013): a prompt offers >= 2 replies — a choice
	# of one is a continue button, not a decision.
	var prompts := 0
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			if response.choices.is_empty():
				continue
			prompts += 1
			assert_gt(
				response.choices.size(),
				1,
				"%s: a choice prompt offers at least two replies" % topic.id
			)
	if prompts == 0:
		pass_test("no choice prompts in the data — rule holds vacuously")


func test_choice_targets_are_answerable_by_the_prompting_npc() -> void:
	# Static shape check (the greeting-coverage style): journal state can't
	# be evaluated here, but a target topic with no response for the
	# prompting NPC at all is certainly broken.
	var checked := 0
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			if response.choices.is_empty() or response.npc_id == &"":
				continue
			checked += 1
			for choice: DialogueChoice in response.choices:
				if choice == null or choice.topic == &"":
					continue
				var target: DialogueTopicDef = (
					load(DIR.path_join(String(choice.topic) + ".tres")) as DialogueTopicDef
				)
				if target == null:
					continue  # resolution already failed in well-formedness
				var answerable := false
				for candidate: DialogueResponse in target.responses:
					if candidate.npc_id == &"" or candidate.npc_id == response.npc_id:
						answerable = true
						break
				assert_true(
					answerable,
					(
						"%s: choice target %s has a response %s could speak"
						% [topic.id, choice.topic, response.npc_id]
					)
				)
	if checked == 0:
		pass_test("no choice prompts in the data — rule holds vacuously")


func test_choice_gated_responses_are_reachable() -> void:
	# Every topic holding a gated commit must be some choice's target
	# somewhere, or the commit is unreachable content.
	var targeted: Dictionary[StringName, bool] = {}
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			for choice: DialogueChoice in response.choices:
				if choice != null and choice.topic != &"":
					targeted[choice.topic] = true
	var gated := 0
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			if response.choice_gated:
				gated += 1
				assert_true(
					targeted.has(topic.id),
					"%s holds a gated commit but is no choice's target" % topic.id
				)
	if gated == 0:
		pass_test("no gated commits in the data — rule holds vacuously")


func test_greeting_covers_every_npc_from_a_fresh_state() -> void:
	# A fresh state (empty journal, empty inventory) passes responses whose
	# positive gates are all empty (blocked_by_journal passes vacuously —
	# nothing is held from fresh), so existence here is exactly
	# "pick_response is non-null for every NPC on first meeting".
	var greeting: DialogueTopicDef = load(DIR.path_join("greeting.tres")) as DialogueTopicDef
	assert_not_null(greeting, "the reserved greeting topic exists")
	if greeting == null:
		return
	for file_name: String in ResourceLoader.list_directory(NPC_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var npc: NPCDef = load(NPC_DIR.path_join(file_name)) as NPCDef
		var covered := false
		for response: DialogueResponse in greeting.responses:
			var npc_matches := response.npc_id == &"" or response.npc_id == npc.id
			var fresh_passes := (
				response.requires_topics.is_empty()
				and response.requires_journal.is_empty()
				and response.take_items.is_empty()
				and not response.choice_gated
			)
			if npc_matches and fresh_passes:
				covered = true
				break
		assert_true(covered, "%s has a greeting from a fresh state" % npc.id)


func test_every_non_greeting_topic_is_reachable_by_keyword_or_choice() -> void:
	# Amended by spec 013: a choice target is a reachability path too —
	# the refusal retrofit leaves refuse_the_square choice-target-only.
	var reachable: Dictionary[StringName, bool] = {}
	for topic: DialogueTopicDef in _topics:
		for response: DialogueResponse in topic.responses:
			for marked: StringName in DialogueMarkup.extract_topic_ids(response.text):
				reachable[marked] = true
			for choice: DialogueChoice in response.choices:
				if choice != null and choice.topic != &"":
					reachable[choice.topic] = true
	for topic: DialogueTopicDef in _topics:
		if topic.id == DialogueTopicDef.GREETING_ID:
			continue
		assert_true(
			reachable.has(topic.id),
			"%s appears as a [[keyword]] or choice target in at least one response" % topic.id
		)
