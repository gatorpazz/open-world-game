class_name InventoryPanel
extends CanvasLayer
## The carried-inventory panel (spec 012): one list — carried stacks then
## [E] equipment rows — a context-sensitive primary action (Use / Equip /
## Unequip), and a footer (gold, weight/capacity, armor rating). Pauses the
## tree like the journal panel. Refresh is purely signal-driven: the panel's
## own mutations round-trip through the component's signals, so external
## changes update it identically. Buttons route through the same public API
## tests call.

signal closed

enum RowKind { STACK, EQUIPPED }

const ACTION_LABELS: Dictionary[StringName, String] = {
	&"use": "Use",
	&"equip": "Equip",
	&"unequip": "Unequip",
	&"none": "Use",
}

var _items: InventoryComponent
var _stats: StatsComponent
## Mirrors the list rows: {kind: RowKind, item: ItemDef, slot: StringName}.
## Equipped items live in the equipment map, not stacks — actions read this
## model, never re-derived index math.
var _rows: Array[Dictionary] = []

@onready var item_list: ItemList = $Dim/Panel/Layout/Items
@onready var footer_label: Label = $Dim/Panel/Layout/Footer
@onready var primary_button: Button = $Dim/Panel/Layout/Buttons/Primary
@onready var close_button: Button = $Dim/Panel/Layout/Buttons/Close


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_pressed)
	close_button.pressed.connect(close)
	item_list.item_selected.connect(select_row)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		close()


## One-shot: the panel frees itself on close, so open is called exactly
## once per instance — the guard makes a double call harmless.
func open(items: InventoryComponent, stats: StatsComponent) -> void:
	if _items != null:
		push_warning("open: panel already open")
		return
	_items = items
	_stats = stats
	items.item_added.connect(_on_inventory_changed.unbind(2))
	items.item_removed.connect(_on_inventory_changed.unbind(2))
	items.equipment_changed.connect(_on_inventory_changed.unbind(2))
	items.gold_changed.connect(_on_inventory_changed.unbind(1))
	items.encumbrance_changed.connect(_on_inventory_changed.unbind(3))
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func row_count() -> int:
	return _rows.size()


func row_text(index: int) -> String:
	return item_list.get_item_text(index)


func select_row(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	item_list.select(index)
	_update_primary()


## The context action the current selection supports; also the primary
## button's label key.
func selected_action() -> StringName:
	var row := _selected_row()
	if row.is_empty():
		return &"none"
	if row[&"kind"] == RowKind.EQUIPPED:
		return &"unequip"
	var item: ItemDef = row[&"item"]
	if item is ConsumableDef:
		return &"use"
	if item is WeaponDef or item is ArmorDef:
		return &"equip"
	return &"none"


## Performs the selection's context action through the component — the
## component is the authority; a false return is a silent no-op (no signals
## fire, nothing rebuilds).
func primary_action() -> bool:
	var row := _selected_row()
	match selected_action():
		&"use":
			return _items.use_consumable(row[&"item"] as ConsumableDef)
		&"equip":
			return _items.equip(row[&"item"] as ItemDef)
		&"unequip":
			return _items.unequip(row[&"slot"] as StringName)
	return false


## Full re-render, preserving the selection by (kind, item-or-slot)
## identity; a vanished row clears the selection.
func _refresh() -> void:
	var keep := _selected_row()
	_rebuild_rows()
	if not keep.is_empty():
		var index := _find_row(keep)
		if index >= 0:
			item_list.select(index)
	_update_primary()
	_update_footer()


func _rebuild_rows() -> void:
	_rows.clear()
	item_list.clear()
	var inventory := _items.inventory
	for stack: ItemStack in inventory.stacks:
		_rows.append({&"kind": RowKind.STACK, &"item": stack.item, &"slot": &""})
		item_list.add_item(
			(
				"%s x%d — %.1f"
				% [stack.item.display_name, stack.count, stack.item.weight * stack.count]
			)
		)
	for slot: StringName in Inventory.EQUIPMENT_SLOTS:
		var worn := inventory.get_equipped(slot)
		if worn == null:
			continue
		_rows.append({&"kind": RowKind.EQUIPPED, &"item": worn, &"slot": slot})
		item_list.add_item("[E] %s — %s" % [slot, worn.display_name])


func _find_row(target: Dictionary) -> int:
	for i: int in _rows.size():
		var row := _rows[i]
		if row[&"kind"] != target[&"kind"]:
			continue
		if row[&"kind"] == RowKind.EQUIPPED and row[&"slot"] == target[&"slot"]:
			return i
		if row[&"kind"] == RowKind.STACK and row[&"item"] == target[&"item"]:
			return i
	return -1


func _selected_row() -> Dictionary:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return {}
	return _rows[selected[0]]


func _update_primary() -> void:
	var action := selected_action()
	primary_button.text = ACTION_LABELS[action]
	primary_button.disabled = action == &"none"


func _update_footer() -> void:
	var inventory := _items.inventory
	var encumbered := "  [ENCUMBERED]" if _items.is_encumbered() else ""
	footer_label.text = (
		"Gold: %d    Weight: %.1f / %.1f%s    AR: %d"
		% [
			inventory.gold,
			inventory.get_total_weight(),
			_stats.sheet.get_carry_capacity(),
			encumbered,
			_items.get_total_armor_rating(),
		]
	)


func _on_primary_pressed() -> void:
	primary_action()


func _on_inventory_changed() -> void:
	_refresh()
