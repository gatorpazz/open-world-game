extends GutTest
## Inventory panel (spec 012, criteria 1-7): listing, footer, context
## actions, use/equip/unequip, signal-driven refresh, and the journal-style
## pause lifecycle. Standalone fixtures — no player scene. Mouse mode is
## never asserted (headless).

const PANEL_SCENE := preload("res://scenes/ui/inventory_panel.tscn")
const IRON_SWORD := preload("res://data/items/iron_sword.tres")
const RUSTY_CLAYMORE := preload("res://data/items/rusty_claymore.tres")
const WOODEN_SHIELD := preload("res://data/items/wooden_shield.tres")
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")
const RAT_PELT := preload("res://data/items/rat_pelt.tres")

var _stats: StatsComponent
var _items: InventoryComponent
var _panel: InventoryPanel


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_items = InventoryComponent.new()
	_items.stats = _stats
	add_child_autofree(_items)
	_panel = PANEL_SCENE.instantiate() as InventoryPanel
	add_child_autofree(_panel)
	watch_signals(_panel)
	_panel.open(_items, _stats)


func after_each() -> void:
	get_tree().paused = false


func _select_row_of(text_fragment: String) -> int:
	for i: int in _panel.row_count():
		if _panel.row_text(i).contains(text_fragment):
			_panel.select_row(i)
			return i
	fail_test("no row contains '%s'" % text_fragment)
	return -1


# --- Listing & footer (criteria 1-2) ---


func test_lists_stacks_then_occupied_equipment_slots() -> void:
	_items.add_item(HEALING_DRAUGHT, 2)
	_items.add_item(RAT_PELT)
	_items.add_item(IRON_SWORD)
	_items.equip(IRON_SWORD)
	assert_eq(_panel.row_count(), 3, "two stacks + one occupied slot")
	assert_string_contains(_panel.row_text(0), "Healing Draught x2")
	assert_string_contains(_panel.row_text(1), "Rat Pelt x1")
	assert_string_contains(_panel.row_text(2), "[E] main_hand — Bronze Sword")


func test_stack_rows_show_total_weight() -> void:
	_items.add_item(HEALING_DRAUGHT, 2)
	var expected := "%.1f" % (HEALING_DRAUGHT.weight * 2)
	assert_string_contains(_panel.row_text(0), expected)


func test_footer_shows_gold_weight_capacity_and_armor() -> void:
	_items.add_gold(30)
	_items.add_item(WOODEN_SHIELD)
	_items.equip(WOODEN_SHIELD)
	assert_string_contains(_panel.footer_label.text, "Gold: 30")
	assert_string_contains(_panel.footer_label.text, "/ %.1f" % _stats.sheet.get_carry_capacity())
	assert_string_contains(_panel.footer_label.text, "AR: %d" % WOODEN_SHIELD.armor_rating)
	assert_false(_panel.footer_label.text.contains("[ENCUMBERED]"))


func test_footer_marks_encumbrance() -> void:
	while not _items.is_encumbered():
		_items.add_item(IRON_SWORD, 10)
	assert_string_contains(_panel.footer_label.text, "[ENCUMBERED]")


# --- Context action (criterion 3) ---


func test_selected_action_follows_row_type() -> void:
	_items.add_item(HEALING_DRAUGHT)
	_items.add_item(IRON_SWORD)
	_items.add_item(RAT_PELT)
	_items.add_item(WOODEN_SHIELD)
	_items.equip(WOODEN_SHIELD)
	assert_eq(_panel.selected_action(), &"none", "no selection")
	assert_true(_panel.primary_button.disabled)
	_select_row_of("Healing Draught")
	assert_eq(_panel.selected_action(), &"use")
	_select_row_of("Bronze Sword")
	assert_eq(_panel.selected_action(), &"equip")
	_select_row_of("Rat Pelt")
	assert_eq(_panel.selected_action(), &"none", "plain items have no action")
	_select_row_of("[E] off_hand")
	assert_eq(_panel.selected_action(), &"unequip")
	assert_false(_panel.primary_button.disabled)


# --- Use (criterion 4) ---


func test_use_consumes_one_and_restores_through_stats() -> void:
	_items.add_item(HEALING_DRAUGHT, 2)
	_stats.set_current_health(10.0)
	_select_row_of("Healing Draught")
	assert_true(_panel.primary_action())
	assert_almost_eq(_stats.current_health, 10.0 + HEALING_DRAUGHT.health_restore, 0.001)
	assert_string_contains(_panel.row_text(0), "Healing Draught x1")
	assert_true(_panel.primary_action(), "selection survived the refresh")
	assert_eq(_panel.row_count(), 0, "the emptied stack's row vanished")


# --- Equip / unequip (criterion 5) ---


func test_equip_moves_stack_row_to_equipment_and_back() -> void:
	_items.add_item(IRON_SWORD)
	_select_row_of("Bronze Sword x1")
	assert_true(_panel.primary_action())
	assert_eq(_panel.row_count(), 1)
	assert_string_contains(_panel.row_text(0), "[E] main_hand — Bronze Sword")
	_select_row_of("[E] main_hand")
	assert_true(_panel.primary_action())
	assert_string_contains(_panel.row_text(0), "Bronze Sword x1")


func test_two_handed_equip_clears_off_hand_in_the_same_refresh() -> void:
	_items.add_item(WOODEN_SHIELD)
	_items.equip(WOODEN_SHIELD)
	_items.add_item(RUSTY_CLAYMORE)
	_select_row_of("Verdigris Greatblade")
	assert_true(_panel.primary_action())
	var texts: Array[String] = []
	for i: int in _panel.row_count():
		texts.append(_panel.row_text(i))
	assert_string_contains("\n".join(texts), "[E] main_hand — Verdigris Greatblade")
	assert_string_contains("\n".join(texts), "Chitin Roundshield x1", "shield returned to stacks")
	assert_false("\n".join(texts).contains("[E] off_hand"))


# --- Signal-driven refresh (criterion 6) ---


func test_external_changes_refresh_the_open_panel() -> void:
	_items.add_item(HEALING_DRAUGHT)
	_select_row_of("Healing Draught")
	_items.add_item(RAT_PELT)
	assert_eq(_panel.row_count(), 2, "external add refreshed the list")
	assert_eq(_panel.selected_action(), &"use", "selection preserved by identity")
	_items.remove_item(HEALING_DRAUGHT)
	assert_eq(_panel.row_count(), 1)
	assert_eq(_panel.selected_action(), &"none", "vanished selection cleared")
	assert_true(_panel.primary_button.disabled)


# --- Lifecycle (criterion 7) ---


func test_open_pauses_and_inventory_action_closes() -> void:
	assert_true(get_tree().paused, "open paused the tree")
	var press := InputEventAction.new()
	press.action = &"inventory"
	press.pressed = true
	_panel._unhandled_input(press)
	assert_signal_emit_count(_panel, "closed", 1)
	assert_false(get_tree().paused, "closed unpaused")


# --- Player wiring (criterion 8) ---


func test_inventory_action_exists_and_player_opens_one_panel() -> void:
	_panel.close()
	assert_true(InputMap.has_action(&"inventory"))
	var player: Player = preload("res://scenes/player.tscn").instantiate()
	add_child_autofree(player)
	player.open_inventory()
	assert_not_null(player._inventory_panel)
	var first: InventoryPanel = player._inventory_panel
	player.open_inventory()
	assert_same(player._inventory_panel, first, "a second call adds nothing")
	first.close()
	assert_null(player._inventory_panel, "closed clears the player's reference")


# --- Drop (spec 016, criterion 6) ---


func test_drop_removes_one_and_emits_the_item() -> void:
	_items.add_item(HEALING_DRAUGHT, 2)
	_select_row_of("Healing Draught")
	assert_true(_panel.drop_selected(), "a carried stack drops")
	assert_signal_emitted_with_parameters(_panel, "drop_requested", [HEALING_DRAUGHT])
	assert_eq(_items.inventory.count_of(HEALING_DRAUGHT), 1, "one left; the row refreshed")


func test_drop_disabled_on_equipped_and_no_selection() -> void:
	_items.add_item(IRON_SWORD)
	_items.equip(IRON_SWORD)
	_select_row_of("[E] main_hand")
	assert_false(_panel.can_drop(), "equipped rows are not droppable")
	assert_true(_panel.drop_button.disabled, "drop button disabled on an equipped row")
	assert_false(_panel.drop_selected(), "drop on an equipped row is a no-op")
