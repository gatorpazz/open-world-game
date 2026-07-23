# Spec 023 — Enchanting-analog (bound workings)

**Status:** complete (2026-07-23)

**Implementation notes (amendments):** the effect coverage shipped is the tested set — **on-hit** `damage`, **constant** `resist` + `fortify`, **on-use** `heal` (the give-back). Constant `ward` pool-seeding and on-use `damage`/`ward` are recognized by the vocabulary but not yet wired (a mis-authored one is a safe no-op / `push_warning`, no charge wasted); they join a later pass. The def validator shipped as a **smoke test in commit 2** (the type had no content yet) and expanded to the full per-def validator in commit 7 with the first defs — avoids risky empty-loop tests. `EnchantRules` + `BoundWorkingLibrary` live in `scripts/enchant/`. Content: 3 items into Tansy's rare stock (placement logged as a `tansy.md` Open-questions line — her canon stock is botanical/daylight salvage, the iron-gear precedent); the give-back ratification resolved the reserved `the_workings` line (person-as-holder half still reserved).
**Depends on:** 008 (`SpellDef`/`CombatMath.spell_power` — the aspect magnitude-scaling a bound working reuses; the aspect skills evocation/mending/warding), 004 (`HurtBox`/`take_hit`/`player_combat` — the on-hit discharge rides the defense pipeline), 001/002 (`ItemDef` + `InventoryComponent` equip/use — the item carrier and the constant/on-use hooks), 016 (`MerchantDef.stock` — the rare-stock acquisition path), 018 (`the_workings` notice economy — bound workings are ruled notice-free, so this is the *non*-dependency the ruling settles), 011 (`the_workings` — the give-back ratification lands here)
**Consumed by:** 024 (creature loot may drop a bound-working item), Phase 3 (a real enchanting bench + soul-charge recharge + faction-rank reward delivery + on-worn fortify-attribute)

## Scope

**In:** a **`BoundWorkingDef`** content type (`scripts/resources/`) — a hand-authored stored working with a **trigger** (`constant` / `on_hit` / `on_use`), an **effect** (`damage` / `heal` / `fortify` / `ward` / `resist`), an optional aspect **skill_id** (evocation/mending/warding — empty = an unscaled hearth-charm), a **magnitude**, a **duration** (ward/timed), and an optional **subject** (the skill a `fortify` lifts) · a **`BoundWorkingLibrary`** (the `SpellLibrary`/`RecipeLibrary` scanner) · an optional **`ItemDef.bound_working`** reference (null = a plain item; any item may carry one) · pure **`EnchantRules`** (`scripts/enchant/`) — `magnitude(working, aspect_skill, config)` (the `spell_power` reuse), `constant_bonus(equipped, effect, subject, config)` (aggregate worn charms), `is_bound`/`triggers` helpers · three thin **hooks**: **constant** (worn charms fold into `InventoryComponent` aggregation → the defense pipeline + the combat/magic skill reads), **on_hit** (after `player_combat` lands a hit, the equipped weapon's working discharges into the target's `HurtBox` — the 004 pipeline), **on_use** (a bound `on_use` item triggers its working through the `InventoryComponent` and is consumed — single-use) · a **`BalanceConfig` Enchant** group · **canon-packet content** — a few worked-glass/blessing-marked bound-working items into rare merchant stock + **the give-back ratification** logged in `the_workings` (canon-keeper) · full GUT coverage.

**Out (later specs / backlog):**
- **A player enchanting bench / dynamic crafted enchantments** → Phase 3 (the "no dynamic crafted items in Phase 2" ruling). 023 ships hand-authored `BoundWorkingDef`s only; `ItemLibrary` serializes by id.
- **Charges + recharge (soul-gem loop)** → Phase 3. Constant/on-hit are always-on; `on_use` items are single-use consumables. No per-instance charge state, so **no `SAVE_VERSION` bump** (the 022 precedent).
- **Faction-rank reward *delivery*** → the acquisition hook is documented, but 015 shipped no rank-up reward mechanism (promotion conversations deferred), so v1 acquires bound workings from **rare merchant stock** (016). Rank delivery is a Phase-3 wire.
- **Fortify an attribute** (vs a skill) and **timed non-ward buffs** → later; v1 `fortify` lifts a named skill, `ward`/`resist` cover defense.
- **A new Enchant skill** → none. No crafting means no making-skill; a bound working's power scales on its **aspect school skill** (the 008 skills), and an unscaled charm is flat.

## Design

### Faithfulness rulings (director, 2026-07-23)

Canon is load-bearing and already mostly written. `the_workings`: *"a worked thing is a regarded thing — objects hold the attention given them"*; **lava-glass holds the charge best** (lens and bead are glass for it); **blessing-marks and hearth-charms** sit on objects (an oven blessed, a bell quieted). So a bound working = a worked-glass or blessing-marked object carrying a stored working. Rulings:

1. **The give-back is ratified for bound workings.** `the_workings` reserved whether stored regard can be *released back into a person*; 023 owns that line and opens it — a worked thing may give its regard back, so **restorative and fortify enchants** (heal-on-use, constant fortify/ward/resist) are in, alongside outward on-hit discharge. Canon-keeper records the ratification in `the_workings` (the reserved Open-question line resolves).
2. **All three hooks ship**: `constant` (a worn charm's standing effect), `on_hit` (an enchanted weapon discharging into the struck target), `on_use` (a charged item the player triggers).
3. **Bound workings are notice-free.** The regard is the *object's* — blessed/chartered at forging — not the wielder casting fresh unlicensed magic, so wearing or triggering one draws **no notice** (018 untouched). Constant charms are hearth-charm level by canon; this keeps 023 additive.
4. **No charges, save-neutral** (the 022 shape): constant/on-hit always-on; `on_use` single-use; no per-instance state, **no `SAVE_VERSION` bump**, **no new skill**; recharge is Phase 3.

### The content type — `BoundWorkingDef` + `BoundWorkingLibrary`

`scripts/resources/bound_working_def.gd`: `id`, `display_name`, `description`, `trigger: StringName` (`&"constant"`/`&"on_hit"`/`&"on_use"`), `effect: StringName` (`&"damage"`/`&"heal"`/`&"fortify"`/`&"ward"`/`&"resist"`), `skill_id: StringName` (aspect for scaling; empty = flat hearth-charm), `magnitude: float`, `duration: float` (ward seconds; 0 = instant/constant), `subject: StringName` (the skill a `fortify` lifts; empty otherwise). `BoundWorkingLibrary` scans `data/bound_workings/*.tres` into an `id -> def` map (the `SpellLibrary` twin). A `tests/data/` validator loads every def: unique ids, a known trigger+effect, a resolvable aspect `skill_id`/`subject` when set, `fortify` names a `subject`, `damage`/`heal` name an aspect.

### The carrier — `ItemDef.bound_working`

`@export var bound_working: BoundWorkingDef` on the **base `ItemDef`** (null = plain). Any item type may carry one; the firing hook is the working's `trigger` matched to the item's role (a `constant` charm fires while the item is equipped; `on_hit` fires from an equipped weapon; `on_use` fires when the item is used). Additive — every existing item defaults `null`, unchanged.

### Pure logic — `EnchantRules` (`scripts/enchant/enchant_rules.gd`)

- `magnitude(working, aspect_skill, config) -> float`: `CombatMath.spell_power(working.magnitude, aspect_skill, config)` when `skill_id` set, else `working.magnitude` (flat). The 008 reuse — a bound working scales like the school it belongs to.
- `constant_bonus(equipped: Array[ItemDef], effect: StringName, subject: StringName, sheet, config) -> float`: sums `magnitude(...)` over equipped items whose `bound_working` is `constant`, matches `effect`, and (for `fortify`) matches `subject`. Pure — the aggregation seam the combat/magic reads and the defense pipeline call.
- `triggers(item, trigger) -> bool` / `is_bound(item) -> bool`: small predicates.

### The three hooks (thin, calls-down)

- **Constant** — `InventoryComponent` gains `bound_bonus(effect, subject)` folding `EnchantRules.constant_bonus` over equipped items (it already owns equipment + `get_total_armor_rating`). Wire it in: `resist`/`ward` add to the effective armor in the defense pipeline (`player_combat._on_hit_taken`); `fortify` adds to the effective skill at the combat/magic read sites (`player_combat` weapon+block reads; a helper `effective_skill(skill_id)` keeps it one call). Constant `ward` seeds a passive ward pool at scene entry.
- **On-hit** — in `player_combat.try_attack`, after `target.take_hit(raw, self)`, if the equipped weapon carries an `on_hit` working, discharge `EnchantRules.magnitude(...)` as a second `take_hit` into the same target (rides the 004 defense pipeline; outward damage — the discharge, not a give-back).
- **On-use** — `InventoryComponent.use_bound_working(item)` (the `use_consumable` sibling): triggers the working (`heal` → `apply_health_delta` give-back; `damage` → a self-targeted no-op in v1, reserved; `ward` → seed the pool), then removes one (single-use). Wired into the `InventoryPanel` Use action beside `use_consumable`.

### `BalanceConfig` Enchant group

`@export_group("Enchant")`: `enchant_ward_default_duration` (a bound `ward`'s seconds when its def leaves `duration` 0), plus any scaling knob the reuse needs. Magnitude scaling reuses the existing Magic group (`spell_power`); no duplicate constants.

### Acquisition & content

- **Rare merchant stock (016):** a couple of bound-working items enter a merchant's `stock` (Tansy's *"a rarity or two if the crews were kind"* is the canon hook). They price off `base_value` like any item.
- **Content (canon-packet):** 3 hand-authored bound-working items grounded in `the_workings` — e.g. a **lava-glass flame-bead set on a bronze blade** (`on_hit` damage, evocation), a **tide-bead** worked-glass charm (`on_use` heal — the ratified give-back, mending), and a **blessing-marked hound-hide jack** (`constant` resist/fortify — a hearth-charm on gear). Ids/materials from the 014 palette; the give-back ratification + any new object facts logged as `the_workings` lines.

### Ripple check (why little else changes)

Additive. `ItemDef.bound_working` defaults null → every existing item and all item tests unaffected. No `Game` state, **no save touch** (bound items serialize by id; on-use consumes like a draught). The on-hit hook is one block after an existing `take_hit`; the constant hook folds into the existing armor/skill aggregation; on-use mirrors `use_consumable`. 018's notice is untouched by ruling. No new skill, no new input (on-use rides the inventory Use action).

## Architecture

- **Content types:** `BoundWorkingDef` (`scripts/resources/`) + `BoundWorkingLibrary` + the optional `ItemDef.bound_working` seam. Content in `data/bound_workings/` and on the carrier items in `data/items/`.
- **Pure logic:** `EnchantRules` (`scripts/enchant/`) — all math, no `Game`/nodes, unit-tested; reuses `CombatMath.spell_power`.
- **Hooks:** thin additions to `InventoryComponent` (constant aggregation + on-use), `player_combat` (on-hit discharge + constant reads), `InventoryPanel` (the Use action). Calls-down throughout.
- **No save surface, no autoload, no new skill or input.**

## Acceptance criteria (GUT tests)

1. **Def validation** (`test_bound_working_defs.gd`): every `BoundWorkingDef` has a unique id, a known `trigger` and `effect`, a resolvable aspect `skill_id`/`subject` where set, and the effect/field invariants (`fortify` names a `subject`; `damage`/`heal` name an aspect).
2. **Magnitude** (`test_enchant_rules.gd`): `magnitude` scales a working with an aspect skill via `spell_power` (rises with skill) and returns the flat base for an unscaled charm; `constant_bonus` sums only matching-effect (and, for fortify, matching-subject) `constant` workings over equipped items and ignores non-bound / wrong-trigger items.
3. **On-hit** (`test_enchant_on_hit.gd`): an equipped weapon with an `on_hit` damage working deals its discharge into the target on top of the weapon hit (the target takes more than the bare weapon damage); a plain weapon discharges nothing.
4. **Constant** (`test_enchant_constant.gd`): equipping a `constant` `resist` charm raises the player's effective armor (less damage taken); a `fortify` charm raises the effective skill at the combat read; unequipping removes both.
5. **On-use** (`test_enchant_on_use.gd`): using a bound `on_use` heal item restores health scaled by the mending skill (the ratified give-back) and consumes one; a bound item with no charge left is gone.

Not machine-validated (human / canon-keeper review): the bound-working item prose + the give-back ratification in `the_workings` under the plain-meaning anchor (worked glass holds the charge; blessing-marks on objects; no apparatus canon doesn't hold), the enchant magnitudes, the acquisition feel.

## How to implement

One commit each, full suite green (653 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 023 begins — the regard a thing holds`)
2. `BoundWorkingDef` + `BoundWorkingLibrary` + `ItemDef.bound_working` + the def validator + the Enchant config group (criterion 1). (`enchant: the bound-working content type`)
3. `EnchantRules` (`magnitude` + `constant_bonus` + predicates) + `test_enchant_rules` (criterion 2). (`enchant: the pure magnitude + aggregation rules`)
4. The on-hit hook (`player_combat` discharge) + `test_enchant_on_hit` (criterion 3). (`enchant: weapons that discharge on hit`)
5. The constant hook (`InventoryComponent.bound_bonus` + defense/skill wiring) + `test_enchant_constant` (criterion 4). (`enchant: worn charms`)
6. The on-use hook (`InventoryComponent.use_bound_working` + the panel Use action) + `test_enchant_on_use` (criterion 5). (`enchant: charged workings`)
7. Canon-packet pass → 3 bound-working items + rare merchant stock + the give-back ratification in `the_workings`; `canon-keeper-reviewer` first. (`content: three worked things that hold a working`)
8. Docs housekeeping — Decision Log rows + status + §4; CLAUDE.md focus. (`docs: spec 023 complete`)
