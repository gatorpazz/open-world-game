# Spec 002 — Items & Inventory

**Status:** ready to implement
**Depends on:** 001 (character stats — carry capacity, resource restoration, skill ids)
**Consumed by:** 003 (world pickups/containers), 004 (combat reads equipped weapon/armor), 006+ (quest items), economy specs (values)

## Scope

**In:** item data model (weapons, armor, consumables, misc), inventory with stacking and weight, equipment slots, encumbrance, consumable use, starter item set, debug scene, tests.
**Out (later specs / backlog):** world pickups and containers (003), item condition/durability and repair, ammo, enchantments, clothing layers, alchemy ingredients as a system, shops/barter, icons and pickup meshes beyond placeholders, quickslots.

## Design

### Item types

All items derive from a base `ItemDef` resource: `id: StringName`, `display_name: String`, `description: String`, `weight: float` (≥ 0), `base_value: int` (≥ 0), `stackable: bool`, `max_stack: int` (1 if not stackable).

| type | extends ItemDef with | notes |
|---|---|---|
| `WeaponDef` | `damage: int`, `skill_id: StringName` (must be a combat skill from 001), `two_handed: bool` | never stackable |
| `ArmorDef` | `slot: StringName`, `armor_rating: int`, `skill_id: StringName` (heavy_armor or light_armor; empty for jewelry — ring/amulet slots) | never stackable |
| `ConsumableDef` | `health_restore: float`, `mana_restore: float`, `stamina_restore: float` | stackable |
| `MiscDef` | *(nothing)* | loot, quest items, valuables |

### Equipment slots (10)

`head, chest, legs, hands, feet, main_hand, off_hand, ring_1, ring_2, amulet`

Rules: armor equips only to its declared slot; weapons equip to `main_hand`; a `two_handed` weapon occupies `main_hand` and blocks `off_hand`; shields are `ArmorDef` with slot `off_hand`; rings accept either ring slot (fill the empty one, else swap `ring_1`); rings/amulets are `ArmorDef` with `armor_rating` 0 unless special, and an empty `skill_id` (no governing armor skill). Morrowind-style: **no stat or skill requirements to equip anything** — skill affects effectiveness (later specs), not permission.

### Inventory

- A list of stacks: `{item: ItemDef, count: int}`. Stackables merge up to `max_stack`, overflow starts a new stack. Non-stackables are always individual entries.
- `gold: int` lives directly on the inventory (weightless, not an item). Barter spec may revisit.
- `total_weight = Σ item.weight × count` **including equipped gear** (worn items still weigh you down, Morrowind-style — encumbrance can't be dodged by equipping heavy pieces). Adding items is **never blocked by weight** (Morrowind-style).
- **Encumbrance:** when `total_weight > carry_capacity` (from the character sheet), the character is encumbered — movement slows to a crawl: the movement controller multiplies speed by `encumbered_speed_multiplier` from `BalanceConfig` (default 0.25). This spec computes state and emits the signal; the controller integration is a one-line multiplier, done here if trivial, else noted for 003.
- Removing an equipped item auto-unequips it first, then removes it.
- Using a consumable calls the stats system's restore methods, decrements the stack, and deletes empty stacks.

### Required additions to StatsComponent (001)

If not already present, add: `apply_health_delta(amount: float)`, `apply_mana_delta(amount: float)`, `apply_stamina_delta(amount: float)` — clamped to [0, max], emitting the existing changed signals. Consumables and (later) combat both use these.

Also add to `BalanceConfig` (001): `encumbered_speed_multiplier: float = 0.25`.

## Architecture

| file | type | role |
|---|---|---|
| `scripts/resources/item_def.gd` (+ `weapon_def.gd`, `armor_def.gd`, `consumable_def.gd`, `misc_def.gd`) | Resources | item data model |
| `scripts/resources/inventory.gd` | `Inventory extends Resource` | pure data + logic: stacks, gold, equipment map, add/remove/equip/unequip/use, total_weight, total_armor_rating; **no signals, no node refs** |
| `scripts/systems/inventory_component.gd` | `InventoryComponent extends Node` | owns an `Inventory`, holds a reference to `StatsComponent`, emits signals, answers `is_encumbered()`, exposes `get_equipped_weapon()` / `get_total_armor_rating()` for 004 |
| `data/items/*.tres` | resources | starter set below |
| `scenes/debug/inventory_debug.tscn` | scene | buttons: add each starter item, remove, equip/unequip, use consumable; labels: stacks, gold, weight/capacity, encumbered flag, equipment map, armor rating |

Signals on `InventoryComponent`: `item_added(item, count)`, `item_removed(item, count)`, `equipment_changed(slot, item_or_null)`, `encumbrance_changed(total_weight, capacity, is_encumbered)`, `gold_changed(amount)`.

### Starter item set (`data/items/`)

iron_sword (blades, 1h, dmg 8) · rusty_claymore (blades, **2h**, dmg 12) · hunting_bow (ranged, **2h**, dmg 6) · leather_cuirass (chest, light_armor, AR 6) · iron_helm (head, heavy_armor, AR 4) · wooden_shield (off_hand, heavy_armor, AR 5) · plain_ring ×2-able (ring, AR 0) · bone_amulet (amulet, AR 0) · healing_draught (stackable ×10, +25 health) · mana_draught (stackable ×10, +25 mana) · flawed_gem (misc, weight 0.1, value 40) · sack_of_ore (misc, weight 30 — encumbrance testing)

## Acceptance criteria (GUT tests)

1. **Stacking:** adding 15 healing draughts (max_stack 10) yields stacks of 10 + 5; non-stackables never merge.
2. **Weight & encumbrance:** total_weight matches Σ weight×count; the encumbered flag flips exactly when weight exceeds capacity from the live character sheet, and flips back on removal; signal fires with correct payload both ways; the speed penalty is sourced from `encumbered_speed_multiplier` in `balance_config.tres`, not hardcoded.
3. **Equip rules:** armor rejected from wrong slots; two-handed weapon clears and blocks `off_hand`, and equipping a shield while a 2h weapon is held is refused; second ring fills `ring_2`; equipping into an occupied slot returns the old item to inventory; `total_armor_rating` sums equipped pieces only.
4. **Consumables:** using a healing draught raises current health via StatsComponent (clamped at max), decrements the stack, and removes it at zero.
5. **Removal edges:** removing more than present fails safely without mutation; removing an equipped item unequips it first; gold never goes negative.
6. **Data validation:** every `data/items/*.tres` loads; unique ids; weights/values non-negative; weapon and armor `skill_id`s exist in `data/skills/` (jewelry — ring/amulet slots — may have an empty `skill_id`); armor slots from the valid set; stackables have max_stack > 1, non-stackables exactly 1.
7. **Serialization readiness:** `Inventory.duplicate(true)` round-trips stacks, gold, and equipment intact (guards spec 007).

## How to implement

One commit each: ItemDef family + starter items + validation test → StatsComponent delta methods (if missing) + tests → Inventory resource + tests → InventoryComponent + tests → debug scene. Full GUT suite green before every commit.
