# Spec 004 — Combat v1 (Melee, Stamina, Basic Enemy AI)

**Status:** ready to implement
**Depends on:** 001 (skills/attributes, use-based xp, StatsComponent deltas), 002 (WeaponDef/ArmorDef, equipment, `get_equipped_weapon` / `get_total_armor_rating`), 003 (Game autoload, WorldContainer, HUD layer)
**Consumed by:** 007 (save/load replaces the death-reload caveat), 008 (magic reuses HurtBox and the defense pipeline), 010 (village content places creatures), Phase 2 (creature variety, factions)

## Scope

**In:** melee attacks with physical hit detection, stamina costs and passive stamina regen, damage/armor/passive-block formulas in a pure-logic class, use-based skill xp hooks (weapon skill, block, armor skills), a `CreatureDef` content type with 3 hand-authored melee creatures, creature AI state machine (idle/wander → detect → chase → attack → die), hand-authored loot drops via `WorldContainer` reuse, player death overlay + scene reload through `Game`, HUD health/stamina bars, debug scene, tests.

**Out (later specs / backlog):** active blocking input · ranged combat (the hunting_bow cannot attack in v1 — attack is a no-op with it equipped) · unarmed combat (no hand-to-hand skill exists; no weapon = no attack) · dice-roll to-hit (**rejected permanently**: a geometrically connecting swing always hits; skill scales damage) · fleeing, ranged, or faction AI · navmesh pathfinding (straight-line pursuit only) · attack animations and wind-up timing · enemy health bars, damage numbers · creature respawning · sneak-attack multipliers · durability · player-xp-for-kills (progression stays use-based per 001).

## Design

### Attack input & hit detection

- New input action `attack` (default **LMB**, gamepad right trigger), added in project settings like `interact` in 003.
- **Immediate-hit model:** on `attack`, if the swing cooldown has elapsed, the swing resolves *that frame* — a `ShapeCast3D` sphere (radius `melee_sweep_radius`) cast forward from the player camera up to `weapon.reach` meters. No wind-up; animations don't exist yet. The next swing is gated by `weapon.swing_time` seconds.
- The cast masks world geometry **and** hurtboxes; the *nearest* hit wins. Nearest hit is a wall → the swing whiffs (walls block attacks). Nearest is a `HurtBox` → exactly one target takes the hit — multi-hit per swing is impossible by construction (cleave is backlog).
- Attacking requires a melee weapon: `get_equipped_weapon()` non-null and `skill_id != &"ranged"`. Otherwise the input is a no-op.
- **Named physics layers** (project settings): 1 world (current default), 2 player, 3 creatures, 4 hurtboxes. The melee sweep masks 1 + 4.
- **Creature attacks are deliberately coarser:** in the ATTACK state, when the player is within `attack_reach` and the creature's cooldown is ready, it calls the player HurtBox directly (distance check, no shapecast — it is already chasing its target).

### Damage model

All formulas live in pure `CombatMath`; every constant comes from `BalanceConfig` (see table below). Attacker side:

```
raw = weapon.damage
    × lerp(damage_skill_min, damage_skill_max, skill / 100.0)     # skill = level in weapon.skill_id
    × (damage_strength_base + strength × damage_per_strength)
    × (exhausted_damage_multiplier if stamina < swing cost else 1.0)
```

Creatures deal flat `CreatureDef.damage` — no sheet, no scaling (see *Creatures are not characters* below). Defender side, block first, then armor:

```
block_chance = clamp(block_chance_base + block_skill × block_chance_per_skill, 0, 1)
after_block  = raw × block_damage_multiplier    # only if a shield is equipped AND roll < block_chance
final        = after_block × (1.0 − AR / (AR + armor_mitigation_scale))
```

- **Passive block** is player-only in v1 (creatures have no equipment). A shield is any `ArmorDef` in `off_hand` (only shields can occupy it, per 002's slot rules). No block input — the roll happens on every incoming hit.
- **Armor** uses the smooth ratio curve: never negative, diminishing returns, no min-damage clamp needed. Player AR from `get_total_armor_rating()`; creature AR from `CreatureDef.armor`.
- **Determinism for tests:** `CombatMath.resolve_defense(...)` takes the block roll as a parameter (`roll: float` in [0,1)); gameplay callers pass `randf()`, tests inject fixed values.
- Sanity at start (attributes 30, blades major 25): iron_sword lands `8 × 0.75 × 0.8 = 4.8`; a full starter kit (~AR 15) turns a 10-damage hit into ~7.7.

### Stamina

- Swing cost: `attack_stamina_base + weapon.weight × attack_stamina_per_weight` (iron_sword: 9.0), paid via `apply_stamina_delta`.
- **Empty stamina never prevents attacking** (Morrowind-ish): if current stamina < cost, the swing still happens at `exhausted_damage_multiplier` and stamina drains to 0. Binary, not a continuous fatigue curve — considered and rejected for v1.
- **New: passive stamina regen.** Nothing currently restores stamina except consumables, so combat would drain it permanently. `PlayerCombat` regenerates `stamina_regen_per_second` each physics frame. Health/mana regen stay out (potions now, mending in 008). At start: 60 max stamina → ~6 sword swings, ~7.5 s to refill.

### Skill xp hooks (player only; use-based, per 001)

| event | xp | skill |
|---|---|---|
| player's swing connects (even if later blocked/mitigated) | `xp_per_weapon_hit` | `weapon.skill_id` |
| an incoming hit is successfully blocked | `xp_per_block` | `block` |
| player takes a hit while wearing armor | `xp_per_armor_hit` | each **distinct** non-empty `skill_id` among equipped `ArmorDef`s |

Granted through `StatsComponent.gain_skill_xp`, so `skill_leveled` / `leveled_up` fire normally. Creatures never grant or receive skill xp. Pacing: at blades 25 (major start, 90 xp to level) that's 18 hits per level.

**002 amendments** to support this: `Inventory.get_equipped_shield() -> ArmorDef` and `Inventory.get_equipped_armor_skill_ids() -> Array[StringName]` (distinct, non-empty — jewelry's empty `skill_id` is excluded automatically), exposed on `InventoryComponent`, with unit tests. `WeaponDef` gains `swing_time: float = 1.0` (seconds between swings) and `reach: float = 2.0` (meters); the three weapon .tres files get values (iron_sword 0.8/2.0, rusty_claymore 1.2/2.4, hunting_bow 1.0/1.5 — unused in v1 but must validate) and `tests/data/test_item_defs.gd` checks both > 0. Reach stays ≤ `interact_range` (2.5).

### Creatures are not characters — the architectural decision

Creatures get a lightweight stat block (`CreatureDef`), not a `CharacterSheet`: flat damage, flat armor, no skills, no xp. Characters are the 001 spine; creatures are content. If a future spec needs humanoid NPCs that fight with real equipment, that's a new decision — don't grow this one silently.

`CreatureDef` (`scripts/resources/creature_def.gd` — new content type per the Golden Rule: Resource + `data/creatures/` + validator):

| field | type | meaning |
|---|---|---|
| `id` | StringName | unique |
| `display_name` / `description` | String | prompt/corpse name, flavor |
| `max_health` | float | starting hp |
| `damage` | int | flat raw melee damage |
| `armor` | int | flat AR vs incoming (default 0) |
| `attack_reach` / `attack_cooldown` | float | meters / seconds between hits |
| `move_speed` | float | chase speed; wander = × `creature_wander_speed_multiplier` |
| `detect_radius` | float | aggro range (requires line of sight) |
| `leash_radius` | float | give-up distance from home; must be ≥ `detect_radius` |
| `loot` | Array[ItemStack] | hand-authored drops (002 reuse) |

Starter creatures (plus two new misc items: `rat_pelt` wt 0.5 / val 2, `hound_fang` wt 0.3 / val 6):

| id | hp | dmg | armor | reach | cooldown | speed | detect | leash | loot |
|---|---|---|---|---|---|---|---|---|---|
| `marsh_rat` | 12 | 3 | 0 | 1.2 | 1.2 | 4.5 | 8 | 14 | rat_pelt ×1 |
| `bog_hound` | 30 | 6 | 0 | 1.5 | 1.5 | 5.5 | 12 | 20 | hound_fang ×2 |
| `barrow_thrall` | 55 | 10 | 5 | 2.0 | 2.0 | 3.0 | 10 | 18 | iron_sword ×1, flawed_gem ×1 |

### Creature scene & AI

- One generic `scenes/creatures/creature.tscn`: `Creature extends CharacterBody3D` with `@export var def: CreatureDef` — one scene, many defs (content is data). Placeholder capsule mesh; per-creature meshes later. Runtime assert `def != null` in debug builds. Children: CollisionShape3D, `HurtBox` (layer 4).
- State machine as a plain enum in `creature.gd` (a node-per-state pattern is deliberately skipped for v1): **IDLE** (dwell `creature_idle_time_min..max`) → **WANDER** (random point within `creature_wander_radius` of the home position captured at `_ready`) → **CHASE** (player within `detect_radius` AND an unobstructed raycast — no seeing through walls) → **ATTACK** (within `attack_reach`: stop, hit on `attack_cooldown`) → **DEAD**. Chase aborts and returns home beyond `leash_radius`. Movement is straight-line `move_and_slide` with gravity. *(Amendments: aggro is also suppressed while the creature is outside its leash, so a creature heading home cannot instantly re-aggro; a dead player needs no explicit AI check — the death overlay pauses the tree, which halts all creatures; and creatures acquire their target by reading `Game.player` — sanctioned for v1 since the player node is state `Game` itself spawns and owns, with tests injecting `target` directly. A physics-based detection area is the upgrade path if this ever grows beyond "the player".)*
- **Death & loot:** at hp ≤ 0 emit `died`, disable AI and collision, instantiate `world_container.tscn` at the corpse position — `display_name = "<name> Remains"`, its `Inventory` filled from `def.loot` — then `queue_free()`. Full 003 reuse: loot UX is the existing container panel. Empty-loot creatures still leave remains (consistent, and proves the pipeline). *(Amendment: the corpse spawn adds the container via `get_parent()` — a sanctioned, topology-only exception to calls-down: the creature's parent is by definition the world node that owns it, and no parent logic is invoked.)*

### Player combat, HUD, death

- `PlayerCombat extends Node` (composition, child of Player) with refs to `StatsComponent`, `InventoryComponent`, the camera `ShapeCast3D`, and the player `HurtBox`. Owns the offense (input/cooldown/stamina/sweep/weapon xp), the defense (resolves block + armor via `CombatMath` when the HurtBox reports a hit, applies `apply_health_delta`, grants block/armor xp), stamina regen, and emits `died` at 0 health.
- `HurtBox extends Area3D` — the one shared damage receiver: `take_hit(raw_damage: float, attacker: Node3D)` + signal `hit_taken`. The *owner* resolves defense (player: equipment; creature: `def.armor`) — HurtBox stays dumb. No HitBox swing-volume component in v1: the instantaneous shapecast makes it unnecessary and kills multi-hit bugs.
- `CombatMath extends RefCounted` — static, pure, config passed in; zero scene-tree dependencies, mirroring `CharacterSheet`'s testability pattern.
- **HUD bars** (`scenes/ui/hud_bars.tscn`, ugly-but-functional): health + stamina driven by `health_changed` / `stamina_changed`. Mana bar waits for 008. Combat is unplayable blind.
- **Player death:** health 0 → `died` → `death_overlay.tscn` ("You died" + Reload), `get_tree().paused = true` (overlay `process_mode = ALWAYS`), mouse released. Reload → unpause → `Game.reload_current_scene()`, a small sanctioned `Game` addition: `change_scene(current_world.scene_file_path, &"default")` (every playable scene already has a `default` marker per 003).
- **Stated caveat:** `Game.character_sheet` and `inventory` persist through death — xp and loot gained before dying are kept; current health/stamina refill because `StatsComponent._ready` re-derives them on the fresh player; world state (dead creatures, looted containers) resets with the scene, exactly as on any 003 door transition. Accepted for v1; spec 007 (save/load) owns the real answer. *(Amendment, 007: the caveat is closed — the overlay button, relabeled "Load Last Save", now calls `Game.load_game()` and falls back to `reload_current_scene()` when no save exists or the file refuses to decode. `reload_current_scene` survives as that fallback and the F6 debug path.)*

## Architecture

| file | role |
|---|---|
| `scripts/combat/combat_math.gd` | `CombatMath extends RefCounted` — all formulas, static + pure |
| `scripts/combat/hurt_box.gd` | `HurtBox extends Area3D` — `take_hit()`, `hit_taken`; layer 4 |
| `scripts/combat/player_combat.gd` | `PlayerCombat extends Node` — offense, defense, xp, regen, `died` |
| `scripts/combat/creature.gd` | `Creature extends CharacterBody3D` — AI state machine, health, death + loot |
| `scripts/resources/creature_def.gd` | `CreatureDef extends Resource` — schema above |
| `data/creatures/*.tres` | marsh_rat, bog_hound, barrow_thrall |
| `data/items/rat_pelt.tres`, `hound_fang.tres` | loot misc items |
| `scenes/creatures/creature.tscn` | generic def-driven creature |
| `scenes/ui/hud_bars.tscn`, `scenes/ui/death_overlay.tscn` | minimal UI |
| `scenes/debug/combat_debug.tscn` + `scripts/debug/combat_debug.gd` | arena below |
| `tests/data/test_creature_defs.gd` | validator |

**Modified:** `weapon_def.gd` + 3 weapon .tres · `balance_config.gd` + `.tres` · `inventory.gd` / `inventory_component.gd` (shield + armor-skill helpers) · `player.gd` / `player.tscn` (attack action, HurtBox, PlayerCombat, HUD bars) · `game.gd` (`reload_current_scene`) · `project.godot` (`attack` action, named physics layers).

`BalanceConfig` additions (groups "Combat" / "Creatures"):

| constant | default | | constant | default |
|---|---|---|---|---|
| `damage_skill_min` / `damage_skill_max` | 0.5 / 1.5 | | `block_chance_base` | 0.10 |
| `damage_strength_base` | 0.5 | | `block_chance_per_skill` | 0.003 |
| `damage_per_strength` | 0.01 | | `block_damage_multiplier` | 0.5 |
| `attack_stamina_base` | 5.0 | | `melee_sweep_radius` | 0.4 |
| `attack_stamina_per_weight` | 0.5 | | `xp_per_weapon_hit` / `xp_per_block` | 5 / 5 |
| `exhausted_damage_multiplier` | 0.5 | | `xp_per_armor_hit` | 2 |
| `stamina_regen_per_second` | 8.0 | | `creature_wander_speed_multiplier` | 0.4 |
| `armor_mitigation_scale` | 50.0 | | `creature_wander_radius` | 5.0 |
| | | | `creature_idle_time_min` / `_max` | 1.0 / 4.0 |

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Damage formulas (unit):** `attack_damage` matches the formula across several skill/strength combos; the exhausted multiplier applies exactly when stamina < swing cost; every constant sourced from `balance_config.tres` — changing a resource value changes results with no code edits.
2. **Defense (unit):** armor curve endpoints (AR 0 → full damage; AR = `armor_mitigation_scale` → half); with a shield, an injected roll below chance → blocked flag + `block_damage_multiplier` then armor, above → armor only; no shield never blocks; block chance clamps to [0, 1].
3. **Stamina & cooldown (scene):** a swing drains `attack_stamina_base + weight × per_weight`; at empty stamina attacks still land at reduced damage; regen refills at the configured rate; a second attack within `swing_time` is ignored; no weapon or the hunting_bow equipped → attack is a no-op.
4. **Hit detection (scene):** the sweep damages a creature HurtBox within `weapon.reach` exactly once per swing; beyond reach, nothing; a wall in between blocks the hit; of two creatures in line, only the nearest is hit.
5. **Skill xp (scene):** a connecting hit grants `xp_per_weapon_hit` to the weapon's skill; a blocked incoming hit grants `xp_per_block` to block; taking a hit in leather_cuirass + iron_helm grants `xp_per_armor_hit` to *both* light_armor and heavy_armor; creatures never grant or receive skill xp.
6. **Creature AI (scene):** spawns IDLE; player inside `detect_radius` with line of sight → CHASE, LOS blocked → stays passive; within `attack_reach` it hits on `attack_cooldown` through the player defense pipeline; beyond `leash_radius` it gives up and returns home.
7. **Creature death & loot (scene):** hp 0 → `died`, AI/collision stop, a WorldContainer "<name> Remains" spawns holding exactly the authored loot, lootable through the 003 panel.
8. **Player death (scene):** health 0 → overlay + pause; reload lands the player at `default` with full current health and the *same* `CharacterSheet` / `Inventory` instances — xp and loot from before death intact (the stated v1 caveat, verified). *(Amendment, 007: this is now the no-save fallback path; with a save present the button restores the save point instead — criterion 9 of 007.)*
9. **Data validation:** every `data/creatures/*.tres` loads with unique id, non-empty display_name, numeric fields > 0 (armor ≥ 0), `leash_radius ≥ detect_radius`, loot entries referencing valid ItemDefs with count > 0; every WeaponDef has `swing_time` and `reach` > 0.

## How to implement

One commit each, full suite green before each: WeaponDef fields + weapon .tres + BalanceConfig additions + validation tests → CombatMath + unit tests → Inventory shield/armor-skill helpers + tests → `attack` action + physics layers + HurtBox + PlayerCombat + player.tscn wiring + HUD bars + scene tests → CreatureDef + loot items + data + validator → creature scene/AI + death/loot + scene tests → death overlay + `Game.reload_current_scene` + tests → combat_debug scene + docs housekeeping.

**Debug scene** (`scenes/debug/combat_debug.tscn`): flat arena with a `default` spawn marker; debug script auto-grants-and-equips iron_sword + wooden_shield + leather_cuirass + iron_helm (loose rusty_claymore and hunting_bow to swap); one of each creature, spaced out; one wall section (proves LOS gating and attack-blocking); a couple of healing draughts; live label dump of stamina/cooldown, last damage dealt/taken, block events, and relevant skill levels/xp. The barrow_thrall doubles as the death-flow test.
