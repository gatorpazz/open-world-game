class_name BarterPanel
extends CanvasLayer
## Two-sided barter counter (spec 016): merchant stock on the left (Buy), the
## player's sellable goods on the right (Sell), a gold footer, and Buy / Sell /
## Close. Opened from dialogue (an opens_barter response) and pauses the tree
## like the dialogue it grows out of; the scene root is process_mode = ALWAYS.
##
## Player-side mutation routes through the InventoryComponent so gold/item
## signals fire (the ContainerPanel precedent). The merchant side is a live
## Inventory whose `gold` IS the barter purse — rebuilt each session by the
## Npc, mutated here, never touching the MerchantDef. A failed guard (too
## little gold either side, an off-category item) is a silent no-op; the panel
## never partially commits. Buttons route through the same public API tests call.

signal closed

var _merchant: Inventory
var _taker: InventoryComponent
var _config: BalanceConfig
var _def: MerchantDef
## The player stacks shown on the sell side, in list order — only can_sell
## items appear, so a sell row index is NOT a player-inventory index.
var _sellable: Array[ItemStack] = []

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var buy_list: ItemList = $Dim/Panel/Layout/Body/Buy/List
@onready var sell_list: ItemList = $Dim/Panel/Layout/Body/Sell/List
@onready var footer_label: Label = $Dim/Panel/Layout/Footer
@onready var buy_button: Button = $Dim/Panel/Layout/Buttons/Buy
@onready var sell_button: Button = $Dim/Panel/Layout/Buttons/Sell
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	close_button.pressed.connect(close)


## merchant.gold is the barter purse; merchant.stacks is the for-sale stock.
func open(
	merchant: Inventory, taker: InventoryComponent, config: BalanceConfig, def: MerchantDef
) -> void:
	_merchant = merchant
	_taker = taker
	_config = config
	_def = def
	title_label.text = def.display_name
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


## Buys one unit of the merchant's stack at row `index`. False (no-op) when the
## row is invalid or the player can't afford it.
func buy_row(index: int) -> bool:
	if index < 0 or index >= _merchant.stacks.size():
		return false
	var item := _merchant.stacks[index].item
	var price := BarterRules.buy_price(item, _config, _def.price_multiplier)
	if _taker.inventory.gold < price:
		return false
	_taker.spend_gold(price)
	_merchant.add_gold(price)
	_taker.add_item(item, 1)
	_merchant.remove_item(item, 1)
	_refresh()
	return true


## Sells one unit of the player's sellable stack at row `index`. False (no-op)
## when the row is invalid, off-category, or the merchant can't pay.
func sell_row(index: int) -> bool:
	if index < 0 or index >= _sellable.size():
		return false
	var item := _sellable[index].item
	if not BarterRules.can_sell(item, _def):
		return false
	var price := BarterRules.sell_price(item, _config, _def.price_multiplier)
	if _merchant.gold < price:
		return false
	_merchant.spend_gold(price)
	_taker.add_gold(price)
	_taker.remove_item(item, 1)
	_merchant.add_item(item, 1)
	_refresh()
	return true


func buy_row_count() -> int:
	return _merchant.stacks.size()


func sell_row_count() -> int:
	return _sellable.size()


func player_gold() -> int:
	return _taker.inventory.gold


func merchant_gold() -> int:
	return _merchant.gold


func _refresh() -> void:
	_rebuild_buy()
	_rebuild_sell()
	_update_footer()


func _rebuild_buy() -> void:
	buy_list.clear()
	for stack: ItemStack in _merchant.stacks:
		var price := BarterRules.buy_price(stack.item, _config, _def.price_multiplier)
		buy_list.add_item("%s x%d — %dg" % [stack.item.display_name, stack.count, price])


func _rebuild_sell() -> void:
	sell_list.clear()
	_sellable.clear()
	for stack: ItemStack in _taker.inventory.stacks:
		if not BarterRules.can_sell(stack.item, _def):
			continue
		_sellable.append(stack)
		var price := BarterRules.sell_price(stack.item, _config, _def.price_multiplier)
		sell_list.add_item("%s x%d — %dg" % [stack.item.display_name, stack.count, price])


func _update_footer() -> void:
	footer_label.text = (
		"Your gold: %d      %s's purse: %d"
		% [_taker.inventory.gold, _def.display_name, _merchant.gold]
	)


func _on_buy_pressed() -> void:
	var selected := buy_list.get_selected_items()
	if not selected.is_empty():
		buy_row(selected[0])


func _on_sell_pressed() -> void:
	var selected := sell_list.get_selected_items()
	if not selected.is_empty():
		sell_row(selected[0])
