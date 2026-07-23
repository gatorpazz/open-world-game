extends GutTest
## Barter panel (spec 016, criterion 3): buy/sell guards, category filtering
## on the sell side, gold movement through the component, and no partial
## commits. Standalone fixtures — no player scene. Mouse mode is never
## asserted (headless).

const PANEL_SCENE := preload("res://scenes/ui/barter_panel.tscn")
const BALANCE := preload("res://data/balance/balance_config.tres")
const TANSY := preload("res://data/merchants/tansy.tres")  # buys weapon, armor, misc
const SUDDEL := preload("res://data/merchants/suddel.tres")  # buys consumable, misc
const IRON_SWORD := preload("res://data/items/iron_sword.tres")  # weapon, value 50
const IRON_HELM := preload("res://data/items/iron_helm.tres")  # armor, value 30
const HEALING_DRAUGHT := preload("res://data/items/healing_draught.tres")  # consumable, value 20

var _stats: StatsComponent
var _items: InventoryComponent
var _merchant: Inventory
var _panel: BarterPanel


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_items = InventoryComponent.new()
	_items.stats = _stats
	add_child_autofree(_items)
	_merchant = Inventory.new()


func after_each() -> void:
	get_tree().paused = false


func _open(def: MerchantDef) -> void:
	_panel = PANEL_SCENE.instantiate() as BarterPanel
	add_child_autofree(_panel)
	watch_signals(_items)
	_panel.open(_merchant, _items, BALANCE, def)


# --- Buying ---


func test_buying_moves_item_to_player_and_coin_to_merchant() -> void:
	_merchant.gold = 100
	_merchant.add_item(IRON_SWORD, 1)
	_items.add_gold(100)
	_open(TANSY)
	var price := BarterRules.buy_price(IRON_SWORD, BALANCE)  # 75

	assert_true(_panel.buy_row(0), "buy succeeds when affordable")
	assert_eq(_panel.player_gold(), 100 - price, "player paid the price")
	assert_eq(_panel.merchant_gold(), 100 + price, "merchant took the coin")
	assert_eq(_items.inventory.count_of(IRON_SWORD), 1, "player received the blade")
	assert_eq(_merchant.count_of(IRON_SWORD), 0, "merchant stock depleted")
	assert_signal_emitted(_items, "gold_changed")


func test_a_friendly_merchant_charges_less_to_buy() -> void:
	# Spec 019: the disposition factor the Npc computes flows into the panel's
	# price calls. A factor below 1 (a friendly merchant) discounts buying.
	_merchant.gold = 100
	_merchant.add_item(IRON_SWORD, 1)
	_items.add_gold(100)
	_panel = PANEL_SCENE.instantiate() as BarterPanel
	add_child_autofree(_panel)
	_panel.open(_merchant, _items, BALANCE, TANSY, null, 0.8)  # friendly factor
	var full := BarterRules.buy_price(IRON_SWORD, BALANCE, TANSY.price_multiplier)
	var discounted := BarterRules.buy_price(IRON_SWORD, BALANCE, TANSY.price_multiplier, 0.8)
	assert_lt(discounted, full, "a friendly factor discounts the price")

	assert_true(_panel.buy_row(0), "buy succeeds at the discounted price")
	assert_eq(_panel.player_gold(), 100 - discounted, "player paid the discounted price")


func test_buying_refused_when_player_cannot_afford() -> void:
	_merchant.gold = 100
	_merchant.add_item(IRON_SWORD, 1)
	_items.add_gold(10)
	_open(TANSY)

	assert_false(_panel.buy_row(0), "buy refused below price")
	assert_eq(_panel.player_gold(), 10, "gold unchanged")
	assert_eq(_items.inventory.count_of(IRON_SWORD), 0, "no blade received")
	assert_eq(_merchant.count_of(IRON_SWORD), 1, "merchant stock intact")


func test_buying_refused_on_invalid_row() -> void:
	_items.add_gold(100)
	_open(TANSY)
	assert_false(_panel.buy_row(0), "empty stock, no row to buy")


# --- Selling ---


func test_selling_moves_item_to_merchant_and_coin_to_player() -> void:
	_merchant.gold = 100
	_items.add_item(IRON_HELM, 1)
	_open(TANSY)
	var price := BarterRules.sell_price(IRON_HELM, BALANCE)  # 15

	assert_true(_panel.sell_row(0), "sell succeeds")
	assert_eq(_panel.player_gold(), price, "player was paid")
	assert_eq(_panel.merchant_gold(), 100 - price, "merchant paid out")
	assert_eq(_merchant.count_of(IRON_HELM), 1, "merchant received the helm")
	assert_eq(_items.inventory.count_of(IRON_HELM), 0, "player gave the helm")
	assert_signal_emitted(_items, "gold_changed")


func test_sell_list_omits_off_category_items() -> void:
	_merchant.gold = 100
	_items.add_item(IRON_SWORD, 1)  # weapon — Suddel refuses
	_items.add_item(HEALING_DRAUGHT, 2)  # consumable — Suddel takes
	_open(SUDDEL)
	assert_eq(_panel.sell_row_count(), 1, "only the consumable is sellable to the salter")


func test_sell_list_omits_stolen_stacks() -> void:
	# A hot draught the salter would otherwise buy (spec 017 blanket refusal).
	_merchant.gold = 100
	_items.add_item(HEALING_DRAUGHT, 2)  # clean — sellable
	_items.add_item(HEALING_DRAUGHT, 1, true)  # stolen — refused, a distinct stack
	_open(SUDDEL)
	assert_eq(_panel.sell_row_count(), 1, "only the clean draught stack is sellable")


func test_steal_is_a_noop_without_an_actor() -> void:
	# The standalone fixture opens with no player, so the grab path stays inert.
	_merchant.add_item(IRON_SWORD, 1)
	_open(TANSY)
	assert_false(_panel.steal_row(0), "no actor, no grab")
	assert_eq(_merchant.count_of(IRON_SWORD), 1, "the stock is untouched")


func test_selling_refused_when_merchant_cannot_pay() -> void:
	_merchant.gold = 5
	_items.add_item(IRON_HELM, 1)
	_open(TANSY)

	assert_false(_panel.sell_row(0), "sell refused when purse too small")
	assert_eq(_panel.player_gold(), 0, "player unpaid")
	assert_eq(_items.inventory.count_of(IRON_HELM), 1, "player keeps the helm")


func test_buy_and_sell_row_counts_track_the_sides() -> void:
	_merchant.gold = 100
	_merchant.add_item(IRON_SWORD, 1)
	_items.add_item(IRON_HELM, 1)
	_open(TANSY)
	assert_eq(_panel.buy_row_count(), 1, "one merchant stack")
	assert_eq(_panel.sell_row_count(), 1, "one sellable player stack")
