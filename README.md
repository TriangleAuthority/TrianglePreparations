# Preparations for The Witcher 3 — 5.x port

Preparations is a gameplay mod for The Witcher 3 by Wasteland Ghost (wghost81), the author of Ghost Mode. It makes meditation the time to prepare: skills, mutagens, alchemy, repairs and upgrades can be changed only while meditating or at a campfire, each takes game time, alchemy items are refilled one by one from ingredients instead of automatically, meditation needs a fire, and eating, drinking and oils are restricted in combat. Everything is configurable from the options menu. Its last release, 6.2, targets the **legacy** game (patch 1.32); it does not work on current versions.

This repository ports it to **game version 5.x** (the 2026 remaster), the same way [TriangleGhostMode](https://github.com/TriangleAuthority/TriangleGhostMode) ports Ghost Mode and [TriangleGwentImprovements](https://github.com/TriangleAuthority/TriangleGwentImprovements) ports Gwent Improvements: re-expressed with 5.x's script annotations and DLC overrides instead of whole-file edits, one small slice at a time, each verified in game.

**First version: legacy behaviour, bugs fixed.** The port reproduces the legacy mod's behaviour and options. Bugs are fixed as they are found, and every difference from legacy is recorded in [docs/deviations.md](docs/deviations.md).

Preparations works with vanilla meditation or with Friendly Meditation (same author), which its readme recommends: with it, meditation happens in real time and a campfire can be spawned with timber. Friendly Meditation is ported separately in [TriangleFriendlyMeditation](https://github.com/TriangleAuthority/TriangleFriendlyMeditation); the two ports must work together and apart.

**Compatible with Ghost Mode, merge possible later.** Like the Gwent port, this mod is developed separately from the Ghost Mode port but must work with it. See [docs/ghost-mode-compatibility.md](docs/ghost-mode-compatibility.md).

**Save-safe, as in legacy.** The legacy mod could be installed and removed at any point of a playthrough. The port keeps that unless a feature forces otherwise (recorded as a deviation).

## Status

All of the legacy mod's features are ported and tested in game, beside the Ghost Mode port, and with Friendly Meditation. Not yet seen in game: Friendly Meditation's campfire refused in an interior or a settlement. There is no packaged release yet.

## Installing

Needs The Witcher 3 game version 5.x (PC). Requirements of the legacy mod (Community Patch – Base, UPatch) do not apply: 5.x contains what it needed.

1. **Get the zip** `modPreparations-<version>.zip`: from a release once there is one, or build it from this repository with `python tools/build_mod.py --ref master --out build/release --package` (needs Python 3 and REDkit, see [docs/tools.md](docs/tools.md)); the zip is then in `build/release/`.
2. **Extract it into the game folder** `<game>` (the folder that holds `bin` and `content`), keeping its folders: it puts the mod into `<game>\mods\modPreparations\` and its options menu into `<game>\bin\config\r4game\user_config_matrix\pc\modPreparationsConfig.xml`. Nothing else in the game changes.
3. Start the game: the options are under **Options → Mods → Preparations**. They start at the legacy defaults; with Friendly Meditation installed, at legacy's "Friendly Meditation" preset (meditation allowed away from fire, a campfire costs 1 Timber, alchemy, skills, mutagens, repairs and upgrades need meditation). Nothing needs to be applied by hand.

The mod is save-safe, as in legacy: it can be installed or removed at any point of a playthrough. To remove it, delete the `modPreparations` folder from `<game>\mods\` and the menu file `modPreparationsConfig.xml` from step 2.

## Using it with other mods (Script Merger)

**With the Ghost Mode, Friendly Meditation and Gwent Improvements ports: nothing to merge.** They are built to run side by side as separate mods, in the default folder order (tested in game, with Ghost Mode's full regression run passing beside them).

**With other mods:** Script Merger merges *loose* scripts (`.ws` files) that two mods both edited. This port ships compiled scripts instead (`content\precompiled.rsblob`, built with 5.x's script annotations), which Script Merger cannot merge. Use it to find conflicts, not to fix this mod's:

1. Install all your mods first, this one included.
2. Run Script Merger Remastered (the 5.x version of Script Merger, on Nexus Mods) and refresh the conflict list.
3. Merge the conflicts it can merge between your *other* mods as usual.
4. Conflicts that involve this mod are listed as "not mergeable": leave them unmerged. The game resolves them itself:
   - Where two compiled mods replace the same function, the mod whose folder name sorts first wins. To change that, give the mod you want to win a lower `Priority` in `Documents\The Witcher 3\mods.settings` (a section `[modPreparations]` with `Priority=50`, for example; the default is 100).
   - Where a mod only adds code around a function (most of this port's changes), both mods' additions run.
   - A loose-script mod that edits the same function as this mod loses to it, whatever its priority.
5. Do **not** let Script Merger Remastered 3.x merge this mod's compiled scripts into a merged mod: in tests of that feature, compiled mods lost some of their changes.

**Mods that add effect types** (or other members of a game enum) need their numbers lined up when two compiled mods add them: the game numbers every mod's additions in load order, so one mod's numbers can shift and its effects stop working. Ghost Mode, Preparations and Friendly Meditation already line up: Friendly Meditation adds none, and Preparations declares Ghost Mode's effect types first, by the same names and in the same order, then its own (checked against Ghost Mode's current list). With another mod that adds effect types, run `python tools/enum_sync.py apply` from a [TriangleGhostMode](https://github.com/TriangleAuthority/TriangleGhostMode) checkout after installing your mods: it patches every installed compiled mod so all agree on the numbers. Run it again after installing, updating or removing such a mod.

If two mods still clash in game, keep the one you prefer first in the load order, or do not combine them.

## Differences from the legacy mod

Every difference from the legacy mod, with the reason and who decided it, is listed in [docs/deviations.md](docs/deviations.md).

## How this repository is organised

The same layout as TriangleGhostMode and TriangleGwentImprovements: every branch starts from the same root commit, the legacy (1.32) game files, so every change is visible as a diff.

| Branch | Contents |
|---|---|
| `vanilla-1.32` | Unmodified legacy (1.32) game files at the mod's paths: the baseline every other branch starts from |
| `legacy-PREP` | `vanilla-1.32` + Community Patch – Base (the mod's dependency) + Preparations 6.2 (two commits) |
| `vanilla-5.x` | `vanilla-1.32` + the same game files from the current 5.x release (Steam build 26238013, `witcher3.exe` 5.0.0.1090142) |
| `master` | `vanilla-5.x` + the port (work in progress), plus the README, tools and docs |

- What the mod changed: `git diff legacy-PREP~1 legacy-PREP` (add `-w`)
- What CDPR changed in 5.x: `git diff vanilla-1.32...vanilla-5.x`
- The port so far: `git diff vanilla-5.x...master -- modPreparations`

`modPreparations/` contains the full vanilla file set (every script, every gameplay XML/CSV) with the mod's changes applied on `legacy-PREP` and `master`, so it is a reference tree, not a ready-to-install mod. See [docs/repository.md](docs/repository.md).

## Documentation

See [docs/](docs/README.md). Start with [docs/port-plan.md](docs/port-plan.md) for where the port stands and what's next.

Testing in game by script, and several AI agents sharing one game install, use TriangleGhostMode's tools: clone [TriangleGhostMode](https://github.com/TriangleAuthority/TriangleGhostMode) next to this repository and follow its [docs/setup.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/setup.md).

Working with an AI coding agent such as Claude Code: [CLAUDE.md.public](CLAUDE.md.public) holds this project's directions for it; copy it to `CLAUDE.md` to use them.
