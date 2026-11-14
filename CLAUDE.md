# CLAUDE.md

Porting the Witcher 3 mod Preparations 6.2 (by wghost81) from the legacy game (1.32) to game version 5.x.

Read [README.md](README.md) for the project's purpose, scope decisions and branch layout, then [docs/README.md](docs/README.md), which indexes the rest. Where the port stands and what to do next: [docs/port-plan.md](docs/port-plan.md).

This project is a sibling of TriangleGhostMode (`../TriangleGhostMode`, the Ghost Mode port) and TriangleGwentImprovements (`../TriangleGwentImprovements`), and works the same way. Before writing mod code, read TriangleGhostMode's `docs/development.md`: how to make changes on 5.x (script annotations such as `@wrapMethod`/`@replaceMethod`, XML overrides with `on_conflict` through a DLC, DLC mounters), the build and compile check, and testing in game. Port in small steps, each verified in game.

- **The game install is shared with TriangleGhostMode and TriangleGwentImprovements.** Never launch, install into or change the game without holding TriangleGhostMode's game slot (its `tools/game_lock.py`), back up the saves before a launch, and before releasing the slot put back what the owner plays (Ghost Mode and Gwent Improvements release builds; this mod is not part of the owner's install unless the owner says so). The procedure: [docs/tools.md](docs/tools.md#testing-in-game).
- **Both skill trees.** 5.x has the classic skill tree (behind a hidden setting) and a new one. Anything that touches skills is ported, and tested, for both, as in TriangleGhostMode ([its feature-mapping.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/feature-mapping.md#two-skill-trees)).
- **Ghost Mode compatibility** is a goal: prefer annotation forms that do not clash with Ghost Mode's (check its `master` for annotations on the same methods), keep this mod's names prefixed (`PREP`/`prep`), and keep string ids in the legacy mod's own range. See [docs/ghost-mode-compatibility.md](docs/ghost-mode-compatibility.md).
- **Friendly Meditation** (`../TriangleFriendlyMeditation`) is ported alongside; keep the hooks between the two mods working with either installed alone or both.
- **Tools** shared with the sibling projects are copies: a fix to one belongs in all of them.

## Keeping docs current

The docs are the project's authoritative reference, not a log. Update them at milestones (a feature verified, a tool working, a decision made) and before ending a session; revise what is there so it states current knowledge, and delete what turned out wrong.

- **Record every deviation from legacy when it is made** (a bug fix, a kept 5.x behaviour, a changed rule) in [docs/deviations.md](docs/deviations.md), in the same commit: legacy vs port, why, who and when ("porter's call" until the owner confirms it).
- **Open questions** go to [docs/open-questions.md](docs/open-questions.md); move answers into the doc they belong to and delete the entry.
- **Status labels:** mark claims as **verified** (tested in game), **compiles** (accepted by the compile check only) or **unverified** (from files, documentation or other sources).
- New docs go into the index in [docs/README.md](docs/README.md).

Binary game files (`.w2ent`, ...) show up as text in `git diff`/`git show` through the `cr2w` diff driver; enable it once per clone as described in [docs/tools.md](docs/tools.md#git-and-github).
