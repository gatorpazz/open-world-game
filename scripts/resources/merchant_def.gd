class_name MerchantDef
extends Resource
## A trader (spec 016): the def-driven shape behind a barter counter. Content
## lives in data/merchants/*.tres; this script only defines the shape. An Npc
## carrying a merchant_def builds a LIVE Inventory from `stock` and an int purse
## from `merchant_gold` at every scene entry — both runtime-only and rebuilt
## each session (Morrowind-faithful regeneration; the world-state-from-journal
## fence holds — no merchant blob in the save). Pure price math that combines a
## def with an item lives in BarterRules (the SaveCodec-style static pattern).
##
## The live stock Inventory is the seam spec 017 consumes: it flags that
## Inventory owned and grabbable so the on-offer goods can be stolen, with no
## change to the barter model.

## The item categories a merchant may trade in — the "Barters:" flags. Derived
## from the ItemDef subclass by BarterRules.item_category; `buys` is validated
## against this set.
const CATEGORIES: Array[StringName] = [&"weapon", &"armor", &"consumable", &"misc"]

@export var id: StringName = &""
@export var display_name: String = ""
## The NPCDef whose dialogue opens this merchant (an opens_barter response).
## Resolves to res://data/npcs/<id>.tres.
@export var npc_id: StringName = &""
## The barter purse — caps what the merchant will pay for the player's wares.
## Rebuilt from this value each session; buying and selling move the runtime
## copy, never this def.
@export var merchant_gold: int = 0
## For-sale goods, built into a live Inventory at runtime. Rebuilt each session.
@export var stock: Array[ItemStack] = []
## Item categories this merchant buys (a subset of CATEGORIES). EMPTY = buys
## anything. Selling an off-category item is refused (BarterRules.can_sell).
@export var buys: Array[StringName] = []
## Regional price lever (Phase 3 world production populates it). Ships 1.0 —
## the inert hook; one settlement exists.
@export var price_multiplier: float = 1.0
