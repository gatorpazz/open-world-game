# archive/undervault — the retired setting

This branch preserves the **undervault** setting exactly as it stood on
2026-09-19 (tag `undervault-final`): the lore vault with 48 canon entries,
the Lastdoor vertical slice (11 NPCs, 4 quests, 29 dialogue topics, 27
journal entries), the seven named world scenes, and the full engine with
712 tests green.

The setting was retired from the open-world game because its rules pull
toward a linear, authored structure (one dramatic question in the Core
promise; every hook serving a core tension; a roofed geography whose law
punishes open ground; a euphemistic register). Those same qualities suit a
tighter, linear game, which is why it is kept here rather than deleted.

## Rules for this branch

- It **never merges to `main`**. `main` restarts the vault from a blank
  foundation pass (spec 011, M1).
- Nothing lands here except this file. If the linear game starts, it gets
  its own repository.

## Spinning off a new repository

```bash
git clone git@github.com:gatorpazz/open-world-game.git linear-game
cd linear-game
git checkout archive/undervault
git checkout -b main
git remote remove origin
git remote add origin <new-repo-url>
git push -u origin main
```

Everything the setting needs is on this branch: `docs/lore/`, the
`data/` slice, `scenes/world/`, the lore engine under `scripts/lore/`, the
lore suite under `tests/lore/`, and the lore skills under `.claude/`.
