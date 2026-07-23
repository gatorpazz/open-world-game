# CLAUDE.md — open-world-game

Solo-developed open-world RPG inspired by Morrowind's *design* (original IP — no Bethesda names, lore, or assets, ever). Godot 4.x, GDScript. One human director + AI agents. Optimize for small, reviewable, tested changes.

## Commands

```bash
# Run the game (adjust binary name/path to this machine)
godot .

# Run all tests (GUT addon)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Reimport assets after adding files outside the editor
godot --headless --import
```

## The Golden Rule: content is data, code is systems

- All game content — items, skills, NPCs, spells, quests, dialogue, loot tables, balance numbers — lives in custom `Resource` files (`.tres`) under `data/`. Scripts define *behavior*, never *content*.
- No hardcoded game values in scripts. Tunable numbers belong in `data/balance/balance_config.tres`.
- Every new content type gets: a `class_name` Resource definition in `scripts/resources/`, a folder under `data/`, and a validation test in `tests/data/` that loads every file of that type and checks it (unique ids, required fields, valid references).

## Code conventions

- GDScript with **static typing everywhere**: typed vars, typed function signatures, typed arrays (`Array[SkillDef]`). `-> void` on functions that return nothing.
- `class_name` on every reusable script. PascalCase for classes/nodes, snake_case for files, folders, functions, and variables. `StringName` for ids.
- Godot reserves many generic nouns as built-in classes; check for collisions before declaring `class_name`, and prefer domain-prefixed names (`World*`, `Game*`) for generic English words.
- Signals up, calls down: children never reach up the tree; they emit signals. Parents call down.
- Autoloads are a last resort. Ask before adding one. The one sanctioned autoload is `Game` (persistent identity + scene changes): `Game` mutates its own state; everything else receives resource references at spawn or calls `change_scene`. Never read `Game.character_sheet` ambiently from random scripts.
- Prefer composition (small component nodes) over inheritance.
- Pure logic lives in Resources/RefCounted classes so it is testable without a scene tree; Nodes are thin wrappers that own state and emit signals.

## Folder layout

```
scenes/        # .tscn files (scenes/debug/ for test scenes)
scripts/       # systems and components (scripts/resources/ for Resource defs)
data/          # .tres content files (skills/, items/, balance/, ...)
assets/        # models, textures, audio (assets/LICENSES.md is mandatory)
tests/         # GUT tests (tests/data/ for content validators)
docs/specs/    # numbered feature specs — implement these as written
docs/lore/     # canon lore vault — validated markdown entries (spec 011)
docs/research/ # commissioned research docs; not shipped
addons/        # third-party only; never hand-edit
```

## Testing

- Every system gets GUT tests written alongside it, not after. Test pure logic directly; use the debug scenes for manual verification.
- All tests must pass before a commit. Run the test command above and show the output.

## Git

- Small, focused commits. Message format: `area: what changed` (e.g., `stats: add skill xp progression`).
- Never commit `.godot/`. Never force-push.

## Asset licensing

Any asset entering `assets/` gets a line in `assets/LICENSES.md` in the same commit: filename, source URL, license, author. No exceptions — this file is what lets us ship commercially.

## Lore & canon

- World canon lives in `docs/lore/` (spec 011): one markdown entry per fact-bearing thing, strict frontmatter, `[[id]]` wikilinks, validated by `tests/lore/` in the normal test run.
- Statuses: draft → reviewed → canon (→ deprecated). **Only the director ratifies `status: canon`** — agents never promote.
- No silent invention: a fact the vault doesn't hold becomes a stub entry or an Open questions line, never improvised prose.
- Run the `canon-packet` skill before writing any player-facing text (dialogue, journal, quests) and write only from cited facts.
- Factions in `docs/lore/factions/` are prose canon only; faction game-data types stay fenced to a Phase 2 spec.

## Agent guardrails

- Don't install addons, delete files, or refactor code unrelated to the task without asking first.
- If a spec in `docs/specs/` conflicts with something in the code, flag it instead of silently choosing.
- When a task is ambiguous, ask one clarifying question rather than guessing at game design decisions — design authority stays with the human.

## Current focus

**Phase 1 is complete** (2026-07-22): specs 001–012 all shipped; the director's exit playthrough and the lore-audit closed spec 010. The slice: Lastdoor + six world scenes, 11 canon-voiced NPCs, four quests (two branching chains), three joinable guilds, the opening waking in the bait square. 444 tests green. **Phase 2 is planned** (2026-07-22): a thirteen-spec queue (013–025) in five waves lives in `docs/master-plan.md` §4, with the planning rulings in the Decision Log — numeric faction reputation on `Game` (015 brings `SAVE_VERSION` → 2 + the first migration), license teeth split across 015 (charter state) and 018 (notice/overcast/enforcement), bounty and notice as separate ledgers over one witness primitive built in 017, deposit as one sanctioned player stash (016), presence-lite schedules (020), re-skin keeps item ids (014), no dynamic crafted items in Phase 2 (022/023). **Spec 013 is complete** (2026-07-22): dialogue choice prompts — `DialogueChoice` sub-resources on `DialogueResponse` (`choices` renders player-voiced reply buttons in `DialoguePanel`; `choice_gated` hides commits from topic/keyword clicks, eligible only via `from_choice` in the pure evaluator), non-modal (navigating lapses a prompt; it re-presents on re-ask since prompts mutate nothing), same-topic commits sit immediately before their prompt, and both shipped decision points are retrofitted (the refusal at the square; expose-vs-absolve). 005 amended inline. **Spec 014 is complete** (2026-07-22): the material re-skin pass — nine generic items re-surfaced to canon materials (bronze blades from bell-salvage, wright-offcut chitin plate/lath, hound-hide, lava-glass lens) with ids/filenames/stats byte-stable; the four material rulings and the mana-term carve-out (backlogged; audit debt 1 stays open by that sliver) are Decision Log rows; the bible's Technology line records the gear stocks. 461 tests green. **Spec 015 is complete** (2026-07-22): the faction system — `FactionDef` + `FactionRank` sub-resources with three canon-grounded guild defs in `data/factions/`, a `FactionStanding` numeric layer (per-faction reputation + rank) on `Game` reconciled from the journal at every scene entry, pure `FactionRules` (`reconcile` / `can_advance` / `is_chartered_under` / `blocks_joining`) in `scripts/factions/`, and the save system's first `SAVE_VERSION` bump (→ 2) + first migration (v1→v2 seeds records from `joined_*` via the same `reconcile`). Additive — the journal stays the dialogue gate; all three guild joins retrofit to 013 choice prompts (`the_reading` added by director ruling); `game_ids` bridges wired to the faction lore. Director rulings: additive membership, independent mechanism-ready exclusivity (empty `rivals`), charter derived from rank, system + join-retrofit only (promotion conversations deferred). 495 tests green. **Spec 016 is complete** (2026-07-22): barter economy v1 — `MerchantDef` (stock/purse/`buys`-categories/regional `price_multiplier` hook) + `MerchantLibrary` + pure `BarterRules` (buy>sell spread, category gating, an inert `persuasion_factor` for 019) with a `BalanceConfig` Economy group; a two-sided `BarterPanel` opened off dialogue via a `DialogueResponse.opens_barter` effect signalled up to the `Npc`, which builds a live merchant `Inventory` (gold = purse) rebuilt each scene entry (runtime-only — the fence holds; the ownable-stock seam 017 flags for shop theft, theft itself staying in 017); `give_gold` rewards; drop-to-world spawning a non-persistent `WorldItem` (closes 012's encumbered-no-drop debt); and the `Game.stash` player bank taking the **second `SAVE_VERSION` bump (→ 3)** + `_migrate_v2_to_v3` (migrations now chain v1→v2→v3), reached at a Lastdoor `StashContainer` chest via a deposit-capable `ContainerPanel`. Director rulings: Morrowind-faithful reset-each-session merchant gold/stock, category-specialized buying, physical-ownable stock as the 017 theft seam (theft in 017), `persuasion` as the inert price lever, haggling rejected. Content: Suddel + Tansy trade via a canon-packet `trade` topic; canon currency is **the bead** (`the_shares`) — prose corrected from "coin" on canon-keeper review, with the UI "Gold" label + `give_gold` field currency sweep backlogged (the 014 mana-term carve-out precedent). 530 tests green. **Spec 017 is complete** (2026-07-22): crime, stealth & locks v1 — a per-stack `ItemStack.stolen` flag + per-inventory `owner_faction` seam; the deterministic **witness primitive `WitnessQuery`** (generalized from `creature.gd`'s LOS/detect — `is_witnessed` built once, reused by 018); a `sneak` crouch stance (slower + smaller detection radius); **lockpicking** — pure `LockRules.pick_chance` rolled by the `Lockpicking` gate, spending a `lockpick` `MiscDef`, on `locked` containers/doors; the **acquire choke `Theft.acquire`** through every take of an owned source (world pickup, owned container, the barter Steal button) — flags stolen and, if witnessed, calls `Game.report_theft` (bounty + the first live `FactionStanding.adjust_reputation` dock); **stolen-goods refusal** via `BarterRules.is_sellable` (blanket, no fence); **`Game.bounty` (`BountyLedger`) — the third `SAVE_VERSION` bump (→ 4)** + `_migrate_v3_to_v4` (chain v1→v2→v3→v4). Content: Torrum's canon-packet **reckoning** (`DialogueResponse.pay_fine` — settle in beads or leave it, dialogue-only) + a locked warden-owned locker & a free lockpick in the warden post. Director rulings: hybrid resolution (locks roll, sneak fixed), dialogue-only confrontation, any-NPC witnesses, blanket stolen refusal; bounty accrues to the jurisdiction (`Theft.JURISDICTION = &"wardens"`; per-settlement is Phase 3). Pure logic in `scripts/crime/`; `Game.bounty`/`Game.report_theft` are the sanctioned Game touches (the stash precedent). 568 tests green. **Spec 018 is complete** (2026-07-23): magic v2 — the license teeth, **closing audit debt 2**. `SpellDef.license_order` names the aspect order that charters a working (empty = hearth-charm, free); an above-hearth-charm working cast without that charter is **unlicensed** → draws **notice** on `Game.notice` (`NoticeLedger`, never-clearing — no `clear()`; the **third `SAVE_VERSION` bump → 5** + `_migrate_v4_to_v5`). Past `overcast_threshold` = **overcast** (permanently remarkable: always exposed to the witness query, a one-time rep dock on crossing, a HUD beacon). Mirrors 017: pure `WorkingRules` (`scripts/magic/`) + a `Working` orchestrator off a `PlayerCasting.working_cast` signal (signals-up); `Game.report_working`/`report_overcast` keep the mutation on Game; **`WitnessQuery` (017) is consumed** — a witnessed unlicensed working draws notice **and** a warden bounty (settled at Torrum's reckoning). Charter is a **soft notice-gate** (never a cast-lock); no aspect-order `FactionDef` exists, so the charterless outsider's higher magic is always unlicensed (Phase 3 adds order factions). Director rulings: notice from unlicensed casting only, overcast = permanently remarkable, soft notice-gate, witnessed working draws both ledgers. 588 tests green. **Spec 022 is complete** (2026-07-23): alchemy — brewing fixed recipes. New `IngredientDef` (canon materials + an ordered `effects` list for inspection) + `RecipeDef` (exact ingredients → an existing `ConsumableDef` + base yield + alchemy `min_skill`) + `RecipeLibrary`; pure `AlchemyRules` (`known_recipes` derived from skill, never stored — the `filter_castable` analog; `can_brew`; `brew_yield` scales with skill; `discovered_effects` reveals effects progressively). A `BrewingPanel` (barter lifecycle) opened by a new `brew` input **gated on the carried Simpler's Kit** (`AlchemyRules.APPARATUS_ID`); brewing consumes inputs → grants the skill-scaled yield + `alchemy` xp through the `InventoryComponent`. Director rulings: fixed recipes + ingredient inspection (effects are flavor, not a brewing input), a carried apparatus, yield scales with skill. Free domestic craft — **not** notice-gated (018); **no new skill** (`alchemy` shipped in 001) and **no `SAVE_VERSION` bump** (recipes/discovery derived; ingredients/kit/outputs are items). Content: 3 canon ingredients (terrace fungus, salter's brine, lava-glass grit) + the kit + 2 recipes into the draughts; canon-keeper swapped hush-moth dust (a regard *detector*, not a holder) for lava-glass grit and logged the new facts as Open-questions lines. 605 tests green. Next: **Wave 4 — 019 (persuasion) ∥ 020 (clock) ∥ 021 (fast-travel)**; later spec stubs are written just-in-time per wave. The plain-meaning anchor rule now lives in the bible's Content grammar — all future dialogue inherits it. The vault stands at 62 entries (19 canon, 42 reviewed, 1 draft). Spec 012 is complete: the inventory panel — `InventoryPanel` on the journal-panel lifecycle (I opens, pauses, same key closes), carried stacks then `[E]` equipment rows via an explicit row model (equipped items are NOT in `stacks`), a context-sensitive Use/Equip/Unequip action over the existing `InventoryComponent` API (zero new inventory logic), gold/weight/AR footer, signal-driven refresh; drop/deposit stay out until Phase 2 barter. Spec 009 is complete: character creation — the title screen (`scenes/ui/title_screen.tscn`) is `main_scene` (New Game / Continue / Quit; boot stays inert because it has no spawn marker), the creation form picks exactly 5 majors + one favored attribute (`attribute_favored_start`) with a live derived-stats preview, and `Game.start_new_game` is the commit point. No new `Game` state, `SAVE_VERSION` still 1; F6 debug scenes ride the untouched default-sheet fallback. Spec 008 (magic v1) is complete: `SpellDef`/`SpellLibrary` + `PlayerCasting` (RMB cast, R cycle), skill-gated by the licensing tiers, bolts through `HurtBox` + the 004 pipeline, ward pool + mana regen in `PlayerCombat`, HUD mana/ward bars + `HudSpell`; spell text is canon-packet authored and the aspect↔school ruling lives in `the_workings`. Any new `Game` field must join the save payload and bump `SAVE_VERSION`. All Phase 1 specs (001–012) are complete.
