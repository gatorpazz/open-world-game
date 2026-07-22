class_name Npc
extends StaticBody3D
## A stationary, def-driven dialogue NPC (spec 005) — one scene, many
## NPCDefs, like creature.tscn. Replaces spec 003's TalkStub: the
## Interactable wiring ("talk" verb) is unchanged, the guts now open the
## dialogue panel. The consumer-less talk_requested signal is gone (003
## amendment) — like WorldContainer, the NPC owns and opens its own panel.

const PANEL_SCENE := preload("res://scenes/ui/dialogue_panel.tscn")
const BARTER_SCENE := preload("res://scenes/ui/barter_panel.tscn")

@export var def: NPCDef
## Optional (spec 016): if set, a "trade" dialogue response (opens_barter)
## opens this counter. The live stock/purse is rebuilt from the def each scene
## entry — runtime-only, never serialized (the world-state-from-journal fence).
@export var merchant_def: MerchantDef

var _panel: DialoguePanel = null
var _barter_panel: BarterPanel = null
## The live merchant Inventory: stacks = stock, gold = the barter purse.
var _merchant_inventory: Inventory = null
## The player from the current interaction — the barter panel needs its
## InventoryComponent, and barter_requested fires after open().
var _last_player: Player = null
## True only across the dialogue -> barter hand-off, so the dialogue close it
## triggers does not clear _last_player before the counter opens.
var _opening_barter := false

@onready var interactable: Interactable = $Interactable


## Before the child Interactable's _ready assert: prompt name per instance.
func _enter_tree() -> void:
	if def != null:
		($Interactable as Interactable).display_name = def.display_name


func _ready() -> void:
	assert(def != null, "Npc needs an NPCDef")
	interactable.interacted.connect(_on_interacted)
	if merchant_def != null:
		_merchant_inventory = _build_merchant_inventory()


func _on_interacted(by: Node) -> void:
	var player := by as Player
	if player == null:
		return
	if _panel != null or _barter_panel != null:
		return
	_last_player = player
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	_panel.closed.connect(_on_panel_closed)
	_panel.barter_requested.connect(_on_barter_requested)
	_panel.open(def, player.journal, player.inventory_component)


func _on_panel_closed() -> void:
	_panel = null
	if not _opening_barter:
		_last_player = null


## Closes the dialogue panel and opens the counter over the live merchant
## Inventory. A no-op if this NPC has no merchant_def or no interacting player.
func _on_barter_requested() -> void:
	if merchant_def == null or _merchant_inventory == null or _last_player == null:
		return
	if _panel != null:
		_opening_barter = true
		_panel.close()
		_opening_barter = false
	_barter_panel = BARTER_SCENE.instantiate()
	add_child(_barter_panel)
	_barter_panel.closed.connect(_on_barter_panel_closed)
	var config := load(StatsComponent.BALANCE_PATH) as BalanceConfig
	_barter_panel.open(_merchant_inventory, _last_player.inventory_component, config, merchant_def)


func _on_barter_panel_closed() -> void:
	_barter_panel = null
	_last_player = null


## The runtime stock + purse, rebuilt from the def (spec 016). gold IS the
## barter purse; stacks are the for-sale goods.
func _build_merchant_inventory() -> Inventory:
	var inventory := Inventory.new()
	inventory.gold = merchant_def.merchant_gold
	for stack: ItemStack in merchant_def.stock:
		inventory.add_item(stack.item, stack.count)
	return inventory
