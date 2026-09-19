# Backlog

Ideas and deferrals that serve a pillar but not the current phase, or expand the scope budget (master plan §3). Nothing here is committed work. Each line names the spec that fenced it so the reasoning is one hop away. Prune at the monthly checkpoint; an item that leaves this file goes to a numbered spec or gets deleted with a Decision Log row.

Rejected-permanently items are **not** listed here; they live in the specs that rejected them (haggling 016, dice-roll spell failure 008, quest markers, YAML, voiced lore, ...).

## Phase 3 candidates (already named in CLAUDE.md "Phase 3 owns")

- **021 fast-travel network** — mini-spec, mechanism mapped (`Game.change_scene` + journal-derived hubs + `spend_gold` fares + `advance_time`); needs settlement scenes to travel between. *Deferred 2026-07-23.*
- **The polish pass** — deferred at the Phase 2 exit audit (2026-07-24); the code-health findings in `docs/audits/code-health-2026-09-19.md` are its seed list.
- **Promotion conversations / faction-rank reward delivery** — 015 shipped `can_advance` with no rank-up dialogue; 023's rank-acquired bound workings wait on it.
- **Dynamic crafting** (player enchanting bench, charges + recharge, player-authored items) — 022/023 fenced under "no dynamic crafted items in Phase 2"; needs a `SAVE_VERSION` answer for per-instance state.
- **The barter buy/sell split** — 019 ships one symmetric disposition factor; split lowers buy and raises sell independently.
- **Order factions for magic charters** — Flame/Stone/Tide have no `FactionDef`; `is_chartered_under(<order>)` is always false in v1 (018).
- **The reserved hearth-name intimacy** on the six reserved NPCs — director taste, off-limits until ratified (019).
- **Regional price variation + per-jurisdiction bounties** — `price_multiplier` and the faction-keyed bounty ledger are inert hooks until more than one settlement exists (016, 017).

## System deferrals (later spec, no phase assigned)

- Currency-term UI + field sweep, Gold → bead (`Gold:` labels, `give_gold`/`spend_gold`) — the 014/016/017 carve-out.
- Mana-term carve-out — the last sliver of spec-010 audit debt 1 (014).
- Birthsign-analog perks / backgrounds — 009's deferral.
- Levitation + the tri-key — lore-backed hook, explicitly not queued (018, Decision Log).
- Fencing / the Quiet Lines laundering seam; pickpocketing; trap disarming; hostile guards / NPC combat (017).
- Roof-vs-open notice pricing once world data carries roof state; overcast as an NPC social reaction beyond gates and prices (018, 019).
- Elemental damage types, spellmaking, channeled spells, magic resistance, silence, ward stacking, a shared global cooldown, a `SpellDef` effect enum (008, 018).
- Active blocking, unarmed combat, cleave (004).
- Ingredient harvest nodes / herbalism; poisons and apply-to-weapon alchemy; a world brewing bench (022).
- Fortify-attribute and timed non-ward buffs on bound workings (023).
- A projectile visual for the spit; flee / pack-call AI; humanoid equipment-wielding NPCs (024).
- High-sky season layer over `day`; multi-window NPC schedules; timed quests, entry-aging bounties, spoilage; fatigue/hunger and rest interruption (020).
- Autosave; named save slots; save thumbnails; a fuller settings surface (keybinds, invert-Y, resolution, per-bus volume) (025).
- Live quest re-evaluation on journal signals; citation floor extended to `NPCDef`/`ItemDef` text (006).
- Persistent dropped items and persistent merchant depletion — both deliberately runtime-only (016); revisit only if a design needs them.
- A lore-audit git hook or CI step, lore localization (011).
- In-game lore books / codex rendering of the vault (011).

## Process

- A stranger playtest of the slice (the Phase 1 exit criterion as written; only director playthroughs are recorded).
