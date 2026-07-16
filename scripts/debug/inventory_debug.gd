extends Control
## Debug harness for the inventory system: a row per item def with add /
## remove / equip-or-use buttons, unequip buttons per slot, gold and
## self-damage buttons, and a live dump of stacks, equipment, weight,
## and encumbrance. Buttons are generated from data/items/, not hand-placed.

const ITEMS_DIR := "res://data/items"
const GOLD_PER_CLICK := 10
const SELF_DAMAGE := 30.0

@onready var stats: StatsComponent = $Stats
@onready var items: InventoryComponent = $Items
@onready var item_buttons: VBoxContainer = $Layout/ItemScroll/ItemButtons
@onready var slot_buttons: VBoxContainer = $Layout/SlotButtons
@onready var dump: RichTextLabel = $Layout/Dump


## Route through the Game autoload's persistent identity (spec 003): parent
## _enter_tree runs before child _ready, so the components skip their defaults.
func _enter_tree() -> void:
	($Stats as StatsComponent).sheet = Game.character_sheet
	($Items as InventoryComponent).inventory = Game.inventory


func _ready() -> void:
	items.item_added.connect(_on_inventory_changed.unbind(2))
	items.item_removed.connect(_on_inventory_changed.unbind(2))
	items.equipment_changed.connect(_on_inventory_changed.unbind(2))
	items.encumbrance_changed.connect(_on_inventory_changed.unbind(3))
	items.gold_changed.connect(_on_inventory_changed.unbind(1))
	stats.health_changed.connect(_on_inventory_changed.unbind(2))
	stats.mana_changed.connect(_on_inventory_changed.unbind(2))
	stats.stamina_changed.connect(_on_inventory_changed.unbind(2))
	_build_buttons()
	_refresh()


func _build_buttons() -> void:
	for file_name: String in ResourceLoader.list_directory(ITEMS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR.path_join(file_name)) as ItemDef
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = item.display_name
		label.custom_minimum_size.x = 130.0
		row.add_child(label)
		row.add_child(_make_button("Add", _on_add_pressed.bind(item)))
		row.add_child(_make_button("Remove", _on_remove_pressed.bind(item)))
		if item is WeaponDef or item is ArmorDef:
			row.add_child(_make_button("Equip", _on_equip_pressed.bind(item)))
		elif item is ConsumableDef:
			row.add_child(_make_button("Use", _on_use_pressed.bind(item)))
		item_buttons.add_child(row)
	for slot: StringName in Inventory.EQUIPMENT_SLOTS:
		slot_buttons.add_child(_make_button("Unequip %s" % slot, _on_unequip_pressed.bind(slot)))
	slot_buttons.add_child(_make_button("+%d gold" % GOLD_PER_CLICK, _on_add_gold_pressed))
	slot_buttons.add_child(_make_button("Spend %d gold" % GOLD_PER_CLICK, _on_spend_gold_pressed))
	slot_buttons.add_child(_make_button("Damage self %.0f" % SELF_DAMAGE, _on_damage_pressed))


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button


func _on_add_pressed(item: ItemDef) -> void:
	items.add_item(item)


func _on_remove_pressed(item: ItemDef) -> void:
	items.remove_item(item)


func _on_equip_pressed(item: ItemDef) -> void:
	items.equip(item)


func _on_use_pressed(item: ConsumableDef) -> void:
	items.use_consumable(item)


func _on_unequip_pressed(slot: StringName) -> void:
	items.unequip(slot)


func _on_add_gold_pressed() -> void:
	items.add_gold(GOLD_PER_CLICK)


func _on_spend_gold_pressed() -> void:
	items.spend_gold(GOLD_PER_CLICK)


func _on_damage_pressed() -> void:
	stats.apply_health_delta(-SELF_DAMAGE)


func _on_inventory_changed() -> void:
	_refresh()


func _refresh() -> void:
	var inventory := items.inventory
	var lines: PackedStringArray = []
	lines.append("[b]Gold[/b] %d" % inventory.gold)
	var encumbered_tag := "   [b][color=red]ENCUMBERED[/color][/b]" if items.is_encumbered() else ""
	(
		lines
		. append(
			(
				"[b]Weight[/b] %5.1f / %5.1f%s   speed x%.2f"
				% [
					inventory.get_total_weight(),
					stats.sheet.get_carry_capacity(),
					encumbered_tag,
					items.get_speed_multiplier(),
				]
			)
		)
	)
	lines.append("[b]Armor rating[/b] %d" % items.get_total_armor_rating())
	lines.append("")
	lines.append("[b]Pools[/b]")
	lines.append("  health   %5.1f / %5.1f" % [stats.current_health, stats.sheet.get_max_health()])
	lines.append("  mana     %5.1f / %5.1f" % [stats.current_mana, stats.sheet.get_max_mana()])
	lines.append(
		"  stamina  %5.1f / %5.1f" % [stats.current_stamina, stats.sheet.get_max_stamina()]
	)
	lines.append("")
	lines.append("[b]Equipment[/b]")
	for slot: StringName in Inventory.EQUIPMENT_SLOTS:
		var equipped := inventory.get_equipped(slot)
		var name := equipped.display_name if equipped != null else "-"
		lines.append("  %-10s %s" % [slot, name])
	lines.append("")
	lines.append("[b]Stacks[/b]")
	if inventory.stacks.is_empty():
		lines.append("  (empty)")
	for stack: ItemStack in inventory.stacks:
		lines.append("  %-18s x%d" % [stack.item.id, stack.count])
	dump.text = "\n".join(lines)
