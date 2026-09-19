# Spec 022 — Alchemy v1 (Brewing Fixed Recipes)

**Status:** complete (2026-07-23)
**Depends on:** 001 (the `alchemy` skill already ships — intellect/magic archetype, "Brewing potions and identifying ingredients"; `sheet.skills.get(&"alchemy", 0)` + `gain_skill_xp` are the read/grant), 002 (`ItemDef`/`ConsumableDef`/`Inventory`/`ItemStack` — ingredients and the brewing kit are items; the outputs are existing `ConsumableDef`s; `ItemLibrary` resolves ids), 008 (`PlayerCasting.filter_castable` — the derived, never-stored skill-gated list `AlchemyRules.known_recipes` mirrors; `gain_skill_xp`-per-action), 012 (`InventoryPanel` — the key-opened, tree-pausing panel lifecycle the brewing panel follows; the context action precedent), 016 (`BarterPanel` — the two-sided panel + `process_mode = ALWAYS` while paused; merchants could stock ingredients later)
**Consumed by:** Phase 3 (spell/service vendors could teach recipes; regional ingredients), 024 (creatures — creature drops become ingredients; the `hound_fang` precedent), 023 (enchanting — the sibling "fixed recipes, no dynamic items" craft; shares the `AlchemyRules` shape)

## Scope

**In:** a new **`IngredientDef`** item type (canon materials, with an ordered `effects` list for inspection) + a **`RecipeDef`** content type (exact ingredients → an existing `ConsumableDef`, a base yield, an alchemy `min_skill`) · pure **`AlchemyRules`** (`scripts/alchemy/`) — `known_recipes` (derived from skill, never stored, the `filter_castable` analog), `can_brew`, `brew_yield` (**scales with alchemy skill**), `discovered_effects` (the first k effects, k derived from skill) · a **brewing panel** (the `InventoryPanel`/`BarterPanel` lifecycle) showing known recipes + your ingredients' *discovered* effects, with a **Brew** action that consumes inputs and grants the yield through the `InventoryComponent` and awards `alchemy` xp · a **carried apparatus** (a brewing-kit `MiscDef`) + a **`brew` input** that opens the panel only while the kit is held · a `BalanceConfig` **Alchemy** group · **3 canon ingredients + the kit + 2 recipes** (into `healing_draught` / `mana_draught`), canon-packet authored · full GUT coverage. **No new `Game` state, no `SAVE_VERSION` bump** — recipes and discovery are derived; ingredients, the kit, and outputs are items already in the save.

**Out (later specs / backlog):**
- **Dynamic crafted items** → never in Phase 2 (Decision Log). Brews are **existing `ConsumableDef`s** by id; no player-authored items, no `SAVE_VERSION` serialization question.
- **Freeform effect-matched brewing** (Morrowind's any-two-shared-effects) → rejected for v1: recipes are **fixed exact-ingredient → output**. Ingredient `effects` are the *inspection* layer only (the "identify ingredients" fantasy), not a brewing input. **Director ruling (2026-07-23).**
- **Brewing failure rolls** → rejected (the no-dice culture, 004/008/017). Brewing a known recipe you hold ingredients for always succeeds; skill scales *yield*, never a pass/fail.
- **Output potency scaling** → a `ConsumableDef`'s restores are fixed; skill scales the **count** of draughts, the only lever without dynamic items.
- **A world brewing bench** → not chosen; brewing is a **carried apparatus** (director ruling). A bench station is a later option.
- **Ingredient-gathering / harvest nodes, herbalism** → later; ingredients enter play as loot/merchant stock (024/Phase 3).
- **Poisons / apply-to-weapon, on-hit alchemy** → later.
- **Alchemy under the license teeth** → no: alchemy is a free domestic craft, **not** notice-gated (spec 018 recorded "022 — no direct dep"; canon reads folk/hearth-level — Tansy's terrace simples, the salter's brine tonic).

## Design

### Faithfulness rulings (director, 2026-07-23)

1. **Fixed recipes + ingredient inspection.** `RecipeDef` maps exact ingredients → an existing `ConsumableDef`. Alchemy skill gates which recipes you *know* (a `min_skill`, derived like the spell list) and, separately, reveals an ingredient's `effects` progressively on inspection. The effects are descriptive flavor (they don't pick the brew); brewing stays deterministic.
2. **A carried apparatus.** A brewing-kit item opens the panel anywhere it's held — Morrowind-portable. No world bench in v1.
3. **Yield scales with skill.** More alchemy → more draughts per brew.
4. **Free domestic craft.** Alchemy draws no notice and needs no charter (spec 018; canon folk-craft).

### Content — the Golden Rule types

**`IngredientDef extends ItemDef`** (`scripts/resources/ingredient_def.gd`; content in `data/items/*.tres`, so `ItemLibrary` and the item validator pick it up for free):

| field (adds to ItemDef) | type | meaning |
|---|---|---|
| `effects` | Array[StringName] | the ingredient's effects, **ordered** — inspection reveals the first *k* as alchemy skill rises. Each must be a known effect tag. |

**`RecipeDef extends Resource`** (`scripts/resources/recipe_def.gd`; content in `data/recipes/*.tres`):

| field | type | meaning |
|---|---|---|
| `id` | StringName | matches the filename stem |
| `display_name` | String | the brew's name on the panel |
| `inputs` | Array[ItemStack] | required ingredients + counts (the `MerchantDef.stock` shape) |
| `output_id` | StringName | the `ConsumableDef` this brews (validator resolves it in `ItemLibrary` and checks it's a `ConsumableDef`) |
| `output_count` | int ≥ 1 | base yield before the skill bonus |
| `min_skill` | int | the alchemy level that unlocks the recipe (the 001 tier values) |

The known effect-tag vocabulary is a `const AlchemyRules.EFFECTS` (e.g. `restore_health` / `restore_mana` / `restore_stamina` / `hide_regard`), the `WorkingRules.ASPECT_ORDERS` precedent — a closed structural set the validator checks `IngredientDef.effects` against. Tags are flavor labels, not behavior (fixed recipes carry the mechanics).

### Pure logic — `AlchemyRules` (static, `scripts/alchemy/`, the `WorkingRules`/`CrimeRules` shape)

- `known_recipes(recipes: Array[RecipeDef], sheet: CharacterSheet) -> Array[RecipeDef]` — every recipe with `sheet.skills.get(&"alchemy",0) >= min_skill`, sorted deterministically (min_skill, id). The `filter_castable` analog — derived, never stored.
- `can_brew(recipe: RecipeDef, inventory: Inventory) -> bool` — `inventory.count_of(input.item) >= input.count` for every input.
- `brew_yield(recipe: RecipeDef, sheet, config) -> int` — `recipe.output_count + floori(alchemy / config.alchemy_yield_skill_step)` (yield scales with skill; a step of, say, 25 gives +1 per tier). Clamped ≥ `output_count`.
- `discovered_effects(ingredient: IngredientDef, sheet, config) -> Array[StringName]` — the first `k` of `ingredient.effects`, `k = config.alchemy_base_discovery + floori(alchemy / config.alchemy_discovery_step)`, clamped to `effects.size()`. Derived from skill, never stored — a fresh alchemist reads one effect, a skilled one reads them all.

### Brewing — the panel + the apparatus (`scripts/ui/brewing_panel.gd` + `player.gd`)

**Access (carried apparatus):** a **brewing-kit `MiscDef`** (`data/items/brewing_kit.tres`) and a new **`brew` input action**. `Player.open_brewing()` (on the `brew` action, the `open_inventory` pattern) opens the panel **only if the inventory holds the kit** (`AlchemyRules.APPARATUS_ID`); otherwise a HUD notice ("You have no brewing kit."). The kit is carried, never consumed.

**`BrewingPanel extends CanvasLayer`** — the `BarterPanel` lifecycle (Dim + centred panel, `get_tree().paused = true`, `process_mode = ALWAYS`, free the mouse, `closed` + `queue_free`, same-key/`ui_cancel` close). `open(taker: InventoryComponent, stats: StatsComponent, config)`:
- **Recipes list** = `AlchemyRules.known_recipes` with, per row, the inputs, the output × `brew_yield`, and whether `can_brew` (held ingredients). A **Brew** button.
- **Ingredients list** = the taker's held `IngredientDef` stacks, each showing its `discovered_effects` (the inspection layer).
- `brew_row(index) -> bool`: guard `can_brew`; `taker.remove_item(input.item, input.count)` for each input; `taker.add_item(output, brew_yield)`; `stats.gain_skill_xp(&"alchemy", config.xp_per_brew)`; refresh. A failed guard is a silent no-op (the 012/016 authority-is-the-component precedent). Direct-call API is the test surface; the button routes through it.

### `BalanceConfig` Alchemy group (`scripts/resources/balance_config.gd` + `.tres`)

`@export_group("Alchemy")`: `alchemy_yield_skill_step: int` (skill per +1 draught, e.g. 25), `alchemy_base_discovery: int` (effects read at skill 0, e.g. 1), `alchemy_discovery_step: int` (skill per +1 revealed effect, e.g. 20), `xp_per_brew: int` (e.g. 5). Every number config-sourced.

### Content (canon-packet, canon-keeper)

- **Ingredients** (`IngredientDef`s, canon-grounded): **terrace fungus** (Tansy's `embershare`-terrace simples — the healing base; effects `restore_health`, `restore_stamina`), **salter's brine** (the healing draught is canonically "a salter's brine-bitter tonic"; `restore_health`), **hush-moth wing-dust** (`hush_moths` "gather to freshly spent regard"; `restore_mana`, `hide_regard`). The **brewing kit** (`MiscDef`) — a salter's/simpler's portable kit; a short lore stub grounds the apparatus (canon has vendors and draughts but no named brewing object — the one gap).
- **Recipes**: **brine tonic** → `healing_draught` (terrace fungus + salter's brine; `min_skill` 0 — a hearth-level domestic brew), **regard philtre** → `mana_draught` (hush-moth wing-dust + terrace fungus; `min_skill` 25 — a chartered-tier alchemy brew). Both output into the *existing* draughts.
- Draught/ingredient/recipe display text runs the `canon-packet` skill first; `canon-keeper-reviewer` before the content commit. The one lore stub (the brewing kit) is scaffolded via `new-lore-entry`.

### Ripple check (why little else changes)

Purely additive. `IngredientDef` lands in `data/items/` so `ItemLibrary`/`Inventory`/the item validator absorb it with no plumbing; ingredients are inert `MiscDef`-like items until brewed. `RecipeDef` is a fresh folder + validator. `AlchemyRules` is pure. The brewing panel is a new key-opened window gated on the kit — every existing flow is untouched. **No `Game` field, no `SAVE_VERSION` change** — the outputs are existing draughts, the ingredients/kit are ordinary saved items, and known-recipes/discovered-effects are derived each open (the 008-casting precedent). `BarterRules.item_category` gains an `ingredient` mapping only if merchants should trade ingredients (deferred — ingredients enter via loot in v1).

## Architecture

| new file | role |
|---|---|
| `scripts/resources/ingredient_def.gd` | `IngredientDef extends ItemDef` — adds the ordered `effects` list |
| `scripts/resources/recipe_def.gd` | `RecipeDef extends Resource` — inputs → a `ConsumableDef` output + yield + `min_skill` |
| `scripts/alchemy/alchemy_rules.gd` | `AlchemyRules` — pure known-recipes / can-brew / yield / discovery + the `EFFECTS`/`APPARATUS_ID` consts |
| `scripts/ui/brewing_panel.gd` + `scenes/ui/brewing_panel.tscn` | `BrewingPanel extends CanvasLayer` — recipes + ingredient inspection + Brew |
| `data/items/terrace_fungus.tres` · `salter_brine.tres` · `hush_moth_dust.tres` · `brewing_kit.tres` | 3 ingredients + the apparatus |
| `data/recipes/brine_tonic.tres` · `regard_philtre.tres` | the two recipes |
| `docs/lore/…/brewing_kit.md` (stub) | the apparatus lore anchor (`new-lore-entry`) |
| `tests/unit/test_alchemy_rules.gd` | known-recipes gate, can-brew, yield scaling, discovery curve |
| `tests/data/test_recipe_defs.gd` | recipe validator (inputs/output resolve, output is a ConsumableDef, counts positive, min_skill a tier) |
| `tests/scenes/test_brewing_panel.gd` | brew consumes inputs → grants the yield + xp; guards; the apparatus gate |

**Modified:** `scripts/player.gd` (`open_brewing` + the `brew` action wiring) + `project.godot` (`brew` input) · `scripts/resources/balance_config.gd` + `data/balance/balance_config.tres` (Alchemy group) · `scripts/ui/hud_notice.gd` (the no-kit notice) · `tests/data/test_item_defs.gd` (item count + `IngredientDef` effect-tag validity) · `docs/master-plan.md` · `CLAUDE.md`.

## Acceptance criteria (GUT tests)

1. **Recipe data** (`test_recipe_defs.gd`): the 2 recipes load; ids unique and equal to filename stems; every `inputs` item id resolves in `ItemLibrary`; `output_id` resolves and is a `ConsumableDef`; `output_count ≥ 1`, input counts ≥ 1; `min_skill` is a licensing tier (0/25/50).
2. **Ingredient data** (`test_item_defs.gd`): the ingredients load as `IngredientDef`; every `effects` tag is in `AlchemyRules.EFFECTS`; the item count bumps.
3. **Alchemy rules** (`test_alchemy_rules.gd`): `known_recipes` excludes a recipe above the sheet's alchemy skill and includes it at/above `min_skill`; `can_brew` false when an ingredient is short, true when all held; `brew_yield` = `output_count` at skill 0 and rises by the config step; `discovered_effects` reveals `alchemy_base_discovery` at skill 0 and more with skill, clamped to the ingredient's list.
4. **Brewing** (`test_brewing_panel.gd`): brewing a known, ingredient-satisfied recipe removes the exact inputs, adds `brew_yield` of the output `ConsumableDef`, and grants `alchemy` xp; brewing is refused (silent no-op) when ingredients are short or the recipe is unknown; the ingredient list shows only `discovered_effects`.
5. **Apparatus gate** (`test_brewing_panel.gd` / a player test): the `brew` action opens the panel only while the brewing kit is held; without it, a HUD notice and no panel.

Not machine-validated (human / canon-keeper review): ingredient/recipe/draught prose under the plain-meaning anchor, the brewing-kit lore stub, brew-yield/discovery balance, the panel's feel.

## How to implement

One commit each, full suite green (588 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 022 begins — the salter's craft`)
2. `IngredientDef` + `RecipeDef` + `AlchemyRules` (pure) + `BalanceConfig` Alchemy group + `test_alchemy_rules` (criterion 3). (`alchemy: content types + pure brewing rules`)
3. Canon-packet pass → the 3 ingredients + the kit + 2 recipes + the brewing-kit lore stub + `test_recipe_defs` + item validator/count (criteria 1, 2); `canon-keeper-reviewer` first. (`content: terrace fungus, brine, moth-dust — and two draughts`)
4. `BrewingPanel` + the `brew` action + `Player.open_brewing` (apparatus-gated) + brew execution + `test_brewing_panel` (criteria 4, 5). (`alchemy: the brewing panel off the carried kit`)
5. Docs housekeeping — master-plan Decision Log rows + status + §4 row → complete; CLAUDE.md focus. (`docs: spec 022 complete`)
