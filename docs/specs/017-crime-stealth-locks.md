# Spec 017 — Crime, Stealth & Locks v1

**Status:** ready to implement
**Depends on:** 002 (`Inventory`/`ItemStack`/`ItemDef` — the `stolen` flag lands on `ItemStack`, `owner_faction` on `Inventory`; `MiscDef` is the lockpick's type; `base_value` prices the bounty), 003 (`Interactable`/`WorldItem` pickup + the container/door interact paths the acquire choke wraps), 004 (`creature.gd`'s `_can_aggro`/`_has_line_of_sight` — the detection/LOS logic the witness primitive generalizes; `LOS_MASK`), 005 (`DialogueResponse` effects + `DialoguePanel` — the `pay_fine` effect joins `give_gold`/`opens_barter`), 007 (`SaveCodec` — this spec bumps it to v4 with its third migration; the inventory codec extends for `stolen`), 012 (`ContainerPanel` — the take path the acquire choke wraps; a lock gate on `open`), 015 (`FactionStanding.adjust_reputation` — the tested-but-uncalled setter crime becomes the first live caller of; `&"wardens"` is the jurisdiction; the `SaveCodec` migration chain this spec extends), 016 (the merchant's live `Inventory` — the ownable-stock seam theft flags; `BarterRules.can_sell`/the sell guard gains the stolen refusal; `give_gold`/`opens_barter` the `pay_fine` effect mirrors; `Game.stash` the bounty-ledger wiring copies)
**Consumed by:** 018 (magic v2 — `WitnessQuery.is_witnessed` is built once here and called again for witnessed-unlicensed-working enforcement; the notice ledger is 018's, separate from this spec's bounty ledger), 019 (persuasion — a persuaded warden could narrow the fine; `pay_fine` is the seam), 020 (clock — a bounty could age; presence swaps change who witnesses), 024 (creatures — creature loot is never owned, so the acquire choke leaves it a clean pickup)

## Scope

**In:** a per-stack **`stolen` flag** (`ItemStack`) + per-inventory **`owner_faction`** (`Inventory`) — the ownership seam · a deterministic **witness primitive** (`WitnessQuery`, `scripts/crime/`) generalized from `creature.gd`'s LOS/detect logic, **built once and consumed by 018** · a **sneak stance** (a new `sneak` input — crouch → slower move + a shrunken detection radius, HUD indicator) · **lockpicking** — pure `LockRules.pick_chance` + a `lockpick` `MiscDef` consumed per attempt, gating `locked` containers/doors (a per-attempt **roll**; no minigame) · **theft → bounty**: the acquire choke routes every take of an owned item through the witness query; a witnessed take flags the stack `stolen` **and** accrues bounty on a new **`Game.bounty` ledger** (**`SAVE_VERSION` → 4** + **`_migrate_v3_to_v4`**, chain v1→v2→v3→v4) **and** docks Wardens reputation via 015's `adjust_reputation` · **stolen-flag → merchant refusal** (the barter sell guard rejects `stolen`) · **warden confrontation** — a `DialogueResponse.pay_fine` effect + Torrum's canon-packet *reckoning* (pay the fine or refuse; dialogue-only) · a `BalanceConfig` **Crime** group · a locked container + a lockpick placed for the vertical slice · full GUT coverage.

**Out (later specs / backlog):**
- **Notice ledger / overcast / unlicensed-casting enforcement** → **018**. This spec builds the witness *query*; 018 builds notice-as-spent-currency over it and applies the charter gate on the 008 tiers. **Bounty and notice are separate ledgers over one witness primitive** (Decision Log): bounty is a per-jurisdiction legal debt that clears by fine; notice never clears. Only the witness query is shared.
- **Hostile guards / NPC combat** → later. **Director ruling (2026-07-22): "resist" is a dialogue refusal in v1.** NPCs stay stationary and non-combatant (only creatures fight, per 004). A warden confronted over a bounty offers pay-or-refuse in dialogue; turning wardens into attackable combatants (aggro + AI) is a later spec.
- **Fencing / the Quiet Lines** → later. **Director ruling: blanket refusal in v1.** Every merchant refuses stolen goods; the canon laundering seam (`licensed_crews`' Quiet Lines) is a later spec. Stolen goods are dead weight until fencing ships.
- **Pickpocketing** → later. v1 theft is taking owned world/stock items, not lifting from a person's inventory.
- **Trap disarming** → later. `security` governs locks only in v1; the skill blurb names traps — a stated deferral.
- **Per-jurisdiction bounty variety** → the ledger is keyed by faction for faithfulness, but only `&"wardens"` exists (one settlement). Regional jurisdictions arrive with Phase 3 world production.

## Design

### Faithfulness rulings (director, 2026-07-22 — Morrowind as the target)

1. **Hybrid resolution — locks roll, sneak is fixed.** Lockpicking is a per-attempt probability roll (security vs lock difficulty; a pick is consumed each attempt) — the one place dice earn their keep. Sneak detection is **deterministic**: line-of-sight + range vs a security/sneak-scaled "safe" radius, no RNG. Stealth stays plain-meaning; the lock is the gamble.
2. **Warden confrontation is dialogue-only in v1** (see Out). Pay the fine or refuse; no hostile-guard combat.
3. **Any NPC witnesses.** A crime seen by *any* placed NPC within range with clear LOS is witnessed → bounty accrues to the jurisdiction (`&"wardens"`). Consequence: **`NPCDef` needs no new authority field** — it stays minimal (the 020 schedule sub-resource remains the first sanctioned `NPCDef` amendment).
4. **Blanket refusal, no fence yet** (see Out).

### Ownership & the stolen flag — the seam (`scripts/resources/`)

**`ItemStack.stolen: bool = false`** — per-stack, because `ItemDef` is a shared cached resource (a flag there would taint every copy of the item across the world). The stack-merge guard gains a `stolen` comparison: a stolen stack and a clean stack of the same item never coalesce, so a laundered/clean copy stays distinct from a hot one.

**`Inventory.owner_faction: StringName = &""`** — empty = unowned (yours to take freely). Set on:
- the merchant's live `Inventory` in `npc.gd:_build_merchant_inventory()` (the 016 seam — for-sale goods are owned by the merchant's faction);
- authorable on `WorldContainer` and `WorldItem` (a crate in a shop back-room, a purse on a shelf).

`owner_faction` on the merchant inventory is **runtime-only** (rebuilt each session — the 016 fence). The `stolen` flag **persists** (below): a stolen sword is still stolen after a reload, through drop-to-world, and in the stash.

### The witness primitive — built once, consumed by 018 (`scripts/crime/witness_query.gd`)

`WitnessQuery` (all static, tree-injected — the `FactionRules`/`BarterRules` shape), generalized from `creature.gd:_can_aggro`/`_has_line_of_sight` (lines 149–166):

- `detection_radius(sneak_skill: int, crouched: bool, config: BalanceConfig) -> float` — **pure**. Base radius shrunk by sneak skill (lerp between `sneak_skill_min`/`max` endpoints) and further multiplied by `sneak_crouch_factor` when crouched. Higher skill + crouch = a smaller radius a thief can work inside. Tested directly.
- `is_detected(observer_pos, actor_pos, sneaking, sneak_skill, config, space_state) -> bool` — distance ≤ `detection_radius` **and** clear LOS (`PhysicsRayQueryParameters3D` against `LOS_MASK`, exactly `creature.gd`'s ray). No RNG (ruling 1).
- `is_witnessed(actor: Node3D, world: Node, sneak_skill: int, sneaking: bool, config) -> bool` — iterates the `world`'s `Npc` descendants, returns `true` on the first observer within the sneak-scaled radius with a clear eye-height ray (the observer's own body — and the actor's, if it has one — excluded so only world geometry blocks, since placed NPCs sit on layer 1). **This is the one function 018 calls** for unlicensed-casting enforcement. Takes the world node → testable with a built scene (a wall + an NPC), the `creature` test precedent.

*Rejected alternative — an authority tag on `NPCDef` so only wardens witness:* ruling 3 says any NPC reports, so no schema change is needed and the query stays a plain child-iteration.

### Sneak stance (`scripts/player.gd` + `project.godot [input]`)

A new action **`sneak`** (Ctrl / C). A `sneaking: bool` toggle on the `Player`:
- feeds `get_speed_multiplier()` (the existing movement hook) a `sneak_move_factor` so crouched movement is slower;
- is passed into `is_witnessed` at every criminal act so the detection radius shrinks while crouched.

A HUD sneak indicator (a stance glyph via `hud_notice.gd`) shows the stance is active. No new movement system — a stance flag on the existing `CharacterBody3D` controller.

### Lockpicking — the roll (`scripts/crime/lock_rules.gd` pure + world nodes)

**`LockRules.pick_chance(security_skill: int, lock_difficulty: int, config) -> float`** = `clampf(1 - difficulty / (security + lock_base_competence), 0, 1)` — a lock inside your *reach* (`security + base_competence`) opens reliably (a fresh character, security 5, picks an easy difficulty-5 lock ~83%), the odds fall off fast toward your reach, and a lock **at or beyond** your reach is `0.0` — it cannot be forced without more skill. **Rebalanced from the shipped symmetric-0.5 curve after a 2026-07-22 playtest** where that curve capped a novice near 52% on *every* lock (a coin-flip on trivial locks). **Pure & tested** (monotonic in skill and difficulty, clamped; the novice-opens-easy and beyond-reach anchors); the **caller rolls** (`randf() < chance`), so pure logic stays RNG-free.

**Lock state** is scene-authored placement data (like a container's loot, not a balance number) on `WorldContainer` / `StashContainer` / `hinged_door` / `transition_door`:
`locked: bool = false`, `lock_difficulty: int = 0`, `key_id: StringName = &""` (optional — a held key opens it outright).

**The gate** in `ContainerPanel.open` / the door interact: if `locked` and the player holds no matching `key_id` —
- no `lockpick` in inventory → HUD "locked" no-op;
- else check `pick_chance`: a chance of **0** (a lock beyond your reach) refuses without spending a pick (HUD "beyond your skill"); otherwise consume one `lockpick` (a `MiscDef`, `data/items/lockpick.tres`) and roll — **success** unlocks (`locked = false`, open proceeds), **failure** reports via HUD (the pick is spent — the Morrowind cost). No minigame (the 016 no-click-gamble culture applies to the *interaction*, not the odds).

### Theft → bounty (`scripts/crime/crime_rules.gd` pure + `BountyLedger` on `Game`)

**`BountyLedger extends Resource`** (`scripts/resources/bounty_ledger.gd`) — `bounty: Dictionary[StringName, int]` keyed by jurisdiction faction, the `FactionStanding` shape: `get_bounty(id)`, `add_bounty(id, delta)`, `clear(id)`. Lives on **`Game.bounty`**, wired exactly like `stash`: built in `_ready`, reset in `start_new_game`, replaced in `_apply_load`, carried on `SaveState.bounty`.

**`CrimeRules`** (pure static, `scripts/crime/crime_rules.gd`):
- `theft_bounty(item: ItemDef, config) -> int` — `maxi(1, ceili(item.base_value * config.theft_bounty_multiplier))`.
- `fine_owed(bounty_amount: int, config) -> int` — `ceili(bounty_amount * config.fine_multiplier)` (the caller reads the raw bounty off `Game.bounty`, so `CrimeRules` stays decoupled from `BountyLedger`; v1 `fine_multiplier` = 1.0 — the fine *is* the bounty, but the seam lets a later spec price it apart).
- `reputation_dock(config) -> int` — `config.crime_reputation_dock`.
- `marks_stolen(owner_faction) -> bool` / `accrues_bounty(owner_faction, witnessed) -> bool` — the acquisition verdict, pure: any owned take is stolen; only a witnessed owned take accrues bounty.

**The acquire choke point** — `Theft.acquire(actor, taker, item, count, owner_faction)`, the one function every take routes through (`ContainerPanel` take of an owned source, `WorldItem` pickup, the `BarterPanel` Steal). Given the source `owner_faction`:
- **empty (unowned / yours):** a clean `add_item`, no crime.
- **non-empty:** the taken stack is flagged `stolen` (it isn't yours). Then `WitnessQuery.is_witnessed`:
  - **witnessed:** `Game.report_theft(JURISDICTION, theft_bounty(item), reputation_dock)` — Game raises its own bounty ledger *and* docks reputation via `FactionStanding.adjust_reputation` (**the first live caller of the 015 setter**; a no-op for a non-member) + HUD "you were seen."
  - **unwitnessed:** stolen-flagged, no bounty, no dock (you got away with it — but the goods are still hot for merchants).

`owner_faction` marks *who* owns the goods (any non-empty value — the merchant's stock is tagged with its `MerchantDef.id`); the bounty always accrues to the **jurisdiction**, a `Theft.JURISDICTION` constant pinned to `&"wardens"` — the canon enforcer of the one shipped settlement (`docs/lore/factions/wardens.md`). Per-settlement jurisdiction is Phase 3 world-production data. The **lock gate** is the sibling orchestrator `Lockpicking.try_open(locked, difficulty, key_id, actor)`, called by each container/door interact handler before it opens: a held key opens free, else one `lockpick` is spent and `LockRules.pick_chance` is rolled.

**Merchant-stock grab** — honor 016's "grab path": a minimal **Steal** action on the barter panel's merchant (owned) side routes through the *same* acquire choke point, so stealing the on-offer goods and looting an owned crate share one code path.

### Stolen-flag → merchant refusal (`scripts/economy/` + `barter_panel.gd`)

The barter **sell** guard rejects any `stolen` stack — blanket refusal (ruling 4). The sell list omits stolen stacks (they never appear as sellable); any direct-call bypass is a silent no-op (the 012 authority-is-the-component precedent). Buying is unaffected — you can still buy clean goods. `BarterRules` gains a small `is_sellable(stack, merchant) -> bool` that ANDs `can_sell(stack.item, merchant)` with `not stack.stolen`, keeping the rule pure and testable.

### Warden confrontation (dialogue, canon-packet)

**`DialogueResponse.pay_fine: bool = false`** — an effect mirroring `give_gold`/`opens_barter`. On a spoken response, `_apply_effects` computes `fine_owed(Game.bounty, &"wardens")`; if player gold ≥ fine, `spend_gold(fine)` + `Game.bounty.clear(&"wardens")` + a HUD notice; else a shortfall notice (no-op). The reckoning topic is gated by a new **`DialogueResponse.requires_bounty: bool` condition** (**playtest amendment, 2026-07-22**): the pure `DialogueEvaluator` gains a trailing `bounty: int = 0` param the `DialoguePanel` fills from `Game.bounty` (the same narrow, sanctioned read as `_settle_fine`), and the reckoning prompt sets `requires_bounty = true` — so the topic surfaces in Torrum's list **only while a fine is owed**, never as an empty "you owe nothing" option. The evaluator stays pure (the bounty is injected, never read ambiently). *(This lifts the plan's original "always-present topic" v1 simplification — the director rejected showing the option with no bounty.)*

**Content:** Torrum (Gate-captain of Lastdoor's warden post — canon "practical enforcer," `data/npcs/torrum.tres`, placed in `scenes/world/lastdoor_warden_post.tscn`) gets a canon-packet **reckoning** exchange: pay the fine or don't. Currency framed as **beads** in prose (canon `the_shares`; the UI "Gold" label + `give_gold`/`spend_gold` field names keep the backlogged currency carve-out — the 014/016 precedent). Canon grounded in `wardens.md` (canon: *license, patrol, witness, gate law*) and `the_shares.md` (*"theft is intimate"*). `canon-keeper-reviewer` runs before the content commit.

### `BalanceConfig` Crime group (`scripts/resources/balance_config.gd` + `.tres`)

A new `@export_group("Crime")`, both the `.gd` `@export` and `balance_config.tres` updated together (validated by `tests/data/test_balance_config.gd`):

| field | representative | role |
|---|---|---|
| `sneak_base_detection_radius` | 12.0 | the unmodified observer sight range (m) |
| `sneak_crouch_factor` | 0.5 | radius multiplier while crouched |
| `sneak_skill_min` / `sneak_skill_max` | 5 / 100 | radius-scaling skill endpoints |
| `sneak_skilled_radius_factor` | 0.3 | radius multiplier at `sneak_skill_max` |
| `sneak_move_factor` | 0.5 | move-speed multiplier while crouched |
| `lock_base_competence` | 25 | the skill floor a novice brings to a lock (the pick-chance denominator) |
| `theft_bounty_multiplier` | 1.0 | bounty per stolen `base_value` |
| `fine_multiplier` | 1.0 | fine per bounty (the 019 seam) |
| `crime_reputation_dock` | 5 | reputation lost per witnessed theft |

No hardcoded values in scripts (the Golden Rule) — every number above is read from the config.

### Save & migration — SAVE_VERSION → 4 (`scripts/systems/save_codec.gd`)

- `const SAVE_VERSION := 4`; `"bounty"` added to `_ROOT_KEYS`; `bounty_to_dict`/`bounty_from_dict` (the `factions` codec shape — a `StringName→int` map through `_strings_to_id_ints`).
- `Game.bounty` carried on `SaveState.bounty`, encode/decode alongside `factions`/`stash`.
- `_migrate_v3_to_v4(data)` seeds an empty bounty dict + stamps `save_version = 4`; `_migrated` chains `v1→v2→v3→v4` (a v1 save now seeds factions, then stash, then bounty).
- **Inventory codec extended for `stolen`:** `inventory_to_dict` writes `stolen` per stack, `_from_dict` reads it (defaulting false when absent — so v1–v3 stashes/inventories decode clean). Affects the `inventory` and `stash` sections uniformly.
- The four `SAVE_VERSION`-guard tests flip `3 → 4` (the intended tripwires): `test_save_codec`, `test_save_load`, `test_player_casting`, `test_title_screen`.

### Ripple check (why little else changes)

Additive throughout. `stolen` defaults false and merges are guarded, so every existing stack is unchanged; `owner_faction` defaults empty, so every existing inventory/container/`WorldItem` take stays a clean pickup (the acquire choke is a no-op for unowned sources). `locked` defaults false, so every existing container/door opens as before. No shipped `DialogueResponse` sets `pay_fine`. The only save-payload growth is one additive `bounty` section + an optional `stolen` field that older saves decode as false; v1/v2/v3 saves migrate rather than break. `FactionStanding.adjust_reputation` was shipped-and-tested in 015 for exactly this caller.

## Architecture

| new file | role |
|---|---|
| `scripts/resources/bounty_ledger.gd` | `BountyLedger extends Resource` — per-jurisdiction bounty ints |
| `scripts/crime/witness_query.gd` | `WitnessQuery` — deterministic detection + LOS over NPCs (018 reuses `is_witnessed`) |
| `scripts/crime/lock_rules.gd` | `LockRules` — pure pick-chance curve |
| `scripts/crime/crime_rules.gd` | `CrimeRules` — pure theft-bounty / fine / reputation-dock math + the stolen/bounty verdict |
| `scripts/crime/theft.gd` | `Theft` — the acquire choke: ties CrimeRules + WitnessQuery to the live game (flags stolen, calls `Game.report_theft`) |
| `scripts/crime/lockpicking.gd` | `Lockpicking` — the lock gate: key/pick check + the `LockRules` roll, spends a pick |
| `data/items/lockpick.tres` | a `MiscDef`, consumed per lockpick attempt |
| `tests/scenes/test_witness_query.gd` | `detection_radius` scaling + `is_witnessed` (built scene, LOS) |
| `tests/unit/test_lock_rules.gd` | pick-chance curve — monotonic, clamped, endpoint determinism |
| `tests/unit/test_crime_rules.gd` | bounty/fine/dock math + the acquire outcomes |
| `tests/scenes/test_theft.gd` | witnessed vs unwitnessed take → stolen flag + bounty |
| `tests/scenes/test_lockpicking.gd` | locked gate: no pick, key bypass, roll success/fail consumes a pick |

Bounty save coverage folds into the existing save suites rather than a new file: the codec round-trip + v3→v4 migration land in `test_save_codec.gd`, and the Game-level bounty/stolen round-trip in `test_save_load.gd`.

**Modified:** `scripts/resources/item_stack.gd` (`stolen` + merge guard) · `scripts/resources/inventory.gd` (`owner_faction`) · `scripts/player.gd` (`sneak` stance) + `project.godot` (`sneak` action) · the acquire choke wired into `scripts/ui/container_panel.gd`, `scripts/world/world_item.gd`, `scripts/ui/barter_panel.gd` (Steal) · `scripts/world/{world_container,stash_container,hinged_door,transition_door}.gd` (lock fields + gate) · `scripts/economy/barter_rules.gd` (`is_sellable`) + `scripts/ui/barter_panel.gd` (stolen omitted) · `scripts/world/npc.gd` (`owner_faction` on the merchant inventory) · `scripts/resources/dialogue_response.gd` (`pay_fine`) + `scripts/ui/dialogue_panel.gd` (`_apply_effects`) · `scripts/systems/game.gd` (`bounty` + save wiring) · `scripts/systems/save_codec.gd` (v4 + `bounty` section + `_migrate_v3_to_v4` + chain + `stolen` in the inventory codec) + `SaveState` · `scripts/resources/balance_config.gd` + `data/balance/balance_config.tres` (Crime group) · `scripts/ui/hud_notice.gd` (crime strings + sneak glyph) · Torrum trade dialogue (canon-packet) + a locked container/lockpick placement · `tests/unit/test_save_codec.gd` · `tests/scenes/test_save_load.gd` · `tests/scenes/test_player_casting.gd` · `tests/scenes/test_title_screen.gd` (3 → 4) · `tests/data/test_balance_config.gd` · `tests/data/test_item_defs.gd` (count) · `docs/master-plan.md` · `CLAUDE.md`.

## Acceptance criteria (GUT tests)

1. **Lock odds** (`test_lock_rules.gd`): `pick_chance` is monotonic non-decreasing in `security_skill`, non-increasing in `lock_difficulty`, clamped `[0,1]`; a trivial lock (difficulty 0) is 1.0, a novice reliably (> 0.75) opens an easy lock, a lock at/beyond reach is 0.0, and more skill lifts the odds on a fixed lock.
2. **Witness** (`test_witness_query.gd`): `detection_radius` shrinks as `sneak_skill` rises and again when `crouched`; `is_witnessed` is true for an NPC in range with clear LOS, false when a wall blocks the ray (`LOS_MASK`) or the observer is beyond the radius; a crouched skilled actor is unseen where an upright novice is seen.
3. **Crime math + verdict** (`test_crime_rules.gd`): `theft_bounty` = `base_value * multiplier` clamped ≥ 1; `fine_owed` scales a raw bounty by `fine_multiplier`; `marks_stolen` is false for an empty owner and true for any owner; `accrues_bounty` is true only for an owned take that was witnessed; `reputation_dock` reads the config.
4. **Theft** (`test_theft.gd`): taking an owned stack with a witness present flags it `stolen`, raises `Game.bounty` by the item's bounty, and docks Wardens reputation; taking the same stack unseen flags it `stolen` with no bounty and no dock; taking an unowned stack does neither.
5. **Lockpicking** (`test_lockpicking.gd`): a `locked` container with no pick and no key stays closed (no-op); a held `key_id` opens it without consuming a pick; a pick attempt consumes exactly one `lockpick`; at a difficulty far below skill it opens, far above it stays locked (both consume the pick).
6. **Stolen refusal** (a barter test): `is_sellable` is false for a `stolen` stack and true for a clean one; the sell list omits stolen stacks; a forced sell of a stolen stack is a no-op.
7. **Bounty + save** (`test_bounty_save.gd` + `test_save_codec.gd` + `test_save_load.gd`): a save/load round-trip preserves `Game.bounty` and per-stack `stolen` flags and the file carries `"save_version": 4`; a **v3 payload (no `bounty`)** decodes to a v4 `SaveState` with an empty ledger; a **v1 payload** chains v1→v2→v3→v4 (factions, stash, bounty all seeded); a `SAVE_VERSION + 1` payload is still refused; `pay_fine` with sufficient gold clears the ledger and spends exactly the fine.

Not machine-validated (human / canon-keeper review): sneak/lock/bounty balance tuning, the Torrum reckoning prose under the plain-meaning anchor + beads framing, the acquire choke's feel in play.

## How to implement

One commit each, full suite green (530 →) before each:

1. This spec + master-plan status/queue note. (`docs: spec 017 begins — the law arrives at Lastdoor`)
2. `BalanceConfig` Crime group + `LockRules` + `data/items/lockpick.tres` (`MiscDef`) + `test_lock_rules` + item-defs count bump (criterion 1). (`crime: lock-pick odds + the Crime tunables`)
3. `ItemStack.stolen` (+ merge guard) + `Inventory.owner_faction` + inventory codec carries `stolen` + `CrimeRules` + `test_crime_rules` (criterion 3). (`crime: ownership + the stolen flag`)
4. `WitnessQuery` + `test_witness_query` (built scene) + `sneak` input/stance + speed/detection hook + HUD indicator (criterion 2). (`crime: the witness primitive + sneak stance`)
5. `BountyLedger` on `Game` + `SaveCodec` v4 + `_migrate_v3_to_v4` + chain; flip the four SAVE_VERSION guards; `test_bounty_save` (criterion 7 save half). (`save: SAVE_VERSION 4 — the bounty ledger + v3→v4`)
6. The acquire choke wired through take paths + merchant Steal; lock gates on containers/doors; `is_sellable` stolen refusal; `test_theft` + `test_lockpicking` + the barter stolen test (criteria 4, 5, 6). (`crime: theft, locks, and stolen-goods refusal`)
7. Canon-packet pass → `pay_fine` effect + Torrum's reckoning dialogue + a locked container/lockpick placement; `canon-keeper-reviewer` first (criterion 7 fine half). (`content: the warden's reckoning — pay the fine or don't`)
8. Docs housekeeping — master-plan Decision Log rows + status + §4 row → complete; CLAUDE.md focus. (`docs: spec 017 complete`)
