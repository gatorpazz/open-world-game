class_name Inventory
extends Resource
## Pure inventory data and rules: stacks, gold, and the equipment map.
## No signals and no node references — InventoryComponent wraps this for
## the scene tree. Items are identified by resource reference: every
## runtime copy of an item is the single cached load() of its .tres.

## The ten physical equipment slots. ArmorDef.VALID_SLOTS is the smaller
## declared-slot vocabulary; its &"ring" wildcard resolves to ring_1/ring_2
## at equip time.
const EQUIPMENT_SLOTS: Array[StringName] = [
	&"head", &"chest", &"legs", &"hands", &"feet",
	&"main_hand", &"off_hand", &"ring_1", &"ring_2", &"amulet",
]

@export var stacks: Array[ItemStack] = []
@export var gold: int = 0
## Only occupied slots are keyed.
@export var equipment: Dictionary[StringName, ItemDef] = {}


## Adds count of item, merging into partial stacks up to max_stack.
## Never blocked by weight.
func add_item(item: ItemDef, count: int = 1) -> void:
	assert(item != null and count > 0)
	var remaining := count
	if item.stackable:
		for stack: ItemStack in stacks:
			if stack.item != item or stack.count >= item.max_stack:
				continue
			var space := item.max_stack - stack.count
			var moved := mini(space, remaining)
			stack.count += moved
			remaining -= moved
			if remaining == 0:
				return
	while remaining > 0:
		var new_stack := ItemStack.new()
		new_stack.item = item
		new_stack.count = mini(remaining, item.max_stack)
		stacks.append(new_stack)
		remaining -= new_stack.count


## Removes count of item, draining loose stacks before unequipping worn
## copies. Fails without any mutation when fewer than count are present.
func remove_item(item: ItemDef, count: int = 1) -> bool:
	assert(item != null and count > 0)
	if count_of(item) + count_equipped(item) < count:
		return false
	var remaining := _drain_stacks(item, count)
	while remaining > 0:
		for slot: StringName in EQUIPMENT_SLOTS:
			if equipment.get(slot) == item:
				unequip(slot)  # returns the copy to stacks
				break
		remaining = _drain_stacks(item, remaining)
	return true


## Count held in loose stacks (excludes equipped copies).
func count_of(item: ItemDef) -> int:
	var total := 0
	for stack: ItemStack in stacks:
		if stack.item == item:
			total += stack.count
	return total


func count_equipped(item: ItemDef) -> int:
	var total := 0
	for slot: StringName in equipment:
		if equipment[slot] == item:
			total += 1
	return total


## Equips one loose copy of item. An empty requested_slot auto-resolves
## (weapons -> main_hand; &"ring" armor -> first empty ring slot, else
## swaps ring_1). Returns false without mutation when the item is not
## equippable, not held loose, the requested slot conflicts, or off_hand
## is blocked by a two-handed weapon.
func equip(item: ItemDef, requested_slot: StringName = &"") -> bool:
	if count_of(item) == 0:
		return false
	var target := _resolve_slot(item, requested_slot)
	if target == &"":
		return false
	if target == &"off_hand" and _holds_two_handed_weapon():
		return false
	var taken := _drain_stacks(item, 1)
	assert(taken == 0)
	if item is WeaponDef and (item as WeaponDef).two_handed:
		unequip(&"off_hand")
	if equipment.has(target):
		unequip(target)  # old item returns to stacks
	equipment[target] = item
	return true


## Moves the item in slot back to the stacks. False when the slot is empty.
func unequip(slot: StringName) -> bool:
	if not equipment.has(slot):
		return false
	add_item(equipment[slot], 1)
	equipment.erase(slot)
	return true


func get_equipped(slot: StringName) -> ItemDef:
	return equipment.get(slot)


func get_equipped_weapon() -> WeaponDef:
	return equipment.get(&"main_hand") as WeaponDef


## Sums armor_rating over equipped ArmorDefs only.
func get_total_armor_rating() -> int:
	var total := 0
	for slot: StringName in equipment:
		var armor := equipment[slot] as ArmorDef
		if armor != null:
			total += armor.armor_rating
	return total


## Total carried weight: loose stacks plus equipped gear (worn items
## still weigh you down).
func get_total_weight() -> float:
	var total := 0.0
	for stack: ItemStack in stacks:
		total += stack.item.weight * stack.count
	for slot: StringName in equipment:
		total += equipment[slot].weight
	return total


func add_gold(amount: int) -> void:
	assert(amount >= 0)
	gold += amount


## False when amount exceeds the current balance; gold never goes negative.
func spend_gold(amount: int) -> bool:
	assert(amount >= 0)
	if amount > gold:
		return false
	gold -= amount
	return true


## Removes up to count of item from loose stacks, emptied stacks are
## erased. Returns how many could NOT be removed. Drains from the array
## end so partial (newest) stacks empty first.
func _drain_stacks(item: ItemDef, count: int) -> int:
	var remaining := count
	for i: int in range(stacks.size() - 1, -1, -1):
		if remaining == 0:
			break
		var stack := stacks[i]
		if stack.item != item:
			continue
		var taken := mini(stack.count, remaining)
		stack.count -= taken
		remaining -= taken
		if stack.count == 0:
			stacks.remove_at(i)
	return remaining


## Maps an item and an optional requested slot to the physical slot it
## should occupy, or &"" when the combination is invalid.
func _resolve_slot(item: ItemDef, requested: StringName) -> StringName:
	if item is WeaponDef:
		if requested == &"" or requested == &"main_hand":
			return &"main_hand"
		return &""
	var armor := item as ArmorDef
	if armor == null:
		return &""  # consumables and misc never equip
	if armor.slot == &"ring":
		if requested == &"ring_1" or requested == &"ring_2":
			return requested
		if requested != &"":
			return &""
		if not equipment.has(&"ring_1"):
			return &"ring_1"
		if not equipment.has(&"ring_2"):
			return &"ring_2"
		return &"ring_1"  # both full: swap ring_1
	if requested == &"" or requested == armor.slot:
		return armor.slot
	return &""


func _holds_two_handed_weapon() -> bool:
	var weapon := get_equipped_weapon()
	return weapon != null and weapon.two_handed
