# Repository layout and workflow

## Branches

```
vanilla-1.32:  Legacy vanilla files (1.32)                       the shared baseline
                 │
                 ├── legacy-PREP:  Community Patch – Base ── Preparations 6.2   the original mod
                 │
                 └── vanilla-5.x:  Vanilla files (5.x build 1090142) ── ...   CDPR's updates
                       │
                       └── master: tools, docs ── the port ── ...
```

| Branch | Contents |
|---|---|
| `vanilla-1.32` | The root commit: unmodified legacy (1.32, Steam build 3280809) game files under `modPreparations/`. |
| `legacy-PREP` | `vanilla-1.32` plus the legacy mod in two commits: Community Patch – Base v1.0 (its dependency; the same change as TriangleGhostMode's `legacy-GM`), then Preparations 6.2. See [legacy-mod.md](legacy-mod.md). |
| `vanilla-5.x` | `vanilla-1.32` plus the same file set from the current 5.x release (Steam build 26238013, `witcher3.exe` 5.0.0.1090142), one commit per release. |
| `master` | `vanilla-5.x` plus the project's tools and docs and the port. All work happens here or on short-lived branches off it (`prep/<slice>`). |

`vanilla-1.32`, `legacy-PREP` and `vanilla-5.x` hold game and mod data only; their one other file is a `.gitattributes` with `* text=auto`.

The vanilla file set:

- `modPreparations/scripts/`: every vanilla script (`content/content0/scripts`).
- `modPreparations/files/`: every `.xml`/`.csv` under `gameplay/` and `game/` (base game and each DLC's `data/`). The mod's only packed files, Blood and Wine's two `effects_ep2.xml`, are among them.

The baselines were cut from TriangleGwentImprovements' `vanilla-1.32` and `vanilla-5.x` trees (its two binary files left out), so every file the three repositories share has the same blob as there (2026-11-13), which keeps a later merge with Ghost Mode simple.

### The legacy mod on `legacy-PREP`

- **Community Patch – Base v1.0** comes first because the mod was written on it: the mod's `ingameMenu.ws` is a few changed lines from the patch's version but about 65 from vanilla's. The mod's readme names UPatch, the older community patch that Community Patch – Base replaced. The commit is TriangleGhostMode's `f6c81b31` with the folder renamed.
- **The mod**: shipped scripts at their vanilla paths under `modPreparations/scripts/` (converted to UTF-8); the shipped `localization/*.csv` as they are (the `.w3strings` were built from them and are not kept); the options menu XML under `modPreparations/menu/`; the readmes and the `*.settings.part.txt` files under `release/`. Details in [legacy-mod.md](legacy-mod.md).

## Keeping branches up to date

- **`vanilla-1.32` and `legacy-PREP` do not move.**
- **A new game release** is a new commit on `vanilla-5.x`: in a worktree of `vanilla-5.x`, re-extract the files with `master`'s `tools/extract_vanilla.py` ([below](#regenerating-the-baselines)) and commit them. `git diff <previous>..vanilla-5.x` shows what the patch changed. Then merge `master` onto it, as TriangleGhostMode does ([its repository.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/repository.md#keeping-branches-up-to-date)).

## Encodings and line endings

| Tree | Scripts | XML | CSV |
|---|---|---|---|
| Legacy game as shipped | UTF-16 LE with BOM | UTF-16 LE with BOM | mostly ASCII |
| Legacy mod as shipped | ASCII | ASCII | ASCII or UTF-8 |
| `vanilla-1.32` and `legacy-PREP` | UTF-8, no BOM (converted) | UTF-8, no BOM (converted) | as shipped |
| 5.x as shipped = `vanilla-5.x` | UTF-8, no BOM | UTF-8 **with BOM** | as shipped |

`.gitattributes` has `* text=auto`: text is stored with LF and checked out with CRLF on Windows (`core.autocrlf=true`). Ported XML must keep 5.x's BOM.

## Regenerating the baselines

`tools/extract_vanilla.py <out> [--utf8] [--game DIR] [--mod-files DIR]` rebuilds either baseline from an installed game ([tools.md](tools.md)): every script, every gameplay XML/CSV, and every file under `--mod-files`.

- Legacy: `--utf8 --game "<legacy game>"` (the legacy copy described in [tools.md](tools.md#game-installs)).
- 5.x: without `--utf8`, into the `vanilla-5.x` worktree's `modPreparations/`.
