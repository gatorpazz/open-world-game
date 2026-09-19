---
title: Spore-Puffers
type: wildlife
status: draft
region: undervault
pitch: "Squat fungus-growths of the unlit galleries that swell and cough a stinging spore-cloud at whatever treads too near."
spoiler: none
surface:
  - environment
game_ids:
  - creature:spore_puffer
  - item:spore_sac
---

## Function

A ranged hazard of the galleries (spec 024): the spore-puffer holds its
ground and coughs a stinging cloud rather than charging, teaching the
player that not every threat closes to arm's reach. Its spent gland is a
salter's and simpler's reagent.

## Canon summary

Spore-puffers are growths, not beasts: feral kin of the terrace fungus the
island eats and doctors with ([[tansy]]), rooted in the unlit galleries
and grown defensive. A puffer swells when a footfall crosses its patch and
coughs a dust-cloud that stings the eyes and lungs at a short distance; it
does not hunt, and clearing a patch is knife-work, not a fight. Salters
and simplers gather the spent gland — the spore-sac — and grind it into
draughts. The draught does what they say it does; the telling that its
dust thins a worker's regard the way a moth-fall thins a lamp is the
simplers' own, and nothing in [[the_workings]] says so.

## Open questions

- ~~Beast or hazard-growth?~~ — ruled (2026-09-19, lore audit M4): a
  hazard-growth. Not fauna; the fungus-craft palette extends to one feral,
  defensive growth.
- ~~Does ground spore truly hide regard?~~ — ruled (2026-09-19): the
  draught's effect is real; the simplers' moth-fall explanation is
  folk-theory, not a ratified mechanism ([[the_workings]] is untouched).
- Game drift: the shipped `creature:spore_puffer` wanders and closes to
  spit range like any other creature, while canon now says rooted. Reconcile
  in the Phase 3 polish pass (a rooted behaviour is untested and the data
  suite currently requires `move_speed` > 0); until then the prose leads
  and the scene lags.
- Folder: spec 011 has no growth type, so the entry sits in `wildlife/` as
  a mechanical convenience; `type: wildlife` is not a claim that it is
  fauna.
