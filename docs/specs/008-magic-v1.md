# Spec 008 — Magic v1 (Evocation, Mending, Warding)

**Status:** ready to implement
**Depends on:** 001 (magic skills + use-based xp, mana pool + `mana_changed`, StatsComponent deltas), 004 (HurtBox, CombatMath, the defense pipeline, PlayerCombat regen loop, HUD bars), 007 (`current_mana` already persists; the no-new-Game-state rule below keeps `SAVE_VERSION` at 1), 011 (`docs/lore/rules/the_workings.md` is the design input; all player-facing text goes through the canon packet)
**Consumed by:** 010 (village content can sell/teach spells), Phase 2 (elemental damage types, regard/overcast mechanics, creature casters)

## Scope

**In:** a `SpellDef` content type + `SpellLibrary` (fourth copy of the Item/Quest/Dialogue library shape), skill-gated spell learning derived from the `CharacterSheet` (no new durable state), a `cast` input (RMB) + `cycle_spell` input (R), instant-hit evocation bolts through the existing HurtBox/defense pipeline, mending self-heal, a temporary ward absorb pool that soaks damage before health, passive mana regen, use-based xp for the three magic schools, HUD mana bar + ward bar + selected-spell label, 5 hand-authored starter spells, debug scene, tests.

**Out (later specs / backlog):** elemental damage types (damage stays one untyped float — wards soak everything) · projectile spells (immediate-hit only, the 004 precedent; dice-roll spell failure **rejected permanently** for the same reason as to-hit rolls) · touch/area/creature-targeted mending or buffs · creature casters and creature wards (player-only) · spell purchase/teaching UX (skill level is the only gate in v1) · spellmaking · concentration/channeled spells · regard/notice cost, the overcast state, licensing enforcement, levitation and the tri-key (the_workings flags these as director + later-spec territory — mechanically deferred; the tier mapping below keeps the door open) · silence/interrupt mechanics · magic resistance.

## Design

### Casting input & spell selection

- New input actions: `cast` (default **RMB**, gamepad left trigger) and `cycle_spell` (default **R**), added in project settings like `attack` in 004. Both dispatched in `player.gd _unhandled_input`; `cast` is gated on `MOUSE_MODE_CAPTURED` exactly like `attack`.
- `PlayerCasting extends Node` — a sibling of `Combat` under Player (composition; `node_paths` exports like PlayerCombat). Owns selection, gating, cast dispatch, cooldown, and xp.
- **Learning is derived, never stored:** the castable list = every `SpellDef` where `sheet.skills[spell.skill_id] >= spell.min_skill`, sorted deterministically by (skill_id, min_skill, id). Recomputed on `_ready` and on `StatsComponent.skill_leveled`. Selection is kept by id across recomputes; a spell newly entering the list emits `spell_learned` → HUD notice. **No new `Game` field; `SAVE_VERSION` stays 1.** Selection and any active ward are transient by design — on load the player re-selects and re-wards. (Stated caveat, in the 004 death-caveat tradition; acceptance criterion 8 pins it.)
- A cast resolves *that frame* if: a spell is selected, the shared casting cooldown has elapsed, and `current_mana >= mana_cost`. Insufficient mana → the cast fails *without* spending mana or starting the cooldown; `cast_failed` fires → HUD notice. Once committed, mana is always spent — a whiffed bolt still costs (the stamina-on-whiff precedent from 004).
- Cooldown: one casting timer set to the cast spell's `cast_time` (the `swing_time` analog). Independent of the melee cooldown — sword/spell weaving is allowed in v1; a shared global cooldown is backlog. Stamina plays no part in casting.

### Evocation — instant bolt

- Delivery mirrors the melee sweep: a `ShapeCast3D` (`SpellCast`, radius `spell_sweep_radius`) under the camera, mask world + hurtboxes, forward up to `spell.cast_range`. Nearest hit wins; a wall whiffs the cast; exactly one target by construction. The nearest-hit loop is extracted from `PlayerCombat` into a shared static helper (`SweepQuery`) so both components use one copy.
- Damage: `raw = spell.magnitude × lerp(magic_skill_min, magic_skill_max, skill / 100.0)` — the melee lerp shape, no attribute term in v1 (intellect already sizes the mana pool; one lever per stat). The formula lives in `CombatMath.spell_power` (CombatMath stays the one pure-formula home).
- Delivered via `HurtBox.take_hit(raw, owner)` → **creature armor applies** (creature-side `armor_mitigation`, unchanged). Spell damage is untyped and rides the exact 004 defense pipeline.

### Mending — self-heal

- Instant self-target: `stats.apply_health_delta(+CombatMath.spell_power(magnitude, mending_skill, cfg))`, clamped by StatsComponent as usual.
- Casting at full health still spends mana (the uniform committed-cast rule); xp is granted only when health was below max.

### Warding — the ward pool

- Lives in **PlayerCombat** (the defense-pipeline owner): `apply_ward(amount: float, duration: float)`, `signal ward_changed(current: float, max_value: float)`, expiry decremented in `_physics_process`. PlayerCasting calls down via an exported `combat` reference.
- Pool = `spell_power(magnitude, warding_skill, cfg)`; recast **replaces** the ward outright — pool and timer both (stacking is backlog).
- **Soak order:** block + armor resolve first (`resolve_defense` untouched), then `CombatMath.ward_absorb(final_damage, ward)` soaks before health; the remainder hits `apply_health_delta`. Ward-after-armor is deliberate: it keeps the defense pipeline untouched and makes ward points stronger on an armored character. Block/armor xp grant as today even on a fully soaked hit. Expiry → pool 0 + `ward_changed`. Player-only in v1; never persisted (it expires anyway).

### Mana regen

- One new line in the existing PlayerCombat regen loop: `mana_regen_per_second` (default 1.0) alongside stamina's 8.0. 45 max mana at start ≈ 45 s to refill — mana is the scarce pool; potions (`mana_draught` +25) stay relevant.

### Skill xp (player only; use-based, per 001)

| event | xp | skill |
|---|---|---|
| a bolt connects with a HurtBox | `xp_per_cast` | evocation |
| a mend cast while health below max | `xp_per_cast` | mending |
| a ward cast (the effect always applies) | `xp_per_cast` | warding |

Whiffed bolts and full-health mends grant nothing (the connect-to-earn precedent from 004). Granted through `StatsComponent.gain_skill_xp`, so `skill_leveled` / `leveled_up` fire normally — and `skill_leveled` is also what re-derives the castable list. Pacing at mending 5 (minor, 30 xp to level): 6 casts per level.

### Tiers & lore (the_workings)

- `min_skill` maps onto the licensing tiers of `docs/lore/rules/the_workings.md`: **0 = hearth-charm, 25 = chartered craft, 50 = ordained aspect-work**. Data uses only these three values in v1 (validator-enforced), so the progression gate *is* the lore's licensing ladder.
- The aspect↔school mapping (the Flame / the Stone / the Tide vs evocation / mending / warding) is **not fixed canon**. Display names, descriptions, and HUD notice terminology MUST be authored through the `canon-packet` skill (spec 011 protocol) before the spell content commit; this spec fixes placeholder ids and mechanics only and invents no flavor. Any dangling `[[link]]`s created get stub entries; the mapping question goes to the director, never an agent.
- Regard cost, the overcast, and levitation are Open (director + later spec).

### `SpellDef` (`scripts/resources/spell_def.gd` — new content type per the Golden Rule)

| field | type | meaning |
|---|---|---|
| `id` | StringName | unique, == filename stem |
| `display_name` / `description` | String | canon-packet authored |
| `skill_id` | StringName | magic school; must reference a `data/skills/` SkillDef with archetype `magic` (the WeaponDef.skill_id pattern) |
| `min_skill` | int | learning gate; ∈ {0, 25, 50} in v1 |
| `mana_cost` | float | spent on every committed cast |
| `magnitude` | float | damage / heal / absorb before skill scaling |
| `duration` | float | seconds; > 0 only for warding in v1, else 0 |
| `cast_range` | float | meters; > 0 only for evocation, else 0 (self-target). Named to avoid shadowing GDScript's `range()` |
| `cast_time` | float | seconds between casts (the `swing_time` analog) |

Per-spell numbers are content on the `.tres`; system tunables (scaling endpoints, regen, sweep radius, xp) live in `BalanceConfig`. Effect dispatch keys on `skill_id` in v1 (an `effect` enum is backlog if schools ever hold mixed effect types). `SpellLibrary` is byte-for-byte the ItemLibrary shape over `data/spells/`.

### Starter spells (5 — placeholder ids; names/descriptions via canon packet)

| id | school | min_skill | mana | magnitude | duration | range | cast_time |
|---|---|---|---|---|---|---|---|
| `minor_bolt` | evocation | 0 | 8 | 8 | 0 | 12 | 0.8 |
| `greater_bolt` | evocation | 50 | 22 | 20 | 0 | 15 | 1.0 |
| `minor_mend` | mending | 0 | 10 | 10 | 0 | 0 | 1.0 |
| `lesser_ward` | warding | 0 | 12 | 20 | 20 | 0 | 1.0 |
| `greater_ward` | warding | 25 | 25 | 45 | 30 | 0 | 1.2 |

Sanity at start (evocation 25 major, mending/warding 5 minor, mana 45): `minor_bolt` lands `8 × 0.75 = 6.0` (vs iron_sword's 4.8) — marsh_rat in 2 casts (16 mana), bog_hound in 5 (40 mana, nearly the pool: melee stays the stamina-cheap workhorse). `minor_mend` heals 5.5 for 10 mana (max health 65). `lesser_ward` soaks 11 (≈ 2 bog_hound hits). The two `greater_*` spells are visible-but-locked, proving the gate at both higher tiers.

### HUD

- `hud_bars.tscn`: a **Mana** ProgressBar stacked with the existing two, bound in `bind(stats)` via `mana_changed` (closing the "Mana waits for spec 008" comment), and a thin **Ward** bar (visible only when > 0) via a new `bind_ward(combat)` on `ward_changed`.
- New `scenes/ui/hud_spell.tscn` + `scripts/ui/hud_spell.gd` — a small label control (the HudPrompt pattern): shows the selected spell's `display_name`, hidden when nothing is castable; updates on `selected_spell_changed`.
- New HUD notice constants for cast-failed and spell-learned (terminology from the canon packet).

## Architecture

| file | role |
|---|---|
| `scripts/resources/spell_def.gd` | `SpellDef extends Resource` — schema above |
| `scripts/magic/spell_library.gd` | `SpellLibrary` — static lazy id→SpellDef over `data/spells/`, `reset()` |
| `scripts/magic/player_casting.gd` | `PlayerCasting extends Node` — selection, gating, cast dispatch, xp, signals |
| `scripts/combat/sweep_query.gd` | static nearest-HurtBox sweep helper (extracted from PlayerCombat) |
| `data/spells/*.tres` | the 5 starter spells |
| `scenes/ui/hud_spell.tscn` + `scripts/ui/hud_spell.gd` | selected-spell label |
| `scenes/debug/magic_debug.tscn` + `scripts/debug/magic_debug.gd` | arena below |
| `tests/data/test_spell_defs.gd` | validator |
| `tests/unit/test_spell_library.gd`, `tests/scenes/test_player_casting.gd` | suites |

**Modified:** `combat_math.gd` (`spell_power`, `ward_absorb`) · `player_combat.gd` (mana regen line, ward pool/expiry/soak, sweep helper delegation) · `balance_config.gd` + `.tres` (Magic group) · `hud_bars.gd` / `.tscn` · `player.gd` / `player.tscn` (inputs, SpellCast node, Casting node, HUD wiring) · `project.godot` (`cast`, `cycle_spell`) · `hud_notice.gd` (notice constants) · `tests/unit/test_combat_math.gd`, `tests/data/test_balance_config.gd` · docs (004 amendments, master-plan, CLAUDE.md).

`BalanceConfig` additions (group "Magic"):

| constant | default | | constant | default |
|---|---|---|---|---|
| `magic_skill_min` / `magic_skill_max` | 0.5 / 1.5 | | `mana_regen_per_second` | 1.0 |
| `spell_sweep_radius` | 0.3 | | `xp_per_cast` | 5 |

## Acceptance criteria (GUT tests — scene tests where needed)

1. **Spell math (unit):** `spell_power` matches the lerp at skill 0/25/50/100; `ward_absorb` returns `min(damage, ward)`; every constant sourced from `balance_config.tres` — a resource edit changes results with no code change.
2. **Learning gate (unit):** castable filtering (static, sheet-injected) includes exactly the spells whose school skill ≥ `min_skill`; a skill level crossing a threshold adds the spell; ordering is deterministic.
3. **Casting (scene):** a committed cast spends `mana_cost` and starts the `cast_time` cooldown; a second cast inside the cooldown is ignored; insufficient mana → no mana spent, no cooldown, `cast_failed` fired; `cycle_spell` wraps through the castable list; empty stamina never affects casting.
4. **Evocation (scene):** a bolt damages a creature HurtBox within `cast_range` exactly once, through creature armor mitigation; beyond range or behind a wall it whiffs (mana still spent); only the nearest of two targets is hit; a connecting bolt grants `xp_per_cast` to evocation, a whiff grants nothing.
5. **Mending (scene):** heals `spell_power` clamped to max health; grants xp only when cast below max health; a full-health cast still spends mana.
6. **Warding (scene):** ward pool = scaled magnitude; incoming damage resolves block + armor, then soaks the ward before health; the remainder hits health; an empty pool means subsequent hits take full final damage; the ward expires after `duration` (pool 0, signal fired); recast replaces pool and timer; block xp is still granted on a soaked blocked hit.
7. **Mana regen (scene):** mana refills at `mana_regen_per_second` in the PlayerCombat loop, clamped at max; stamina regen unchanged.
8. **Transience (scene):** after a save/load round-trip the sheet's magic skills persist (the castable list re-derives identically) but selection resets and any ward is gone — `SAVE_VERSION` untouched at 1.
9. **HUD (scene):** the mana bar follows `mana_changed` from `bind`; the ward bar appears/updates/hides with `ward_changed`; HudSpell shows the selected `display_name` and updates on cycle and on learning.
10. **Data validation:** every `data/spells/*.tres` loads; count 5; unique ids == filename stems; non-empty display names; `skill_id` resolves to a `data/skills/` SkillDef with archetype `magic`; `mana_cost` / `magnitude` / `cast_time` > 0; `min_skill` ∈ {0, 25, 50}; evocation spells have `cast_range` > 0 and `duration` == 0; warding has `duration` > 0 and `cast_range` == 0; mending has both == 0.

## How to implement

One commit each, full suite green before each: spec doc + 004 amendment notes → canon-packet naming pass (names/descriptions authored from cited facts, lore stubs as needed, the aspect↔school gap surfaced to the director) → SpellDef + SpellLibrary + 5 .tres + BalanceConfig Magic group + validator/library/balance tests → CombatMath `spell_power`/`ward_absorb` + unit tests → SweepQuery extraction + PlayerCombat delegation → PlayerCombat mana regen + ward pool/soak/expiry + scene tests *(amended: ward precedes casting — PlayerCasting calls `apply_ward`, so the dependency must exist first)* → `cast`/`cycle_spell` actions + PlayerCasting + SpellCast node + player wiring + notice constants + casting/evocation/mending scene tests → HUD (mana bar, ward bar, HudSpell) + scene tests → magic_debug scene + docs housekeeping (master-plan row, CLAUDE.md Current focus).

**Debug scene** (`scenes/debug/magic_debug.tscn`): flat arena with a `default` spawn marker; debug script grants a few mana_draughts and binds hotkeys that pump xp into each school (to walk the 0→25→50 gates live); a marsh_rat and a bog_hound spaced out, one wall section (bolt LOS blocking); live label dump of mana/regen, selected spell + full castable list, ward pool + seconds remaining, school levels/xp, last damage dealt/taken. Leveling warding to 25 live doubles as the greater_ward unlock test.
