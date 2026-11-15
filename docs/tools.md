# Tools

`<game>` and `<REDkit>` stand for the install folders of The Witcher 3 and of REDkit. The tools find them through Steam, or take them from the `W3_GAME_DIR` and `W3_REDKIT_DIR` environment variables (`tools/paths.py`). No absolute paths go into the repository.

## Project tools (`tools/`)

Plain Python 3 (tested with 3.13), no extra packages. They are copies of TriangleGwentImprovements' tools, which are copies of TriangleGhostMode's; that repository's [tools.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/tools.md) documents them in full. Differences here: the mod folder is one constant, `paths.MOD` (`modPreparations`), and in-game test scripts go in `modPreparations/scripts/local/prep/tests/` (exec functions `preptest_*`). A fix to one of them belongs in all three repositories.

| Script | Purpose |
|---|---|
| `paths.py` | Finds the game and REDkit install folders; `MOD` names the mod folder. Run it to print what it finds. |
| `extract_vanilla.py <out> [--utf8] [--game DIR] [--mod-files DIR]` | Extracts the vanilla file set from a legacy or 5.x install. See [repository.md](repository.md#regenerating-the-baselines). |
| `unbundle.py <bundle-or-dir> <out_dir> [--list]` | Extracts every file from `.bundle` files (game bundles, packed mods). |
| `to_utf8.py <dir-or-file>...` | Converts UTF-16/BOM text to plain UTF-8 in place (legacy files only; 5.x XML keeps its BOM). |
| `cr2w_dump.py <file>`, `cr2w_dump.py --rev <ref> <path>` | Dumps a binary CR2W file (`.w2ent`, ...) as text. Also git's `cr2w` diff driver ([below](#git-and-github)). |
| `cr2w_patch.py FILE EDIT [...]` | Edits properties of a CR2W file and fixes its sizes and CRCs. Its `--selftest` only works in TriangleGhostMode. |
| `bindiff.py BASE OTHER [PATH ...] [--summary]` | Property-level diff of the binary files under the mod folder that differ between two refs (none so far). |
| `w3strings.py encode\|decode <in> <out> [--version 162]` | Encodes and decodes string tables (5.x format by default; `--version 162` for legacy). |
| `make_reddlc.py <out.reddlc> --id ID --xml PATH ...` | Writes a DLC definition whose mounters load the given definitions XML (for XML overrides through the mod's own DLC). |
| `build_mod.py --ref REF --out DIR`, `--install-from DIR --holder AREA:TOKEN [--enable]`, `--uninstall --holder AREA:TOKEN` | Builds the mod from a branch: compiles every script `REF` adds or changes under `modPreparations/scripts/` with `wcc_lite` (the compile check), packs changed game files into `blob0.bundle`, encodes `localization/<table>/<lang>.csv`, collects `menu/*.xml`. Installing needs the game slot (below) and the game closed. `--release` leaves out the test scripts. It imports `game_lock.py` from the TriangleGhostMode checkout next to this one (or `TGM_TOOLS`), so all three projects share one game slot and one compiler lock. Anything else under `modPreparations/` that a branch changes stops the build (e.g. `bin/config/.../input.xml`: a port of key bindings needs its own handling first). |
| `soundcache.py` | Packs Wwise banks for `build_mod.py` (none). |

**Verified** (slice 0, 2026-11-13): `build_mod.py --ref master --out build/slice0-<commit>` compiles `master`'s ping test script (`preptest_ping`) cleanly with `wcc_lite` against the 5.x game scripts. 

## Testing in game

**The game is one install shared with TriangleGhostMode and TriangleGwentImprovements**, and its game tools (`game.py`, `game_lock.py`, rw3d_cli, `modAutomation`) are used from the TriangleGhostMode checkout, as its `w3-game-automation` skill describes. The procedure is TriangleGwentImprovements' ([its tools.md](https://github.com/TriangleAuthority/TriangleGwentImprovements/blob/master/docs/tools.md#testing-in-game)), **verified** for this mod (slice 0, 2026-11-14):

1. Commit, then build this mod (`python tools/build_mod.py --ref <branch> --out build/<slice>-<commit>`). `game.py` refuses to start without a `modGhostMode` installed in the same turn: reinstall the Ghost Mode build the owner plays (its `build/` folder there; `game.py`'s install record names it) or build TriangleGhostMode's `master`.
2. In TriangleGhostMode: `python tools/game_lock.py request --who PREP --why "..."` (the grant backs up the saves; also back them up with robocopy as its skill says, from PowerShell: Git Bash turns robocopy's `/E` into a path. Documents may be under OneDrive: `%USERPROFILE%\OneDrive\Documents\The Witcher 3\gamesaves` on the owner's machine).
3. Install both with each repository's `build_mod.py --install-from ... --holder PREP:<token>` (this mod with `--enable`).
4. In TriangleGhostMode: `python tools/game.py run <save> --holder PREP:<token>`, then `game.py exec "preptest_ping()" --holder ...` and read the log, then `game.py quit`.
5. **Put the owner's install back before releasing**: uninstall this mod (`build_mod.py --uninstall --holder PREP:<token>`; check that its menu file is gone from `<game>/bin/config/r4game/user_config_matrix/pc/`), and put back the Ghost Mode and Gwent Improvements release builds if the run replaced them. Then `game_lock.py release --holder PREP:<token>` there, and check that its saves line says clean.

**Mod settings live in the user settings file** (`dx12user.settings` on 5.x; the options menu writes them), which the owner's game shares: a test that changes this mod's options, and the first load with the mod (which writes its defaults), write into the owner's settings file. `game_lock.py release` restores the settings files (and `mods.settings`, where `--uninstall` leaves this mod's entry) from the grant's baseline; set changed options back anyway, or set them in memory only (`CInGameConfigWrapper.SetVarValue` without saving), as GI-SKIP's test does.

## Game installs

- **5.x:** `<game>`, Steam app 292030, the same install TriangleGhostMode uses.
- **Legacy (1.32):** the `legacy-The Witcher 3` folder next to the checkouts (`witcher3.exe` 3.0.0.1259521), the copy TriangleGhostMode describes in its [tools.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/tools.md#game-install).
- **REDkit:** `<REDkit>`, Steam app 2684660 (`wcc_lite` for compiling and packing).

## Git and GitHub

- Remote: none yet (planned: `git@github.com:TriangleAuthority/TrianglePreparations.git`, private, like the sibling repositories). Repo-local identity: `Triangle Man <4241168+TriangleAuthority@users.noreply.github.com>`.
- SSH: the key is in the Windows OpenSSH agent, so the clone sets `core.sshCommand` to Windows' own `ssh.exe` (`%SystemRoot%\System32\OpenSSH\ssh.exe`), as in TriangleGhostMode.
- **Readable diffs of binary files**: enable the `cr2w` diff driver once per clone:

  ```bash
  git config diff.cr2w.textconv "python tools/cr2w_dump.py"
  git config diff.cr2w.cachetextconv true
  ```
