extends GutTest
## Unit tests for SaveCodec section codecs (spec 007, criteria 1-3 and the
## unknown-id half of criterion 5). Every round-trip passes through an actual
## JSON string — that is what proves the String/float coarseness handling.

const BALANCE_PATH := "res://data/balance/balance_config.tres"
const SKILL_IDS: Array[StringName] = [
	&"blades",
	&"block",
	&"heavy_armor",
	&"evocation",
	&"sneak",
	&"security",
]
const MAJORS: Array[StringName] = [
	&"blades",
	&"block",
	&"heavy_armor",
	&"evocation",
	&"sneak",
]

# --- Criterion 1: sheet round-trip ---


func test_mutated_sheet_round_trips_through_json() -> void:
	var balance := load(BALANCE_PATH) as BalanceConfig
	var sheet := _make_sheet(balance)
	for i: int in balance.level_up_threshold:
		sheet.gain_skill_xp(&"blades", sheet.xp_required(&"blades"))
	assert_gt(sheet.level, 1, "precondition: a level-up was forced")
	assert_true(sheet.spend_attribute_point(&"strength"), "precondition: a point was spent")
	sheet.gain_skill_xp(&"security", 10)
	assert_eq(sheet.skill_xp[&"security"], 10, "precondition: carried xp")

	var restored := SaveCodec.sheet_from_dict(
		_json_round_trip(SaveCodec.sheet_to_dict(sheet)), balance
	)

	assert_not_null(restored)
	assert_same(restored.config, balance, "config is the injected balance, never read from data")
	assert_eq(restored.attributes, sheet.attributes)
	assert_eq(restored.skills, sheet.skills)
	assert_eq(restored.skill_xp, sheet.skill_xp)
	assert_eq(restored.major_skills, sheet.major_skills)
	assert_eq(restored.level, sheet.level)
	assert_eq(restored.unspent_attribute_points, sheet.unspent_attribute_points)
	assert_eq(restored.major_level_ups, sheet.major_level_ups)
	for key: Variant in restored.attributes:
		assert_true(key is StringName, "dictionary keys decode back to StringName")
	assert_eq(typeof(restored.skills[&"blades"]), TYPE_INT, "values decode back to int")
	assert_eq(
		restored.get_max_health(),
		sheet.get_max_health(),
		"derived stats work on the restored sheet"
	)


func test_sheet_from_dict_refuses_malformed_shapes() -> void:
	var balance := load(BALANCE_PATH) as BalanceConfig
	assert_null(SaveCodec.sheet_from_dict({}, balance), "missing fields")
	var bad := SaveCodec.sheet_to_dict(_make_sheet(balance))
	bad["skills"] = "not a dictionary"
	assert_null(SaveCodec.sheet_from_dict(bad, balance), "malformed section")


# --- Criterion 2: inventory round-trip ---


func test_inventory_round_trips_through_json() -> void:
	var items := _make_items()
	var inventory := Inventory.new()
	inventory.gold = 120
	inventory.stacks = [
		_stack(items[&"potion"], 3),
		_stack(items[&"sword"], 1),
		_stack(items[&"potion"], 2),
	]
	inventory.equipment = {
		&"main_hand": items[&"claymore"],
		&"ring_2": items[&"band"],
	}

	var restored := SaveCodec.inventory_from_dict(
		_json_round_trip(SaveCodec.inventory_to_dict(inventory)), items
	)

	assert_not_null(restored)
	assert_eq(restored.gold, 120)
	assert_eq(restored.stacks.size(), 3, "partial stacks survive, in order")
	assert_same(
		restored.stacks[0].item, items[&"potion"], "decoded item is the resolver's instance"
	)
	assert_eq(restored.stacks[0].count, 3)
	assert_same(restored.stacks[1].item, items[&"sword"])
	assert_same(restored.stacks[2].item, items[&"potion"])
	assert_eq(restored.stacks[2].count, 2)
	assert_same(restored.get_equipped_weapon(), items[&"claymore"], "two-handed weapon re-equipped")
	assert_same(restored.get_equipped(&"ring_2"), items[&"band"], "ring_2 stays ring_2")
	assert_false(restored.equipment.has(&"ring_1"), "ring_1 stays empty")


func test_unknown_item_and_slot_skip_without_failing_the_load() -> void:
	var items := _make_items()
	var data := {
		"gold": 5,
		"stacks":
		[
			{"item": "deleted_item", "count": 4},
			{"item": "potion", "count": 2},
		],
		"equipment": {"tail": "band", "main_hand": "deleted_item", "ring_1": "band"},
	}

	var restored := SaveCodec.inventory_from_dict(_json_round_trip(data), items)

	assert_not_null(restored, "unknown ids degrade, they don't brick the load")
	assert_eq(restored.stacks.size(), 1, "the unknown stack is skipped")
	assert_same(restored.stacks[0].item, items[&"potion"])
	assert_eq(restored.equipment.size(), 1, "unknown slot and unknown item are skipped")
	assert_same(restored.get_equipped(&"ring_1"), items[&"band"])


func test_inventory_from_dict_refuses_malformed_shapes() -> void:
	var items := _make_items()
	assert_null(SaveCodec.inventory_from_dict({}, items), "missing fields")
	assert_null(
		SaveCodec.inventory_from_dict({"gold": 0, "stacks": "no", "equipment": {}}, items),
		"stacks must be an array"
	)
	assert_null(
		SaveCodec.inventory_from_dict(
			{"gold": 0, "stacks": [{"item": "potion"}], "equipment": {}}, items
		),
		"a stack entry missing count is structural, not skippable"
	)


# --- Criterion 3: journal round-trip ---


func test_journal_round_trips_in_exact_order() -> void:
	var journal := Journal.new()
	journal.entries = [&"third_seen_first", &"arrival", &"the_favor"]
	journal.known_topics = [&"lastdoor", &"the_rolls"]

	var restored := SaveCodec.journal_from_dict(
		_json_round_trip(SaveCodec.journal_to_dict(journal))
	)

	assert_not_null(restored)
	assert_eq(restored.entries, journal.entries, "entry order IS chronology and survives exactly")
	assert_eq(restored.known_topics, journal.known_topics, "topic order survives exactly")


func test_journal_from_dict_refuses_malformed_shapes() -> void:
	assert_null(SaveCodec.journal_from_dict({}), "missing fields")
	assert_null(
		SaveCodec.journal_from_dict({"entries": [1, 2], "known_topics": []}),
		"non-string entries are structural"
	)


# --- Criterion 4: full payload — transform, pitch, pools ---


func test_full_payload_round_trips_transform_and_pools() -> void:
	var balance := load(BALANCE_PATH) as BalanceConfig
	var items := _make_items()
	var state := _make_state(balance, items)

	var decoded := SaveCodec.decode_save(
		_json_round_trip(SaveCodec.encode_save(state)), balance, items
	)

	assert_not_null(decoded)
	assert_eq(decoded.scene_path, state.scene_path)
	assert_true(
		decoded.player_transform.is_equal_approx(state.player_transform),
		"transform survives within epsilon"
	)
	assert_almost_eq(decoded.head_pitch, state.head_pitch, 0.00001)
	assert_almost_eq(decoded.current_health, 42.5, 0.00001)
	assert_almost_eq(decoded.current_mana, 10.25, 0.00001)
	assert_almost_eq(decoded.current_stamina, 55.0, 0.00001)
	assert_eq(decoded.journal.entries, state.journal.entries)


func test_decoded_basis_is_orthonormal() -> void:
	var skewed: Array[float] = [1.02, 0.01, 0.0, -0.01, 0.99, 0.0, 0.0, 0.0, 1.01, 3.0, 0.5, -2.0]
	var transform := SaveCodec.transform_from_array(skewed)
	assert_almost_eq(transform.basis.x.length(), 1.0, 0.00001, "axes renormalized")
	assert_almost_eq(transform.basis.x.dot(transform.basis.y), 0.0, 0.00001, "axes orthogonal")
	assert_eq(transform.origin, Vector3(3.0, 0.5, -2.0), "origin untouched")


# --- Criteria 5 (unit half) and 10: atomic refusal + security ---


func test_decode_save_refuses_bad_payloads() -> void:
	var balance := load(BALANCE_PATH) as BalanceConfig
	var items := _make_items()
	var good := SaveCodec.encode_save(_make_state(balance, items))

	assert_null(SaveCodec.decode_save({}, balance, items), "missing sections")

	var wrong_version := _json_round_trip(good)
	wrong_version["save_version"] = SaveCodec.SAVE_VERSION + 1
	assert_null(SaveCodec.decode_save(wrong_version, balance, items), "future version refused")

	var bad_sheet := _json_round_trip(good)
	bad_sheet["sheet"] = {"level": 3}
	assert_null(
		SaveCodec.decode_save(bad_sheet, balance, items), "one bad section fails the whole decode"
	)

	var bad_transform := _json_round_trip(good)
	(bad_transform["player"] as Dictionary)["transform"] = [1.0, 2.0]
	assert_null(SaveCodec.decode_save(bad_transform, balance, items), "short transform refused")


func test_scene_path_outside_res_is_refused() -> void:
	var balance := load(BALANCE_PATH) as BalanceConfig
	var items := _make_items()

	var evil := _json_round_trip(SaveCodec.encode_save(_make_state(balance, items)))
	evil["scene_path"] = "user://evil.tscn"
	assert_null(SaveCodec.decode_save(evil, balance, items), "user:// scene refused")

	var missing := _json_round_trip(SaveCodec.encode_save(_make_state(balance, items)))
	missing["scene_path"] = "res://scenes/does_not_exist.tscn"
	assert_null(SaveCodec.decode_save(missing, balance, items), "nonexistent scene refused")


# --- Helpers ---


func _make_state(
	balance: BalanceConfig, items: Dictionary[StringName, ItemDef]
) -> SaveCodec.SaveState:
	var state := SaveCodec.SaveState.new()
	state.scene_path = "res://scenes/main.tscn"
	state.player_transform = Transform3D(Basis(Vector3.UP, 1.3), Vector3(3.0, 0.5, -2.0))
	state.head_pitch = -0.31
	state.current_health = 42.5
	state.current_mana = 10.25
	state.current_stamina = 55.0
	state.sheet = _make_sheet(balance)
	var inventory := Inventory.new()
	inventory.gold = 7
	inventory.stacks = [_stack(items[&"potion"], 2)]
	state.inventory = inventory
	var journal := Journal.new()
	journal.entries = [&"arrival"]
	state.journal = journal
	return state


func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data)) as Dictionary


func _make_sheet(balance: BalanceConfig) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.setup(SKILL_IDS, MAJORS, balance)
	return sheet


func _make_items() -> Dictionary[StringName, ItemDef]:
	var potion := ItemDef.new()
	potion.id = &"potion"
	potion.stackable = true
	potion.max_stack = 5
	var sword := WeaponDef.new()
	sword.id = &"sword"
	var claymore := WeaponDef.new()
	claymore.id = &"claymore"
	claymore.two_handed = true
	var band := ArmorDef.new()
	band.id = &"band"
	band.slot = &"ring"
	return {
		potion.id: potion,
		sword.id: sword,
		claymore.id: claymore,
		band.id: band,
	}


func _stack(item: ItemDef, count: int) -> ItemStack:
	var stack := ItemStack.new()
	stack.item = item
	stack.count = count
	return stack
