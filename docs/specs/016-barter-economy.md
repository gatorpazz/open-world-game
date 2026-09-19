# Spec 016 — Barter Economy v1

**Status:** complete (2026-07-22)
**Depends on:** 002 (`Inventory`/`ItemStack`/`ItemDef` — `gold`, `add_gold`/`spend_gold`, `base_value`; the item subclasses the price categories derive from), 003 (`WorldItem` pickup — drop-to-world spawns one; the `Interactable` verb the stash chest reuses), 005 (`DialogueResponse` effects + `DialoguePanel` — the barter entry and `give_gold` amend the effect path), 007 (`SaveCodec` — this spec bumps it to v3 and gives it its second migration; `Game`-held identity the stash joins), 012 (`InventoryPanel` — Drop closes its deferred encumbered-no-drop debt; `ContainerPanel` the stash reuses), 013 (the barter entry reads best as a choice), 015 (the `SaveCodec` migration chain this spec extends; `persuasion` is the price lever 019 later drives)
**Consumed by:** 017 (crime/stealth/locks — the merchant's live `Inventory` is the ownable seam theft flags; "stolen-flag → merchant refusal" consumes this barter path), 018 (no direct dep), 019 (persuasion & disposition — `BarterRules`' `persuasion_factor` param, pinned 1.0 here, is where the price nudge lands), 021 (fast-travel — gold fares spend this currency), 023 (enchanting — rare stock is merchant stock), 024 (creatures — loot is priced against `base_value` at these merchants)

## Scope

**In:** a `MerchantDef` content type + `MerchantLibrary` scanner (the Golden Rule triple) · pure `BarterRules` (price math + category gating + an item-category helper) in `scripts/economy/` · a `BalanceConfig` **Economy** group (buy markup, sell fraction) · a two-sided `BarterPanel` opened *from dialogue* via a new `DialogueResponse.opens_barter` effect signalled up to the `Npc` · a `Game.stash: Inventory` sanctioned player bank, a Lastdoor stash chest, and `ContainerPanel` gaining a deposit direction · **the second `SAVE_VERSION` bump (2 → 3)** + **`_migrate_v2_to_v3`** (seeds an empty stash) with the migration chain (v1→v2→v3) · a `DialogueResponse.give_gold` effect (gold quest rewards unlocked) · **drop-to-world** from the inventory panel (spawns a `WorldItem`) · 2 Lastdoor merchants (Suddel, Tansy) with trade dialogue + one demonstrated gold reward, canon-packet authored · the `price_multiplier` regional hook (ships 1.0) · full GUT coverage.

**Out (later specs / backlog):**
- **All theft / ownership / crime** → **017** (ownership fields, the witness primitive built once, `sneak` + `security` live, lockpicking, bounty, stolen-flag → merchant refusal). **Director ruling (2026-07-22): shop theft is faithful-Morrowind and desired, but it lands in 017.** 016 only guarantees the seam: a merchant's for-sale goods are a *real `Inventory`* (below), so 017 can flag them owned and grabbable without reworking the barter model.
- **Live persuasion / disposition price effect** → **019**. `BarterRules` prices take a `persuasion_factor` param that **ships pinned to 1.0** (the inert-friendly lever, Decision Log); 019 supplies the real value and adds per-NPC disposition. **There is no Mercantile skill** — the social skill is `persuasion`; it doubles as the price lever.
- **Haggling mini-game** — **rejected as a mechanic.** The spread is fixed data narrowed later by disposition, never a click-gamble (Morrowind's most-modded-out system; the plain-meaning, no-dice culture of specs 004/008).
- **Persistent merchant depletion** — merchant gold + stock are **runtime-only**, rebuilt from `MerchantDef` at every scene entry (Morrowind-faithful regeneration; keeps the world-state-from-journal fence — no merchant blob in the save). **Director ruling: reset each session.**
- **Persistent dropped items** — a dropped `WorldItem` is world state and does **not** survive save/load (the 006/007 fence). Stated caveat; the stash is the durable encumbrance relief.
- **Spell/service vendors, training, repair, fast-travel fares** — 021/later; 016 ships item barter + gold only.
- **Regional price variation** — one settlement exists; `price_multiplier` is the inert hook (Phase 3 world production populates it).

## Design

### The problem (ground truth from the shipped data)

`Inventory.gold` exists and `add_gold`/`spend_gold` work, but **nothing moves gold outside `inventory_debug.tscn`**. Quest rewards are `give_items` + journal-gated access (spec 010's "rewards stay give_items + access"). The inventory panel (012) shipped without drop or deposit, naming both "Phase 2 barter." Every item already carries a `base_value` (authored in all 16 `data/items/*.tres`). So 016 is not new item data — it is the machinery that turns `base_value` into a transaction: a price formula, a trade UI, a coin reward effect, and the one sanctioned place to offload weight.

### Faithfulness rulings (director, 2026-07-22 — Morrowind as the target)

Researched against UESP/OpenMW. The faithful behaviors, adopted:
1. **Merchant barter gold is a fixed purse that caps what they pay you and regenerates** → runtime-only, reset each session.
2. **Restocking stock refills** (unique items aside) → runtime-only, reset each session.
3. **Merchants trade only in their categories** (the "Barters:" flags — a clothier won't touch armour) → `MerchantDef.buys`.
4. **Sell price sits below buy price**; social standing narrows the spread → the fixed spread + inert `persuasion_factor`.
5. **Shop goods are owned; taking them is theft only if witnessed; selling to the owner is caught; other merchants buy stolen goods freely** → all 017, but the ownable-`Inventory` seam is laid here.

### Content model — the Golden Rule triple

**`MerchantDef`** (`scripts/resources/merchant_def.gd`; content in `data/merchants/*.tres`):

| field | type | meaning |
|---|---|---|
| `id` | StringName | matches the filename stem |
| `display_name` | String | the counter label on the panel |
| `npc_id` | StringName | the `NPCDef` whose dialogue opens this merchant (validator resolves it to `data/npcs/`) |
| `merchant_gold` | int ≥ 0 | the barter purse — caps what they'll pay; **rebuilt each session** |
| `stock` | Array[ItemStack] | for-sale goods; built into a live `Inventory` at runtime, **rebuilt each session** |
| `buys` | Array[StringName] | accepted item categories; **empty = buys anything** (the Barters flags) |
| `price_multiplier` | float > 0 = 1.0 | the regional hook — ships 1.0 |

Item category is **derived from the `ItemDef` subclass**, not a new data field (the creatures-aren't-characters cheapness): `BarterRules.item_category(item)` → `&"weapon"` (`WeaponDef`) / `&"armor"` (`ArmorDef`) / `&"consumable"` (`ConsumableDef`) / `&"misc"` (`MiscDef`/base). The known-category set is a `const` on `BarterRules`, which the validator checks `buys` against.

*Rejected alternative — an abstract trade-window stock list (pure Morrowind):* the director wants the on-offer goods themselves stealable. A real `Inventory` is the one object both the barter panel trades and 017 flags owned. **Director ruling: physical, ownable stock.**

### Pure logic — `BarterRules` (static, resolver-injected, `scripts/economy/`)

Mirrors `FactionRules` — all static, no scene tree, everything passed in:
- `item_category(item: ItemDef) -> StringName`
- `buy_price(item, config, price_mult := 1.0, persuasion_factor := 1.0) -> int` — `ceili(base_value * config.barter_buy_markup * price_mult * persuasion_factor)`, clamped ≥ 1.
- `sell_price(item, config, price_mult := 1.0, persuasion_factor := 1.0) -> int` — `floori(base_value * config.barter_sell_fraction * price_mult * persuasion_factor)`, clamped ≥ 0.
- `can_sell(item, merchant) -> bool` — `merchant.buys.is_empty() or item_category(item) in merchant.buys`.
- **Invariant (tested): `sell_price ≤ buy_price` for every item**, the merchant margin — guaranteed by `barter_sell_fraction < barter_buy_markup`.

`BalanceConfig` gains `@export_group("Economy")`: `barter_buy_markup: float` and `barter_sell_fraction: float`, authored into `balance_config.tres` (representative: 1.5 / 0.5; exact tuning is content). No per-merchant margins (Golden Rule — margins are global; `price_multiplier` is the only per-def lever).

**`MerchantLibrary`** (`scripts/economy/merchant_library.gd`) — folder scanner over `data/merchants/`, the `ItemLibrary`/`FactionLibrary` shape; `get_merchants() -> Dictionary[StringName, MerchantDef]` + `reset()`.

### Runtime merchant state — non-persistent, the 017 seam

`Npc` gains an optional `@export var merchant_def: MerchantDef`. On `_ready`, if set, it builds a **live `Inventory`** from `stock` and an `int` purse from `merchant_gold`, rebuilt every scene entry — buying/selling depletes them within a session, a reload restores full stock (faithful, zero save footprint). **This live `Inventory` is the seam 017 consumes**: 017 adds an `owner` to it and a grab path so the on-offer goods can be stolen, with no change to the barter model.

### Barter panel — off dialogue, two-sided (`scripts/ui/barter_panel.gd`)

`BarterPanel extends CanvasLayer`, the `ContainerPanel`/`InventoryPanel` skeleton (Dim + centred PanelContainer, pause the tree, free the mouse, same-lifecycle `closed` + `queue_free`). Left `ItemList` = merchant stock with `buy_price`; right = the player's **sellable** stacks (filtered by `can_sell`) with `sell_price`; footer = player gold + merchant gold; buttons **Buy / Sell / Close**. All player-side mutation routes through `player.inventory_component` so `gold_changed`/`item_added`/`item_removed` fire (the `ContainerPanel` precedent). Guards: buy needs `player gold ≥ buy_price` and the merchant to hold the stack; sell needs `can_sell` and `merchant_gold ≥ sell_price`. A failed guard is a silent no-op (the 012 authority-is-the-component precedent). Direct-call API is the test surface, buttons route through it: `open(merchant_inv, merchant_gold, taker, config, def)`, `buy_row(i) -> bool`, `sell_row(i) -> bool`, `player_gold()`, `merchant_gold()`, `buy_row_count()`, `sell_row_count()`, `close()`.

**Entry from dialogue (signals up, calls down):**
- `DialogueResponse.opens_barter: bool = false` — an effect flag.
- `DialoguePanel` gains `signal barter_requested`; the renamed `_apply_effects` (was `_apply_item_effects`) emits it after a spoken response with `opens_barter`, then closes the dialogue panel.
- `Npc._on_interacted` connects `barter_requested` → opens `BarterPanel` over its live merchant `Inventory` + purse + `player.inventory_component`. The `Npc` owns both panels, exactly as it owns the `DialoguePanel`.
- A merchant's dialogue carries a plain-meaning "trade" topic/choice → a response with `opens_barter = true`.

### Gold quest rewards

`DialogueResponse.give_gold: int = 0` — an effect. `_apply_effects` calls `_inventory_component.add_gold(give_gold)` and appends a notice. One shipped reward is retrofitted to pay coin (content — a warden stipend / `a_small_favor`), proving the path end-to-end.

### Drop-to-world (closes 012's encumbered-no-drop debt)

`InventoryPanel` gains a **Drop** button, enabled for any carried stack (disabled on `[E]` rows and empty selection). Drop removes one via the component and emits `signal drop_requested(item: ItemDef)`; the `Player` (which opens the panel) spawns a `WorldItem` (`scenes/world/world_item.tscn`) a short forward offset at its feet. Non-persistent by the fence — a reload loses it; the stash is the durable relief. Stated caveat.

### The player stash — `Game.stash`, SAVE_VERSION → 3

- `Game` gains `var stash: Inventory`, wired exactly like `inventory`: built in `_ready`, reset in `start_new_game`, replaced in `_apply_load`, carried on `SaveCodec.SaveState.stash` in `save_game`/`_apply_load`.
- **Access:** a stash chest in a Lastdoor interior opens a **deposit-capable** `ContainerPanel` over `Game.stash`. `ContainerPanel` gains an `allow_deposit` flag: when true it also lists the taker's stacks and shows a **Deposit** button (loot containers stay take-only — the flag defaults false). The chest resolves `Game.stash` at open — a narrow, documented, spec-sanctioned `Game` read, the chest being the stash's designated world anchor (the `save_game`/death-overlay precedent of a system calling `Game`). Flagged for the gdscript-conventions review.
- **Save:** `const SAVE_VERSION := 3`; `"stash"` added to `_ROOT_KEYS`; encode/decode reuse `inventory_to_dict`/`inventory_from_dict` verbatim (a stash *is* an `Inventory`, resolved through the `items` resolver `decode_save` already takes). `_migrate_v2_to_v3(data)` seeds `data["stash"]` with an empty inventory dict and stamps `save_version = 3`. `_migrated` is restructured to apply successive steps, so a v1 save chains v1→v2→v3 (factions seeded *then* stash added).

### Ripple check (why little else changes)

Additive throughout. No shipped `DialogueResponse` sets `opens_barter`/`give_gold` (default off/0), so every existing exchange is untouched. `ContainerPanel.allow_deposit` defaults false → every loot `WorldContainer` is unchanged. The only save-payload growth is one additive `stash` section; v1/v2 saves migrate rather than break. The four `SAVE_VERSION`-touching tests (`test_save_codec`, `test_save_load`, `test_player_casting`, `test_title_screen`) flip 2 → 3 by design — the intended tripwires for this bump.

## Architecture

| new file | role |
|---|---|
| `scripts/resources/merchant_def.gd` | `MerchantDef extends Resource` |
| `scripts/economy/barter_rules.gd` | `BarterRules` — pure static price math + category gating |
| `scripts/economy/merchant_library.gd` | `MerchantLibrary` — folder scanner |
| `data/merchants/suddel.tres` · `tansy.tres` | two merchant defs (`buys` specialised; `price_multiplier` 1.0) |
| `scripts/ui/barter_panel.gd` + `scenes/ui/barter_panel.tscn` | `BarterPanel extends CanvasLayer` — two-sided trade |
| `tests/data/test_merchant_defs.gd` | content validator (Golden Rule) |
| `tests/unit/test_barter_rules.gd` | price math + `can_sell` + the spread invariant |
| `tests/scenes/test_barter_panel.gd` | buy/sell guards + signals |
| `tests/scenes/test_stash.gd` | deposit/withdraw persists across save/load |

**Modified:** `scripts/resources/dialogue_response.gd` (`opens_barter`, `give_gold`) · `scripts/ui/dialogue_panel.gd` (`barter_requested`, `_apply_effects`) · `scripts/world/npc.gd` (`merchant_def` + live merchant runtime + `BarterPanel`) · `scripts/resources/balance_config.gd` + `data/balance/balance_config.tres` (Economy group) · `scripts/ui/inventory_panel.gd` + `scenes/ui/inventory_panel.tscn` (Drop + `drop_requested`) · `scripts/player.gd` (spawn `WorldItem` on drop) · `scripts/ui/container_panel.gd` + `scenes/ui/container_panel.tscn` (`allow_deposit`) · `scripts/systems/game.gd` (`stash` + save wiring) · `scripts/systems/save_codec.gd` (SAVE_VERSION 3 + `stash` section + `_migrate_v2_to_v3` + chain) + `SaveState` · a Lastdoor interior scene (stash chest) + Suddel/Tansy trade dialogue (canon-packet) + one gold reward · `tests/unit/test_save_codec.gd` · `tests/scenes/test_save_load.gd` · `tests/scenes/test_player_casting.gd` · `tests/scenes/test_title_screen.gd` (2 → 3) · `tests/scenes/test_inventory_panel.gd` (drop) · a dialogue test (give_gold) · `docs/master-plan.md` · `CLAUDE.md`.

## Acceptance criteria (GUT tests)

1. **Merchant data** (`test_merchant_defs.gd`): the 2 defs load; ids unique and equal to filename stems; `npc_id` resolves to `data/npcs/<id>.tres`; every `stock` item id resolves in `ItemLibrary`; every `buys` entry is a known category; `merchant_gold ≥ 0`; `price_multiplier > 0`.
2. **Price math** (`test_barter_rules.gd`): **`sell_price ≤ buy_price` for every shipped item** (the spread invariant); prices scale with `price_multiplier` and `persuasion_factor` and clamp to ≥ 1 / ≥ 0; `item_category` maps each `ItemDef` subclass; `can_sell` false off-category, true when `buys` empty or the category is listed.
3. **Barter panel** (`test_barter_panel.gd`): buying moves the item to the player and coin to the merchant, refused when player gold < price or the merchant lacks the stack; selling refused off-category and when `merchant_gold < sell_price`, else moves item → merchant and coin → player; the sell list omits `can_sell`-false stacks; `gold_changed` fires; a failed guard mutates nothing.
4. **Dialogue effects** (a dialogue test): a response with `opens_barter` emits `barter_requested` and closes the dialogue panel; `give_gold` raises player gold by exactly that amount through the component.
5. **Stash + save** (`test_stash.gd` + `test_save_codec.gd` + `test_save_load.gd`): a deposit-mode `ContainerPanel` moves stacks both ways between `Game.stash` and the player; a save/load round-trip preserves stash contents and the file carries `"save_version": 3`; a `stash` section round-trips through a real JSON string; a **v2 payload (no `stash`)** decodes to a v3 `SaveState` with an empty stash; a **v1 payload** chains v1→v2→v3 (factions seeded *and* stash added); a `SAVE_VERSION + 1` payload is still refused.
6. **Drop** (`test_inventory_panel.gd`): Drop removes one from the selected stack and emits `drop_requested` with the item; the row updates on refresh; Drop is disabled on `[E]` rows and empty selection.

Not machine-validated (human / canon-keeper review): merchant stock and price balance, trade-dialogue prose under the plain-meaning anchor, the stash-chest `Game.stash` read.

## How to implement

One commit each, full suite green (495 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 016 begins — the counter opens at Lastdoor`)
2. `MerchantDef` + `data/merchants/*.tres` + `MerchantLibrary` + `test_merchant_defs.gd` + `BalanceConfig` Economy group (criterion 1). (`economy: MerchantDef content type + the counter's tunables`)
3. `BarterRules` + `test_barter_rules.gd` — pure, no `Game` (criterion 2). (`economy: pure price math — buy > sell, category gating, inert persuasion lever`)
4. `BarterPanel` + `opens_barter` + `barter_requested` + `Npc.merchant_def` wiring + `test_barter_panel.gd` (criterion 3). (`economy: barter panel off dialogue`)
5. `give_gold` effect + drop-to-world (`InventoryPanel` Drop + `Player` spawn) + tests (criteria 4, 6). (`economy: gold rewards + drop-to-world`)
6. `Game.stash` + stash chest + `ContainerPanel` deposit mode + `SaveCodec` v3 + `_migrate_v2_to_v3` + chain; flip the four SAVE_VERSION guards; `test_stash` + save/migration tests (criterion 5). (`save: SAVE_VERSION 3 — the player stash + v2→v3 migration`)
7. Canon-packet pass → Suddel + Tansy stock/gold/trade dialogue + one gold quest reward + stash-chest placement; canon-keeper-reviewer first. (`content: the counter opens — Suddel and Tansy trade`)
8. Docs housekeeping — master-plan Decision Log rows + status + §4 row → complete; CLAUDE.md focus. (`docs: spec 016 complete`)
