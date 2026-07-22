# Spec 012 — Inventory Panel (mini-spec)

**Status:** ready to implement
**Depends on:** 001 (StatsComponent restores + `get_carry_capacity`), 002 (Inventory / InventoryComponent: stacks, equipment map, `equip`/`unequip`/`use_consumable`, the change signals), 005 (the journal-panel overlay model: CanvasLayer, pause, same-key close, `closed`, queue_free)
**Consumed by:** 010 (the slice needs a way to drink a draught and swap gear outside debug scenes), Phase 2 (barter, container deposit)

## Scope

**In:** an in-world overlay panel opened with a new `inventory` action (**I**): view carried stacks (name, count, weight) and equipped gear (`[E]` rows), use consumables, equip and unequip gear, a footer line (gold, weight/capacity + ENCUMBERED, armor rating), tests.

**Out (later specs / backlog):** dropping items into the world *(re-ruled during the 010 exit playthrough: the encumbered-with-no-drop trap is a known, accepted slice tradeoff — relief waits for Phase 2 barter/deposit)* · depositing into containers (this supersedes `world_container.gd`'s "depositing comes with the real inventory UI" note — the comment is amended to point at Phase 2 barter/deposit) · item icons, tooltips, descriptions · sorting/filtering · drag-and-drop · hotkey/quickslot consumable use · gold interactions from the panel.

## Design

### Open/close — the exact journal model

- New input action `inventory`, default **I**, added in `project.godot` beside `journal`.
- Dispatched in `player.gd _unhandled_input`: `open_inventory()` mirrors `open_journal()` — scene preload, `_inventory_panel` field with null guard, `closed` → clear field, `open(inventory_component, stats)`.
- `InventoryPanel extends CanvasLayer` (`process_mode` ALWAYS on the scene root): `open()` pauses the tree + frees the mouse; the same `inventory` action closes it from its own `_unhandled_input`; `close()` unpauses, recaptures, emits `closed`, `queue_free()`. Byte-for-byte the JournalPanel lifecycle.

### One list, two regions

One `ItemList` (the ContainerPanel precedent), rows built from an internal `_rows` model, because equipped items live in `equipment`, **not** `stacks`:

- Rows `0 .. stacks.size()-1` — carried stacks in `stacks` order: `"%s x%d — %.1f" % [display_name, count, weight * count]`.
- Then one row per **occupied** equipment slot in `Inventory.EQUIPMENT_SLOTS` order: `"[E] %s — %s" % [slot, display_name]`.

Each rebuild fills `_rows` (kind STACK|EQUIPPED, item, slot) so actions never re-derive index math. Two separate lists were considered and rejected: double the selection handling for a mini-spec.

### Context-sensitive primary action

Two buttons: **primary + Close**. The primary's label and enablement follow the selection: `ConsumableDef` → "Use" (`use_consumable`) · `WeaponDef`/`ArmorDef` in the stack region → "Equip" (`equip(item)` — the component resolves the slot, ring wildcard included) · any `[E]` row → "Unequip" (`unequip(slot)`) · plain ItemDef / no selection → disabled. A `false` return from the component is a silent no-op — the component is the authority; no signals fire, nothing rebuilds.

### Footer

One label, the `inventory_debug` dump distilled: gold · `get_total_weight()` vs `stats.sheet.get_carry_capacity()` with an `[ENCUMBERED]` marker when `is_encumbered()` · `get_total_armor_rating()`.

### Refresh — signal-driven, synchronous

`_refresh()` (rows + footer) connects to `item_added`, `item_removed`, `equipment_changed`, `gold_changed`, `encumbrance_changed`. The panel performs **no** rebuild after its own actions — its mutations round-trip through the same signals, so external changes (a trigger grant, a debug add) refresh identically for free. One equip can fire 2–3 signals same-frame (incl. a two-hander clearing `off_hand`) → 2–3 rebuilds; deliberately accepted. Selection is preserved by (kind, item-or-slot) identity across rebuilds; a vanished row clears the selection and disables the primary.

No pause wrinkle: nothing in production listens to `equipment_changed`, PlayerCombat reads equipment lazily per swing, and `use_consumable` restores land through StatsComponent setters → HUD bars — all pause-safe.

### Direct-call API (the test surface — buttons route through it)

`open(items: InventoryComponent, stats: StatsComponent)` · `row_count() -> int` · `row_text(index) -> String` · `select_row(index) -> void` · `selected_action() -> StringName` (`&"use"` / `&"equip"` / `&"unequip"` / `&"none"` — also drives the button label) · `primary_action() -> bool` · `close()`.

## Architecture

| file | role |
|---|---|
| `scenes/ui/inventory_panel.tscn` | CanvasLayer (`process_mode` ALWAYS) + Dim + centered PanelContainer: Title, ItemList, footer Label, Primary/Close buttons — the journal-panel skeleton |
| `scripts/ui/inventory_panel.gd` | `InventoryPanel extends CanvasLayer` — lifecycle, `_rows` model, context action, footer, signal-driven refresh, direct-call API, `signal closed` |
| `tests/scenes/test_inventory_panel.gd` | suite below |

**Modified:** `project.godot` (`inventory` action, I) · `scripts/player.gd` (preload, `_inventory_panel`, `open_inventory()`, dispatch, doc-comment key list) · `scripts/world/world_container.gd` (deposit-comment amendment) · docs (master-plan row + Current Status, CLAUDE.md Current focus).

No BalanceConfig additions — the panel introduces no tunables.

## Acceptance criteria (GUT scene tests)

1. **Listing:** opened over a component holding stacks + equipped gear, `row_count()` = stacks + occupied slots; stack rows render name/count/total weight, equipped rows render `[E] slot — name`; order is stacks-order then `EQUIPMENT_SLOTS` order.
2. **Footer:** shows gold, total weight vs sheet carry capacity, and armor rating; the ENCUMBERED marker appears exactly when `is_encumbered()`.
3. **Context action:** consumable → `&"use"`, weapon/armor stack → `&"equip"`, `[E]` row → `&"unequip"`, plain item or no selection → `&"none"` with the button disabled.
4. **Use:** `primary_action()` on a consumable removes exactly one and applies its restores through stats (clamped at max); a count-1 stack's row disappears on refresh.
5. **Equip/unequip:** equipping a weapon stack row moves it to an `[E]` row; a two-handed weapon also clears `off_hand` in the same refresh; `primary_action()` on the `[E]` row returns it to the stacks.
6. **Signal refresh:** an external `add_item` / `equip` on the component while the panel is open updates rows and footer with no panel call; a surviving selection is preserved by identity, a vanished one clears.
7. **Lifecycle:** `open` pauses the tree; a hand-built `inventory` `InputEventAction` closes it; `closed` fires exactly once; the tree is unpaused after. (Mouse mode is never asserted headless.)
8. **Player wiring:** the `inventory` InputMap action exists; `player.open_inventory()` instantiates one panel and a second call while open adds nothing.

## How to implement

One commit each, full suite green before each: spec doc + `world_container.gd` comment amendment + master-plan queue row → InventoryPanel scene/script + the `inventory` input action + scene tests *(amended: the action lands with the panel, not the player wiring — the panel's own `_unhandled_input` references it, and an unregistered action errors on every input event)* → player wiring + wiring test → docs housekeeping (row → complete, Current Status "Next:" → 010, CLAUDE.md Current focus).

**No debug scene** — `inventory_debug.tscn` already exercises every component path; the panel is reachable in any world scene with I.

**Manual pass:** I opens/pauses/frees the mouse; drinking a draught below max health visibly moves the HUD bar under pause; equipping the iron sword shows `[E] main_hand`; a two-handed equip empties off_hand; I again closes and recaptures; J (journal) still works and the two panels don't fight.
