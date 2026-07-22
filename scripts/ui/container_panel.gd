class_name ContainerPanel
extends CanvasLayer
## Transfer panel for a WorldContainer or the player stash: the source's items
## up top with Take / Take All, and — in deposit mode (spec 016, the stash) —
## the player's own stacks below with Deposit. Loot containers open take-only
## (allow_deposit defaults false), so the deposit list and button stay hidden
## and their behavior is unchanged. Frees itself on close and emits `closed`.

signal closed

var _source: Inventory
var _taker: InventoryComponent
var _allow_deposit := false

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var item_list: ItemList = $Dim/Panel/Layout/Items
@onready var taker_list: ItemList = $Dim/Panel/Layout/TakerItems
@onready var take_button: Button = $Dim/Panel/Layout/Buttons/Take
@onready var take_all_button: Button = $Dim/Panel/Layout/Buttons/TakeAll
@onready var deposit_button: Button = $Dim/Panel/Layout/Buttons/Deposit
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	take_button.pressed.connect(take_selected)
	take_all_button.pressed.connect(take_all)
	deposit_button.pressed.connect(deposit_selected)
	close_button.pressed.connect(close)


## Shows the panel over `source`'s contents; taken stacks go through `taker`
## so the player-side signals fire. In deposit mode the player's own stacks
## show below and Deposit moves them into `source` (the stash).
func open(
	source: Inventory, taker: InventoryComponent, title := "Container", allow_deposit := false
) -> void:
	_source = source
	_taker = taker
	_allow_deposit = allow_deposit
	title_label.text = title
	taker_list.visible = allow_deposit
	deposit_button.visible = allow_deposit
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## Moves the selected stack (list rows map 1:1 to _source.stacks indices).
func take_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	_take_stack(_source.stacks[selected[0]])
	_refresh()


func take_all() -> void:
	for stack: ItemStack in _source.stacks.duplicate():
		_take_stack(stack)
	_refresh()


## Moves the selected player stack into the source (the stash). No-op unless
## in deposit mode with a selection.
func deposit_selected() -> void:
	if not _allow_deposit:
		return
	var selected := taker_list.get_selected_items()
	if selected.is_empty():
		return
	var stack: ItemStack = _taker.inventory.stacks[selected[0]]
	var item := stack.item
	var count := stack.count
	_taker.remove_item(item, count)
	_source.add_item(item, count)
	_refresh()


func close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func _take_stack(stack: ItemStack) -> void:
	var item := stack.item
	var count := stack.count
	_taker.add_item(item, count)
	_source.remove_item(item, count)


func _refresh() -> void:
	item_list.clear()
	for stack: ItemStack in _source.stacks:
		item_list.add_item("%s x%d" % [stack.item.display_name, stack.count])
	if not _allow_deposit:
		return
	taker_list.clear()
	for stack: ItemStack in _taker.inventory.stacks:
		taker_list.add_item("%s x%d" % [stack.item.display_name, stack.count])
