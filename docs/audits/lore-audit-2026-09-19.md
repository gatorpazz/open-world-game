# Lore audit — 2026-09-19 (Phase 2 exit, the outstanding half of the exit criterion)

Report-only; nothing in `docs/lore/` was edited. 77 entries walked (65 live + 12 templates/examples). Mechanical baseline: suite green (712), every `game_ids` value resolves, every `data/npcs|dialogue|journal|creatures` stem claimed exactly once (`greeting` exempt), no dangling links, no hookless anchors, no naming-convention violations. Strip-test: the world stays identifiable with the proper nouns removed (roofed island under a harvesting sky; magic as attention that invites predation; heat and light as commons-vs-deed; two descents; "kept, not dead"; bead cash; bells) — not generic fantasy. Weakest layer: **religion** (three aspects, no god-names, no cosmogony, no clergy voice); second: the hives' species identity.

## Findings (severity-ordered) — `entry_id — finding — disposition`

- **H1** `chitin_crawler` (draft, shipped as `data/creatures/chitin_crawler` + `items/raw_chitin` "sells by the plate") — makes chitin a renewable native stock; contradicts `shell_year` ("fixed stock, maintained not replenished") and `chitin_bridge`/`chitin_wrights` (fresh carapace is oath-breaking) — **director ruling**: crawler chitin is a lesser grade the wrights refuse for structure, or amend `shell_year` to *structural* chitin.
- **H2** `telling_time` (draft) — cited by the canon `bible` as the rule of record for Time; never director-read — **fix**: review → ratify in the next batch.
- **M1** `undervault` (canon) "no maps of the surface younger than the Coming" vs `licensed_crews` (canon) cover-maps + `open_fields` cover-marks + `wester` salvage maps — **fix** (one clause in `undervault`: no *surveys*; crews keep cover-maps) — edits canon, needs a director note.
- **M2** `bellworks` / `first_bells` (reviewed) "every bell is made of older bells… never mined" vs the spec-014 bell-bronze blade ruling; `first_bells` flags it unreconciled — **fix before promotion** (one sentence on the blade stream).
- **M3** canon surfacing `dialogue` with no topic behind it: `swift`, `tansy`, `wardens`, `reciters`, `licensed_crews`, `underfirst`, `lastlight`, `undervault`, `the_taking`, `the_workings`, `the_shares`, `rope_ring`, `scrimshaw_token`, `vault_rat` — **open question** (Phase 3 dialogue pass, or downgrade `surface`).
- **M4** `spore_puffer` (draft, shipped) — "wild fungus-*beast*" vs the fungus-craft palette; its own open question — **director ruling** (creature vs hazard-growth).
- **M5** `the_crown` (reviewed) — "first Lastlight-descended arbiter" still flagged "drafted invention for director veto"; hooks lean on it — **director ruling**, then promotable.
- **M6** `tidegate` (reviewed) — "does a fourth guild form here? director/Phase 2" — Phase 2 closed without ruling — **director ruling** or re-fence to Phase 3.
- **L1** `the_scar` (reviewed) links three drafts — **hold** until H1/M4 settle.
- **L2** `drowned_stair` claims `topic:drowned_stair` but its surface omits `dialogue`; `scar_hound` claims `topic:scar_hounds` (plural mismatch) — **fix**.
- **L3** 13 lore-bearing items unclaimed by any `game_ids` (`kindled_blade`, `tide_bead`, `steadying_bead`, `hound_fang`, `rat_pelt`, `spore_sac`, `raw_chitin`, `terrace_fungus`, `brewing_kit`, `salter_brine`, `lava_glass_grit`, `flawed_gem`, `sack_of_ore`) — **fix** (add `game_ids` to their owning entries).
- **L4** `data/items/mana_draught` — "shimmering blue philtre that restores magical reserves": the one item text still in generic-fantasy voice — **fix** (canon-packet rewrite).
- **L5** `bible`/`the_taking` say "ants"; the aesthetic brief says "wasp-nest cathedral" and "wingbeat" — species vocabulary unfixed — **open question** (bible).
- **L6** beneficiary-less hooks: `bellworks` brine-scented mallet, `ember_road` cold span every ninth day — **open question** or cut at quest time.
- **L7** the High Register is deferred everywhere and holds zero words, yet `first_bells`, seal-texts, and the reading rite depend on it — **stub** `rules/high_register` (draft).

## Red-team summary

Contradicts the region brief: H1, M1 only. Naming: clean. Mechanic vs rules limits: H1; L4 is wording only. False-in-world rumors all have beneficiaries (bridge "upkeep" → keepers; "natural, by common assent" → parish sounding-fees; "none remaining within" → the crown's purse; the three arrival tellings → each guild) except L6. Codex-removed inference: intended (hide-from-sky, grief-for-the-taken, heat/light as property, two peoples at odds); what a player would *not* infer is that magic costs attention (M3 is the gap) or that the Homebringers exist.

## Draft queue

16 `status: draft` files: 12 templates/examples, 4 real — `telling_time`, `deep_roads` (the locked stub, stays), `chitin_crawler`, `spore_puffer`.

## Next canonization batch — recommendation (director ratifies; agents never promote)

**Ready to ratify (22)**: `torrum`, `bryony`, `dossun`, `kellom`, `ollun`, `wester`, `wren`, `munnok`; `bait_square`, `grief_court`, `first_roof`, `open_fields`; `the_untaken_arrival`, `warden_doctrine`, `first_kept_names`, `the_coming`, `the_going_under`, `the_still_year`, `crown_compact`; `vent_parishes`, `hush_moths`; `telling_time` (review, then ratify — closes H2). Canon would go 19 → 41.

**Not ready**: `the_crown` (M5), `tidegate` (M6), `bellworks`/`first_bells` (M2), `shell_year`/`chitin_bridge`/`chitin_wrights`/`the_scar` (H1, L1), `chitin_crawler`/`spore_puffer` (H1, M4).

**Defer** the far geography (`highroof`, `embershare`, `ember_road`, `tide_road`, `last_road`, `leviathan_ribs`, `sealed_reaches`, `undersun_galleries`, `sealing_of_the_reaches`, `scar_night`, `the_beaching`, `terrace_centuries`, `cold_tier_hush`) until Phase 3 builds those scenes — canonizing places no scene has tested invites a second retrofit.
