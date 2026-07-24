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
	&"head",
	&"chest",
	&"legs",
	&"hands",
	&"feet",
	&"main_hand",
	&"off_hand",
	&"ring_1",
	&"ring_2",
	&"amulet",
]

@export var stacks: Array[ItemStack] = []
@export var gold: int = 0
## Only occupied slots are keyed.
@export var equipment: Dictionary[StringName, ItemDef] = {}
## Per-slot stolen provenance (spec 017 fix): whether the item worn in a slot was
## stolen. Equipment stores the shared ItemDef, which cannot carry the per-stack
## stolen flag, so without this a stolen item would launder clean on
## equip -> unequip. Restored onto the stack on unequip; only stolen slots keyed.
@export var equipment_stolen: Dictionary[StringName, bool] = {}
## The faction that owns this inventory's contents (spec 017); empty = yours.
## Runtime-only on a merchant's live stock (rebuilt each session); the take
## paths read it to decide whether an acquisition is theft.
@export var owner_faction: StringName = &""


## Adds count of item, merging into partial stacks up to max_stack. A stolen
## batch only merges into existing stolen stacks (and clean into clean), so
## provenance never launders through stacking. Never blocked by weight.
func add_item(item: ItemDef, count: int = 1, stolen: bool = false) -> void:
	assert(item != null and count > 0)
	var remaining := count
	if item.stackable:
		for stack: ItemStack in stacks:
			if stack.item != item or stack.stolen != stolen or stack.count >= item.max_stack:
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
		new_stack.stolen = stolen
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
	var stolen := _drain_one_for_equip(item)
	if item is WeaponDef and (item as WeaponDef).two_handed:
		unequip(&"off_hand")
	if equipment.has(target):
		unequip(target)  # old item returns to stacks
	equipment[target] = item
	if stolen:
		equipment_stolen[target] = true
	return true


## Drains one copy of item for equipping, preferring a clean copy so a stolen one
## is only worn (and its slot flagged) when no clean copy exists. Returns whether
## the drained copy was stolen (spec 017: equipping must not launder a stolen
## item — the flag rides the slot and returns to the stack on unequip).
func _drain_one_for_equip(item: ItemDef) -> bool:
	var stolen_index := -1
	for i: int in range(stacks.size() - 1, -1, -1):
		if stacks[i].item != item:
			continue
		if not stacks[i].stolen:
			_take_one(i)
			return false
		if stolen_index == -1:
			stolen_index = i
	_take_one(stolen_index)  # only stolen copies exist (count_of > 0 guaranteed)
	return true


func _take_one(index: int) -> void:
	stacks[index].count -= 1
	if stacks[index].count == 0:
		stacks.remove_at(index)


## Moves the item in slot back to the stacks. False when the slot is empty.
func unequip(slot: StringName) -> bool:
	if not equipment.has(slot):
		return false
	add_item(equipment[slot], 1, equipment_stolen.get(slot, false))
	equipment.erase(slot)
	equipment_stolen.erase(slot)
	return true


func get_equipped(slot: StringName) -> ItemDef:
	return equipment.get(slot)


func get_equipped_weapon() -> WeaponDef:
	return equipment.get(&"main_hand") as WeaponDef


## The shield in off_hand, or null. Only shields occupy off_hand (spec 002
## slot rules), so any ArmorDef there is a shield (spec 004 amendment).
func get_equipped_shield() -> ArmorDef:
	return equipment.get(&"off_hand") as ArmorDef


## Distinct non-empty skill_ids across equipped armor; jewelry's empty
## skill_id drops out. Combat grants armor xp to each on a hit taken
## (spec 004 amendment).
func get_equipped_armor_skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: StringName in equipment:
		var armor := equipment[slot] as ArmorDef
		if armor == null or armor.skill_id == &"":
			continue
		if not ids.has(armor.skill_id):
			ids.append(armor.skill_id)
	return ids


## Sums armor_rating over equipped ArmorDefs only.
func get_total_armor_rating() -> int:
	var total := 0
	for slot: StringName in equipment:
		var armor := equipment[slot] as ArmorDef
		if armor != null:
			total += armor.armor_rating
	return total


## Every equipped item (spec 023 bound-working aggregation), unordered — the
## caller sums over them, so equip order is immaterial.
func get_equipped_items() -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for slot: StringName in equipment:
		items.append(equipment[slot])
	return items


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
		return _resolve_ring_slot(requested)
	if requested == &"" or requested == armor.slot:
		return armor.slot
	return &""


## Resolves the &"ring" wildcard: honor an explicit ring slot, otherwise
## first empty one, swapping ring_1 when both are full.
func _resolve_ring_slot(requested: StringName) -> StringName:
	if requested == &"ring_1" or requested == &"ring_2":
		return requested
	if requested != &"":
		return &""
	if not equipment.has(&"ring_1"):
		return &"ring_1"
	if not equipment.has(&"ring_2"):
		return &"ring_2"
	return &"ring_1"  # both full: swap ring_1


func _holds_two_handed_weapon() -> bool:
	var weapon := get_equipped_weapon()
	return weapon != null and weapon.two_handed
