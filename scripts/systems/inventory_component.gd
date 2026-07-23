class_name InventoryComponent
extends Node
## Scene-tree wrapper around an Inventory: forwards mutations down, emits
## signals, computes encumbrance against the StatsComponent's sheet, and
## applies consumables through the stats delta methods.

signal item_added(item: ItemDef, count: int)
signal item_removed(item: ItemDef, count: int)
## item is null when the slot was cleared.
signal equipment_changed(slot: StringName, item: ItemDef)
## Emitted only when the encumbered flag flips.
signal encumbrance_changed(total_weight: float, capacity: float, is_encumbered: bool)
signal gold_changed(amount: int)

@export var stats: StatsComponent
@export var inventory: Inventory

var _was_encumbered := false


func _ready() -> void:
	if inventory == null:
		inventory = Inventory.new()
	_was_encumbered = is_encumbered()


func add_item(item: ItemDef, count: int = 1, stolen: bool = false) -> void:
	inventory.add_item(item, count, stolen)
	item_added.emit(item, count)
	_refresh_encumbrance()


func remove_item(item: ItemDef, count: int = 1) -> bool:
	var old_equipment := inventory.equipment.duplicate()
	if not inventory.remove_item(item, count):
		return false
	item_removed.emit(item, count)
	_emit_equipment_diff(old_equipment)
	_refresh_encumbrance()
	return true


func equip(item: ItemDef, requested_slot: StringName = &"") -> bool:
	var old_equipment := inventory.equipment.duplicate()
	if not inventory.equip(item, requested_slot):
		return false
	_emit_equipment_diff(old_equipment)
	return true


func unequip(slot: StringName) -> bool:
	var old_equipment := inventory.equipment.duplicate()
	if not inventory.unequip(slot):
		return false
	_emit_equipment_diff(old_equipment)
	return true


## Consumes one item from the stacks and applies its restores through the
## stats delta methods. False when none are held.
func use_consumable(item: ConsumableDef) -> bool:
	if not inventory.remove_item(item, 1):
		return false
	stats.apply_health_delta(item.health_restore)
	stats.apply_mana_delta(item.mana_restore)
	stats.apply_stamina_delta(item.stamina_restore)
	item_removed.emit(item, 1)
	_refresh_encumbrance()
	return true


## Triggers an on-use bound working (spec 023) and consumes one — a single-use
## charge. v1 handles `heal`, the ratified give-back: it restores health scaled
## by the working's aspect (mending) skill. Returns false without consuming when
## the item carries no on-use working or an unsupported effect (no charge wasted).
func use_bound_working(item: ItemDef) -> bool:
	if not EnchantRules.triggers(item, &"on_use"):
		return false
	var working := item.bound_working
	if working.effect != &"heal":
		push_warning("use_bound_working: unsupported on-use effect '%s'" % working.effect)
		return false
	if not inventory.remove_item(item, 1):
		return false
	var aspect_skill: int = stats.sheet.skills.get(working.skill_id, 0)
	stats.apply_health_delta(EnchantRules.magnitude(working, aspect_skill, stats.sheet.config))
	item_removed.emit(item, 1)
	_refresh_encumbrance()
	return true


func add_gold(amount: int) -> void:
	inventory.add_gold(amount)
	gold_changed.emit(inventory.gold)


func spend_gold(amount: int) -> bool:
	if not inventory.spend_gold(amount):
		return false
	gold_changed.emit(inventory.gold)
	return true


## Encumbered when total weight strictly exceeds carry capacity; exactly
## at capacity is fine.
func is_encumbered() -> bool:
	return inventory.get_total_weight() > stats.sheet.get_carry_capacity()


## 1.0 normally; the balance-config multiplier while encumbered. The
## movement controller (spec 003) multiplies its speed by this.
func get_speed_multiplier() -> float:
	if is_encumbered():
		return stats.sheet.config.encumbered_speed_multiplier
	return 1.0


func get_equipped_weapon() -> WeaponDef:
	return inventory.get_equipped_weapon()


func get_total_armor_rating() -> int:
	return inventory.get_total_armor_rating()


func get_equipped_shield() -> ArmorDef:
	return inventory.get_equipped_shield()


func get_equipped_armor_skill_ids() -> Array[StringName]:
	return inventory.get_equipped_armor_skill_ids()


## The summed constant bound-working bonus of an effect (and, for fortify, a
## subject) across every equipped item (spec 023) — the worn-charm aggregation.
func bound_bonus(effect: StringName, subject := &"") -> float:
	return EnchantRules.constant_bonus(
		inventory.get_equipped_items(), effect, subject, stats.sheet, stats.sheet.config
	)


## Armor rating including worn `resist` charms (spec 023) — what the defense
## pipeline actually mitigates with.
func get_effective_armor_rating() -> int:
	return get_total_armor_rating() + roundi(bound_bonus(&"resist"))


## A skill's level including worn `fortify` charms (spec 023) — what the combat
## reads scale with.
func effective_skill(skill_id: StringName) -> int:
	var base: int = stats.sheet.skills.get(skill_id, 0)
	return base + roundi(bound_bonus(&"fortify", skill_id))


func _refresh_encumbrance() -> void:
	var encumbered := is_encumbered()
	if encumbered == _was_encumbered:
		return
	_was_encumbered = encumbered
	encumbrance_changed.emit(
		inventory.get_total_weight(), stats.sheet.get_carry_capacity(), encumbered
	)


## Emits equipment_changed for every slot that differs from the snapshot
## (equip can touch several slots at once: 2h clearing off_hand, swaps).
func _emit_equipment_diff(old_equipment: Dictionary[StringName, ItemDef]) -> void:
	for slot: StringName in Inventory.EQUIPMENT_SLOTS:
		var current: ItemDef = inventory.equipment.get(slot)
		if old_equipment.get(slot) != current:
			equipment_changed.emit(slot, current)
