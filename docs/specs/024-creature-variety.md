# Spec 024 — Creature variety pass

**Status:** ready to implement
**Depends on:** 004 (`CreatureDef`/`creature.gd` — the AI state machine + flat-stat defs this extends; `HurtBox`/`take_hit` the ranged spit reuses; `WitnessQuery`-adjacent LOS the spit checks), 016 (`base_value` — new drop materials price for sale; `MerchantDef` categories), 022 (`IngredientDef` — a drop doubles as an alchemy ingredient), 011 (`new-lore-entry` — the ~2 new canon-creature stubs + the hush-moths grounding)
**Consumed by:** 010's exit-audit shape (a fuller bestiary for the slice); Phase 3 (more biomes/creatures as settlement scenes land; a real projectile visual for the spit)

## Scope

**In:** a **lean bestiary of ~6 `CreatureDef`s** (the 3 existing — scar-hound, vault-rat, stair-drowned — plus a hush-moths def and **~2 new canon-creature defs**) placed across the existing wild scenes · **two cheap AI additions** on `creature.gd`, each a `CreatureDef` field + a small branch: **ambient non-hostile** (`hostile: bool`, false = never aggros — wanders/ignores the player, the hush-moths niche) and a **ranged spitter** (`attack_range: float`, > 0 = attacks from range with a hitscan spit, the player-bolt shape, LOS-gated) · **new canon drop materials** — one per new huntable kind, priced for 016 sale, **≥ 1 doubling as a 022 `IngredientDef`** · **~2 new lore stubs** (`new-lore-entry`) grounding the new creatures + the hush-moths def · the `test_creature_defs` validator extended for the new fields · full GUT coverage. **Content spec** — no `Game` state, **no `SAVE_VERSION` bump** (remains are non-persistent `WorldContainer`s — the 007 fence; drops are `ItemLibrary` items by id).

**Out (later specs / backlog):**
- **A projectile visual for the spit** → Phase 3. The spit is **hitscan** (instant `take_hit` within `attack_range` + LOS) — byte-consistent with the player's own evocation bolt (also hitscan, no projectile scene). A real projectile is a later polish, not a new mechanic.
- **Flee / pack-call AI** → not this pass (director picked ambient + ranged). The state machine stays small.
- **Humanoid/equipment-wielding NPCs** → still a future decision (`CreatureDef` stays flat — no skills, no xp; the 004 warning holds).
- **The leviathan as a fought creature** → never — canon's untouchable sea-terror stays offscreen lore, not a `CreatureDef`.

## Design

### Faithfulness rulings (director, 2026-07-23)

Canon fauna is sparse and roofed. The strongest material: **scar-hounds** (surface pack), **vault-rats / vermin**, the **drowned** (the flooded stair), and **hush-moths** — canonically *non-hostile*, gathering to freshly spent regard, crowding lamps, never attacking (`hush_moths`). Rulings: a **lean ~6-creature bestiary** (010-slice discipline over a sprawl); **two AI additions — ambient non-hostile + a ranged spitter**; **a new canon material per huntable kind** (sellable, ≥ 1 an alchemy ingredient). The leviathan stays lore-only.

### AI addition 1 — ambient non-hostile (`CreatureDef.hostile: bool = true`)

`_can_aggro()` returns false when `not def.hostile`, so the creature never leaves IDLE/WANDER — it drifts, ignores the player, and never joins the `&"hostile"` group (spec 020's rest-danger check stays honest: an ambient creature is not "danger near"). Hush-moths are the canon case: living atmosphere, the roofed world's omen of spent regard. Default `true` — every existing creature is unchanged.

### AI addition 2 — ranged spitter (`CreatureDef.attack_range: float = 0.0`)

`0.0` = melee only (the default; every existing creature unchanged). `> 0` = the creature attacks from range: **CHASE** closes only to `attack_range` (not `attack_reach`), then **ATTACK** spits — a **hitscan** `take_hit` on the target's `HurtBox`, LOS-gated (`_has_line_of_sight`), on the existing `attack_cooldown`. The spit reuses the player-bolt shape (instant, no projectile). A ranged creature that loses LOS or range falls back to CHASE. The attack-distance helper (`attack_range if attack_range > 0 else attack_reach`) is the one branch the state machine grows.

### Content — ~6 creatures, canon-packet grounded (`new-lore-entry` for the new ones)

- **Existing (unchanged):** scar-hound, vault-rat, stair-drowned.
- **Hush-moths** (`hostile = false`) — a def for the existing `hush_moths` lore; ambient placement (drifting near lamps/shaft-mouths). Loot minimal or none (they are omen, not quarry).
- **~2 new canon-creature defs** — one a **ranged spitter** (a vent/cave dweller that spits — grounded via a new lore stub), one a **melee** kind (a vermin/drowned variant or a new canon creature — a second lore stub). Exact identities + materials settle at the content commit under a canon packet, held to the plain-meaning anchor and the palette (no chitin where regard must be held; the 014 material rulings).
- **New drop materials:** one canon material per new huntable kind — a `WeaponDef`-free `MiscDef`/material item priced off `base_value` for 016 sale, with **≥ 1 authored as a 022 `IngredientDef`** (effects list) so a kill feeds alchemy. Existing drops (rat_pelt, hound-hide) stay.
- **Placement:** the new creatures instance `creature.tscn` with their `def` into the existing wild scenes' `Creatures` nodes (scar_route, drowned_stair), the established pattern; ambient hush-moths add life without combat.

### Ripple check (why little else changes)

Additive. `CreatureDef.hostile`/`attack_range` default to the current behavior (hostile melee), so every existing creature and all combat/creature tests are unmoved. The two AI branches are guarded on the new fields. No `Game` state, **no save surface** (remains are world-state, drops are id-serialized items). New materials are ordinary items; the ingredient rides 022's existing machinery. The lore suite validates the new stubs; `test_creature_defs` gains field-range checks.

## Architecture

- **Content:** ~3 new `CreatureDef`s in `data/creatures/`, new material items in `data/items/` (≥ 1 an `IngredientDef` in `data/ingredients/`), ~2 new lore stubs in `docs/lore/wildlife/`, placement edits to the wild scenes.
- **Code (thin):** two `CreatureDef` fields + two guarded branches in `creature.gd` (`_can_aggro` for ambient, `_tick_chase`/`_tick_attack` for ranged). No new class, no new node, no autoload, no save touch.
- **Validation:** `test_creature_defs` extended (hostile is bool, attack_range ≥ 0, a ranged def's attack_range ≥ attack_reach); the lore suite covers the stubs; a small `test_creature_ai` scene test for the two behaviors.

## Acceptance criteria (GUT tests)

1. **Def validation** (`test_creature_defs.gd`): every `CreatureDef` still passes the flat-stat invariants; `attack_range` is ≥ 0 and (when > 0) ≥ `attack_reach`; `hostile` present. The bestiary count matches the shipped set.
2. **Ambient non-hostile** (`test_creature_ai.gd`): a `hostile = false` creature with the player in detect range + LOS never enters CHASE (stays IDLE/WANDER) and never joins the `&"hostile"` group.
3. **Ranged spitter** (`test_creature_ai.gd`): a creature with `attack_range > attack_reach` and the target within `attack_range` + LOS deals damage (a `hit_taken` on the target's HurtBox) without closing to melee reach; out of `attack_range` or LOS, it does not.
4. **Loot** (extends `test_creature_defs` / `test_item_defs` / `test_ingredient_defs`): every new drop material resolves as an item with a positive `base_value`; the ingredient(s) validate against 022's rules.
5. **World-scene lint** (`test_world_scenes.gd`): the wild scenes still instantiate and every creature `def` reference resolves (the new placements included).

Not machine-validated (human / canon-keeper review): the new creature prose + lore stubs + drop-material names under the plain-meaning anchor and the material palette (no invented apparatus; the leviathan stays lore-only); the bestiary's threat/loot feel; ambient placement.

## How to implement

One commit each, full suite green (676 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 024 begins — a fuller bestiary`)
2. `CreatureDef.hostile` + `attack_range` + the two `creature.gd` branches + `test_creature_ai` + the `test_creature_defs` field checks (criteria 1-3). (`creatures: ambient drift and a ranged spit`)
3. Canon-packet pass → the new drop materials (items + ≥ 1 ingredient) + the hush-moths def + ~2 new creature defs + ~2 lore stubs + wild-scene placement; `canon-keeper-reviewer` first (criteria 4-5). (`content: the roofed world's other tenants`)
4. Docs housekeeping — Decision Log rows + status + §4; CLAUDE.md focus. (`docs: spec 024 complete`)
