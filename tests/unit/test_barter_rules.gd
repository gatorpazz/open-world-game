extends GutTest
## Pure BarterRules price math (spec 016, acceptance criterion 2). Loads the
## real balance config and item/merchant content; no scene tree.

const BALANCE_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig
var _items: Dictionary[StringName, ItemDef] = {}
var _merchants: Dictionary[StringName, MerchantDef] = {}


func before_all() -> void:
	_config = load(BALANCE_PATH) as BalanceConfig
	_items = ItemLibrary.get_items()
	_merchants = MerchantLibrary.get_merchants()


func test_item_category_maps_each_subclass() -> void:
	assert_eq(BarterRules.item_category(_items[&"iron_sword"]), &"weapon", "weapon")
	assert_eq(BarterRules.item_category(_items[&"leather_cuirass"]), &"armor", "armor")
	assert_eq(BarterRules.item_category(_items[&"healing_draught"]), &"consumable", "consumable")
	assert_eq(BarterRules.item_category(_items[&"flawed_gem"]), &"misc", "misc")


func test_sell_never_exceeds_buy_for_any_item() -> void:
	# The spread invariant — the merchant margin, for every shipped item.
	for item: ItemDef in _items.values():
		var buy := BarterRules.buy_price(item, _config)
		var sell := BarterRules.sell_price(item, _config)
		assert_lte(sell, buy, "%s sell (%d) <= buy (%d)" % [item.id, sell, buy])


func test_prices_reflect_base_value_and_spread() -> void:
	var sword := _items[&"iron_sword"]  # base_value 50
	assert_eq(BarterRules.buy_price(sword, _config), ceili(50 * 1.5), "buy = base * markup")
	assert_eq(BarterRules.sell_price(sword, _config), floori(50 * 0.5), "sell = base * fraction")


func test_price_multiplier_and_persuasion_scale_both_ends() -> void:
	var sword := _items[&"iron_sword"]
	var base_buy := BarterRules.buy_price(sword, _config)
	assert_eq(
		BarterRules.buy_price(sword, _config, 2.0),
		ceili(50 * 1.5 * 2.0),
		"price_multiplier doubles the buy price"
	)
	assert_gt(
		BarterRules.buy_price(sword, _config, 1.0, 1.5),
		base_buy,
		"a >1 persuasion factor raises the buy price"
	)


func test_prices_clamp_at_floors() -> void:
	var freebie := _items[&"tally_log_copy"]  # base_value 0
	assert_eq(BarterRules.buy_price(freebie, _config), 1, "buy clamps to >= 1 (nothing is free)")
	assert_eq(BarterRules.sell_price(freebie, _config), 0, "sell clamps to >= 0")


func test_can_sell_gates_on_category() -> void:
	var suddel := _merchants[&"suddel"]  # buys consumable, misc
	var tansy := _merchants[&"tansy"]  # buys weapon, armor, misc
	assert_true(BarterRules.can_sell(_items[&"healing_draught"], suddel), "salter takes draughts")
	assert_false(BarterRules.can_sell(_items[&"iron_sword"], suddel), "salter refuses a blade")
	assert_true(BarterRules.can_sell(_items[&"iron_sword"], tansy), "market takes a blade")
	assert_true(BarterRules.can_sell(_items[&"flawed_gem"], tansy), "market takes misc")


func test_empty_buys_accepts_anything() -> void:
	var anything := MerchantDef.new()
	anything.buys = []
	assert_true(BarterRules.can_sell(_items[&"iron_sword"], anything), "empty buys = accepts all")
