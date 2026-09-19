# Code-health sweep — 2026-09-19 (Phase 2 → 3 boundary)

Whole-codebase review, not a diff review. Baseline: 712/712 GUT tests, gdlint clean, one autoload (`Game`), every `data/` folder validated, no `class_name` collisions, flat inheritance, static typing effectively complete. Verdict: healthy; the findings below are a concentrated polish list, not rot. They seed the Phase 3 polish pass.

## Must fix or amend the spec

1. **Direct mutation of Game-owned ledgers** (house pattern: `Game` mutates its own state via `report_*`):
   - `scripts/magic/working.gd:28` — `Game.notice.add(...)` from the orchestrator. Add `Game.report_notice(amount)`.
   - `scripts/ui/dialogue_panel.gd:188` — `Game.bounty.clear(...)` from a UI panel; the whole `_settle_fine` path (178–189) is a rules transaction in a CanvasLayer. Add a `Fines.settle(...)` orchestrator + `Game.report_fine_paid(jurisdiction)`.
2. **"The player's parent is the world" via `get_parent()`** (signals up, calls down):
   - `scripts/player.gd:179-185` (drop spawn), `scripts/combat/creature.gd:172` (remains spawn), `scripts/player.gd:149-150` (wild-rest group check), `scripts/crime/theft.gd:29` + `scripts/magic/working.gd:35` (witness world). One injected world reference at `setup_identity` erases all five.
3. **Skill ceiling hardcoded as `100.0`** in `scripts/combat/combat_math.gd:19,45` while `BalanceConfig.skill_max` exists. Use `float(cfg.skill_max)`.
4. **Content ids in code with no validator behind them** (a rename fails silently):
   - `&"wardens"` jurisdiction — `scripts/crime/theft.gd:14`, `scripts/magic/working.gd:14`.
   - `&"brewing_kit"` — `scripts/alchemy/alchemy_rules.gd:17`; `&"lockpick"` — `scripts/crime/lockpicking.gd:10`. Prefer a `MiscDef.tool_kind` flag; minimum is a `BalanceConfig` StringName + a `tests/data` resolve assertion.
   - `ASPECT_ORDERS` — `scripts/magic/working_rules.gd:14`; `test_spell_defs.gd:69` validates data against this code list.
   - `DEFAULT_MAJOR_SKILLS` — `scripts/systems/stats_component.gd:19-25`, still live at `game.gd:80`; comment stale since 009.
5. **Tunables outside `balance_config.tres`**: `scripts/player.gd:20-21` (`speed`, `jump_velocity`), `scripts/resources/world_clock.gd:10` (`START_BELL`).

## Should fix (ambient reads, testability)

- `Game.clock.get_day()` read in three places just to day-stamp a journal entry (`world_item.gd:35`, `journal_trigger.gd:29`, `dialogue_panel.gd:96`); give `Journal` a current day set by `Game`.
- `scripts/combat/creature.gd:68` — `target = Game.player` every physics frame; call down after spawn instead.
- `scripts/ui/hud_clock.gd:16,26` — binds to `Game` directly; `bind(clock, config)` like `HudBars`.
- No tests reference `HudClock` or `HudBars`.
- Transactional UI panels holding rules a unit test cannot reach: `barter_panel.gd:79-123`, `brewing_panel.gd:49-63`, `dialogue_panel.gd:147-189`. Extract `Barter.buy/sell`, `Alchemy.brew`, and the fine/persuade side of effects into orchestrators (the `Theft` shape).
- `data/creatures/spore_puffer.tres` + `creature.gd` — canon now rules the spore-puffer a *rooted* hazard-growth (2026-09-19), but the creature wanders and chases like any other and `test_creature_defs.gd:46` asserts `move_speed > 0`. Add a rooted behaviour (never leaves IDLE, spits when in range; `move_speed` 0 is untested and the data test forbids it today) and set the puffer to it.
- `scripts/combat/creature.gd:65-233` — the whole state machine is scene-test-only; a pure `CreatureRules` (`can_aggro`, `attack_distance`, `next_state`) would unit-test the transitions.

## Judgment calls (recorded, not queued)

- Seven player-facing persuasion outcome lines live in `scripts/social/persuasion.gd:25,37-46` — reviewable/canon-packetable as data, not a hard fail.
- `player_casting.gd:102-106` and `player_combat.gd:57` dispatch behaviour on skill content ids (`evocation`/`mending`/`warding`, `ranged`); a `SpellDef.effect_kind` / `WeaponDef.is_ranged` would decouple. Already an 008 backlog line.
- `inventory_panel.gd:32` rows are `Array[Dictionary]` holding `ItemDef`s; `save_codec.gd:282,285,599,605` and `quest_evaluator.gd:51` could declare tighter container types.
- `owner`-as-actor in `interaction_detector.gd`, `player_combat.gd`, `player_casting.gd` — accepted idiom; an `@export var actor` would drop the dependency.
- `Inventory` / `Journal` are unprefixed generic nouns; grandfathered.
