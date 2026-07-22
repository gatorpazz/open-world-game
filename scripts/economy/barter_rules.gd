class_name BarterRules
extends RefCounted
## Pure barter price math (spec 016): all static, no scene tree, every input
## passed in (the SaveCodec/FactionRules pattern). The player buys at
## base_value * markup and sells at base_value * fraction; fraction < markup
## guarantees sell <= buy — the merchant margin. A regional price_multiplier
## (per MerchantDef) and a persuasion_factor (spec 019 supplies it; pinned 1.0
## here — the inert-friendly lever) scale both ends symmetrically.

const NEUTRAL_PERSUASION := 1.0


## The item's barter category, derived from its ItemDef subclass (not stored) —
## the value MerchantDef.buys is matched against. Order: the concrete gear
## subclasses first, everything else (MiscDef and the bare base) is misc.
static func item_category(item: ItemDef) -> StringName:
	if item is WeaponDef:
		return &"weapon"
	if item is ArmorDef:
		return &"armor"
	if item is ConsumableDef:
		return &"consumable"
	return &"misc"


## What the player pays to buy one unit. Clamped to >= 1 — nothing is free.
static func buy_price(
	item: ItemDef,
	config: BalanceConfig,
	price_mult: float = 1.0,
	persuasion_factor: float = NEUTRAL_PERSUASION
) -> int:
	var raw := item.base_value * config.barter_buy_markup * price_mult * persuasion_factor
	return maxi(1, ceili(raw))


## What the player receives for selling one unit. Clamped to >= 0. By
## construction (fraction < markup) this never exceeds buy_price.
static func sell_price(
	item: ItemDef,
	config: BalanceConfig,
	price_mult: float = 1.0,
	persuasion_factor: float = NEUTRAL_PERSUASION
) -> int:
	var raw := item.base_value * config.barter_sell_fraction * price_mult * persuasion_factor
	return maxi(0, floori(raw))


## Whether this merchant trades in the item's category. Empty buys = anything.
static func can_sell(item: ItemDef, merchant: MerchantDef) -> bool:
	return merchant.buys.is_empty() or merchant.buys.has(item_category(item))
