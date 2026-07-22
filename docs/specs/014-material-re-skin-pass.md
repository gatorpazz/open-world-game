# Spec 014 — Material Re-skin Pass

**Status:** complete
**Depends on:** 002 (the item roster this pass re-surfaces), 010/011 (the lore-audit that named the debt; the vault the text is authored from)
**Consumed by:** 016 (barter reads the re-skinned names/values at the counter), 022/023 (any future alchemy/crafting naming inherits this material palette)

## Scope

**In:** surface re-skin of the generic-medieval items in `data/items/` — `display_name` and `description` only, authored canon-packet-first from the vault's material logic (chitin, rope, stone, fungus, lava-glass, bell-bronze salvage, hound-hide) · the four director material rulings recorded below and in the master-plan Decision Log · one sentence added to the bible's Technology line recording gear materials (director-ratified) · the hardcoded display-name literals in `tests/scenes/test_inventory_panel.gd` updated in the same commit · closes the item half of audit debt 1 (010 lore-audit).

**Out (later specs / backlog):** **item ids and filenames — never touched** (Decision Log: 007's unknown-id-skip would silently vaporize renamed items from saves; any unavoidable rename waits for a `SAVE_VERSION` migration carrying an id-remap, machinery 015 introduces) · **the mana term** (**director ruling:** out of scope entirely — `mana_draught` keeps its name and text; coining an in-world term for the casting resource and sweeping the UI labels is a backlog item, and audit debt 1 stays open by exactly that sliver) · any `material`/tier schema field on `ItemDef` (content mini-spec; no code) · stat, weight, or value changes · per-item meshes/icons (no `assets/` dir exists yet) · new lore entries (the item template's own rule: routine gear earns no lore page).

## Design

### Director rulings (2026-07-22 planning session)

1. **Blades are recast bell-bronze salvage; helms are wright-offcut chitin plate.** "Rusty" rereads as verdigris on old bronze.
2. **Ore is bell-bronze scrap** — no mining or smelting exists in canon; heavy metal cargo is broken salvage bound for the recasters.
3. **The leather analogue is oil-dark scar-hound hide** — a small ratified extension (canon traded fangs; the described coats now also trade as hide).
4. **The bow is chitin-lath; the shield is offcut chitin plate** — timber is a closed stock, so no cheap wooden gear exists.

### The re-skin table

Ids, filenames, and all stats byte-stable; only the two text fields change.

| id (stays) | old name | new `display_name` | new `description` |
|---|---|---|---|
| `iron_sword` | Iron Sword | Bronze Sword | A plain, serviceable blade of recast bell-bronze, worn to a working shine. |
| `rusty_claymore` | Rusty Claymore | Verdigris Greatblade | A heavy two-handed blade of old salvage bronze, green-pitted to the tang but still dangerous. |
| `iron_helm` | Iron Helm | Chitin Helm | A heavy helm of oiled offcut chitin, wright-lashed, nasal guard and all. |
| `hunting_bow` | Hunting Bow | Chitin-Lath Bow | A sprung bow of chitin laths, made for taking small game along the terrace rims. |
| `leather_cuirass` | Leather Cuirass | Hound-Hide Jack | Oil-dark scar-hound hide, worked light and quiet. The coat swallows lamplight, on or off the hound. |
| `wooden_shield` | Wooden Shield | Chitin Roundshield | A round shield of oiled offcut plate, wright-lashed at the rim. Regard slides off shell — so, folk say, does a blow. |
| `healing_draught` | Healing Draught | *(kept — "draught" is canon vocabulary)* | A salter's brine-bitter tonic from the stores shelf. It knits wounds closed. |
| `flawed_gem` | Flawed Gem | Flawed Lens | A lava-glass lens gone cloudy in the working. A mirror-wright might still pay for it. |
| `sack_of_ore` | Sack of Ore | Sack of Bronze Scrap | A rope-stitched sack of broken bell-bronze salvage, bound for the recasters. Back-breakingly heavy. |
| `mana_draught` | Mana Draught | *(untouched — the carve-out)* | *(untouched)* |

Already canon-voiced, untouched: `rope_ring`, `scrimshaw_token`, `reciters_staff`, `tally_log_copy`, `rat_pelt`, `hound_fang`.

Canon grounding (packet citations): bell-bronze [bible, first_bells] · offcut plate, wright-lashing [chitin_wrights] · chitin-plated posts and "regard slides off shell" (folk-certain, unproven — the shield line says "folk say") [wardens, the_workings] · terrace-rim small game [vault_rat] · oil-dark coats that swallow lamplight [scar_hound] · draughts sold from stores; salters charter under the Tide [suddel, the_workings] · lens and bead are lava-glass; mirror-wrights [the_workings] · rope-stitched sacking [rope_ring, suddel].

### Ripple check (why nothing else changes)

Shipped prose survives untouched: dialogue says "a draught from stores" and "draw a blade from the rack" (material unnamed); the journal says "a healing draught" (name kept). All UI (inventory rows, container panel, HUD prompts, dialogue exchange notices) reads `display_name` live from the resource — zero wiring changes. Loot tables, scenes, and saves reference items by id — untouched by construction.

## Architecture

**New files: none.** Content mini-spec.

**Modified:** `data/items/{iron_sword,rusty_claymore,iron_helm,hunting_bow,leather_cuirass,wooden_shield,healing_draught,flawed_gem,sack_of_ore}.tres` · `tests/scenes/test_inventory_panel.gd` (display-name literals; preload consts keep their id-derived names) · `docs/lore/bible.md` (one Technology sentence, director-ratified) · `docs/master-plan.md` · `CLAUDE.md`.

**BalanceConfig additions: none.**

## Acceptance criteria (GUT tests)

1. **Data validation (existing suite, unchanged):** `tests/data/test_item_defs.gd` stays green as-is — 16 items, ids unique and equal to filename stems, stats untouched. The id-stability constraint is enforced by the existing id==filename assertion; no new validator.
2. **Scene (updated literals):** `tests/scenes/test_inventory_panel.gd` green with "Bronze Sword", "Verdigris Greatblade", "Chitin Roundshield" — proving the panel renders the re-skinned names through the live `display_name` path.

Not validated, by design: prose quality and canon fidelity are human review (canon-packet citations above + canon-keeper-reviewer on the bible diff), not machine-checkable.

## How to implement

One commit each, full suite green before each:

1. Canon-packet pass → the nine `.tres` edits + `test_inventory_panel.gd` literals + this spec. (`content: re-skin generic gear to canon materials (spec 014)`)
2. The bible's Technology sentence, canon-keeper-reviewer pass first. (`lore: bible records gear materials (014 rulings)`)
3. Docs housekeeping — master-plan Decision Log line, status, queue row; CLAUDE.md focus. (`docs: spec 014 complete`)
