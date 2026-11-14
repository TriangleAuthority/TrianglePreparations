# Preparations for The Witcher 3 — 5.x port

Preparations is a gameplay mod for The Witcher 3 by Wasteland Ghost (wghost81), the author of Ghost Mode. It makes meditation the time to prepare: skills, mutagens, alchemy, repairs and upgrades can be changed only while meditating or at a campfire, each takes game time, alchemy items are refilled one by one from ingredients instead of automatically, meditation needs a fire, and eating, drinking and oils are restricted in combat. Everything is configurable from the options menu. Its last release, 6.2, targets the **legacy** game (patch 1.32); it does not work on current versions.

This repository ports it to **game version 5.x** (the 2026 remaster), the same way [TriangleGhostMode](https://github.com/TriangleAuthority/TriangleGhostMode) ports Ghost Mode and [TriangleGwentImprovements](https://github.com/TriangleAuthority/TriangleGwentImprovements) ports Gwent Improvements: re-expressed with 5.x's script annotations and DLC overrides instead of whole-file edits, one small slice at a time, each verified in game.

**First version: legacy behaviour, bugs fixed.** The port reproduces the legacy mod's behaviour and options. Bugs are fixed as they are found, and every difference from legacy is recorded in [docs/deviations.md](docs/deviations.md).

Preparations works with vanilla meditation or with Friendly Meditation (same author), which its readme recommends: with it, meditation happens in real time and a campfire can be spawned with timber. Friendly Meditation is ported separately in [TriangleFriendlyMeditation](https://github.com/TriangleAuthority/TriangleFriendlyMeditation); the two ports must work together and apart.

**Compatible with Ghost Mode, merge possible later.** Like the Gwent port, this mod is developed separately from the Ghost Mode port but must work with it. See [docs/ghost-mode-compatibility.md](docs/ghost-mode-compatibility.md).

**Save-safe, as in legacy.** The legacy mod could be installed and removed at any point of a playthrough. The port keeps that unless a feature forces otherwise (recorded as a deviation).

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
