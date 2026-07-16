class_name ContainerPanel
extends CanvasLayer
## Minimal take-only transfer panel for a WorldContainer: item list, Take,
## Take All, Close. Frees itself on close and emits `closed`.

signal closed

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var item_list: ItemList = $Dim/Panel/Layout/Items
@onready var take_button: Button = $Dim/Panel/Layout/Buttons/Take
@onready var take_all_button: Button = $Dim/Panel/Layout/Buttons/TakeAll
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close

var _source: Inventory
var _taker: InventoryComponent


func _ready() -> void:
	take_button.pressed.connect(take_selected)
	take_all_button.pressed.connect(take_all)
	close_button.pressed.connect(close)


## Shows the panel over `source`'s contents; taken stacks go through `taker`
## so the player-side signals (item_added, encumbrance_changed) fire.
func open(source: Inventory, taker: InventoryComponent, title := "Container") -> void:
	_source = source
	_taker = taker
	title_label.text = title
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_list()


## Moves the selected stack (list rows map 1:1 to _source.stacks indices).
func take_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var stack: ItemStack = _source.stacks[selected[0]]
	_take_stack(stack)
	_rebuild_list()


func take_all() -> void:
	for stack: ItemStack in _source.stacks.duplicate():
		_take_stack(stack)
	_rebuild_list()


func close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func _take_stack(stack: ItemStack) -> void:
	var item := stack.item
	var count := stack.count
	_taker.add_item(item, count)
	_source.remove_item(item, count)


func _rebuild_list() -> void:
	item_list.clear()
	for stack: ItemStack in _source.stacks:
		item_list.add_item("%s x%d" % [stack.item.display_name, stack.count])
