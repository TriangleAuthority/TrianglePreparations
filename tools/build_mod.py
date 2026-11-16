"""Build an installable 5.x mod from a branch, and optionally install it.

This repository's branches hold the full vanilla file set with the mod's edits applied
(see docs/repository.md), so they cannot be installed as they are. This script takes
only what a branch changes relative to vanilla 5.x and builds a mod from it:

    <out>/scripts/<path>                     every script the branch adds or modifies,
                                             written straight from git objects (the
                                             working tree and checkout do not matter)
    <out>/<name>/content/precompiled.rsblob  those scripts compiled by REDkit's
                                             `wcc_lite compilescripts` against the game's
                                             own scripts (about 20 seconds; full log in
                                             <out>/compile.log)
    <out>/files/<depot path>                 every other game file the branch adds or
                                             modifies under <mod>/files
    <out>/<name>/content/blob0.bundle        those files packed by `wcc_lite pack` (zlib,
    <out>/<name>/content/metadata.store      like the 5.x game bundles), plus the metadata
                                             store from `wcc_lite metadatastore`
    <out>/<name>/content/<lang>.w3strings    the string tables: every
                                             <mod>/localization/<table>/<lang>.csv,
                                             merged per language and encoded by
                                             tools/w3strings.py
    <out>/<name>/bin/config/r4game/user_config_matrix/pc/<file>.xml
                                             the options menu: every <mod>/menu/*.xml.
                                             --install copies these into the game's own bin
                                             folder (the game reads menus only from there) and
                                             records them, so a reinstall removes stale ones
    <out>/<name>/content/soundspc.cache      the Wwise banks: every <mod>/sound/*.bnk,
                                             packed by tools/soundcache.py (sound cache
                                             format 2, as 5.x's own)

The mod ships the compiled blob, not loose scripts: 5.x applies scope-based overrides
and enum extensions only from a mod's precompiled.rsblob, and ignores a mod's loose
scripts when it has one. Compile errors therefore show up here, not at game start.
With --loose the mod gets the loose scripts instead (annotations and whole-file
overrides work that way; scope-based overrides and enum extensions do not).

Not handled (the script lists them and stops): anything else outside
<mod>/scripts, <mod>/files, <mod>/localization,
<mod>/menu and <mod>/sound.

Usage:
    python tools/build_mod.py --ref prep/<slice> --out build/<slice>-1a2b3c4d         # build and compile into a folder
    python tools/build_mod.py --ref master --out build/release --package
                                                                     # a release zip, laid out like the game folder: extract it into the game to install
    python tools/build_mod.py --install-from build/wgt-1a2b3c4d --holder AREA:TOKEN
                                                                     # install that build (the game slot's holder)
    python tools/build_mod.py --ref prep/<slice> --out build/<slice> --install --holder AREA:TOKEN
                                                                     # build and install in one go
    python tools/build_mod.py --scripts tools/automation/scripts --name modAutomation --out build/automation --install --enable --parent
                                                                     # scripts from a folder instead of a branch (the parent only)

--ref and --out are required (no default branch or folder, so parallel agents never build
master or overwrite each other's build by accident). Installing changes the shared game: it
needs --holder AREA:TOKEN from tools/game_lock.py (or the parent's --parent) and the game closed.
Each wcc_lite run takes a short OS file lock (wcc_lite writes shared REDkit files and listens on
port 37000), so parallel builds wait their turn; the build runs at below-normal priority.

See docs/development.md.
"""

import argparse
import configparser
import os
import shutil
import subprocess
import sys
from pathlib import Path

import paths

# The game slot is TriangleGhostMode's (one game install for both projects): its game_lock.py, from the
# sibling checkout (or TGM_TOOLS), so both projects queue for the same slot and compiler lock.
sys.path.insert(0, os.environ.get("TGM_TOOLS") or str(Path(__file__).resolve().parents[2] / "TriangleGhostMode" / "tools"))
import game_lock  # noqa: E402
import soundcache
import w3strings
from paths import documents_dir  # noqa: F401  (kept importable from here)

REPO = Path(__file__).resolve().parent.parent
MOD = paths.MOD
SCRIPTS = f"{MOD}/scripts/"
FILES = f"{MOD}/files/"
LOCALIZATION = f"{MOD}/localization/"
MENU = f"{MOD}/menu/"
SOUND = f"{MOD}/sound/"
TESTS = f"{MOD}/scripts/local/prep/tests/"  # preptest_* exec functions and probes; left out with --release
TEST_FILES: set[str] = set()  # test-only game files, left out with --release (none yet)
MENU_DIR = Path("bin") / "config" / "r4game" / "user_config_matrix" / "pc"
MARKER = ".built-by-build_mod"  # only folders carrying this are deleted on reinstall


def git(*args: str) -> bytes:
    return subprocess.run(["git", *args], cwd=REPO, check=True, capture_output=True).stdout


def changed_paths(base: str, ref: str) -> list[tuple[str, str]]:
    out = git("diff", "--name-status", "--no-renames", "-z", f"{base}...{ref}", "--", MOD)
    parts = out.decode("utf-8").split("\0")
    return [(parts[i], parts[i + 1]) for i in range(0, len(parts) - 1, 2)]


def warn_uncommitted(ref: str) -> None:
    """Warn when a worktree that has `ref` checked out has uncommitted changes under the mod folder:
    the build takes the commit, not the working tree."""
    out = git("worktree", "list", "--porcelain").decode("utf-8", "replace")
    for block in out.split("\n\n"):
        lines = dict(line.split(" ", 1) for line in block.splitlines() if " " in line)
        branch = lines.get("branch", "").removeprefix("refs/heads/")
        if lines.get("worktree") and branch and branch == ref:
            r = subprocess.run(["git", "-C", lines["worktree"], "status", "--porcelain", "--", MOD + "/"],
                               capture_output=True, text=True, errors="replace")
            changed = [x for x in r.stdout.splitlines() if x.strip()]
            if changed:
                print(f"warning: {lines['worktree']} ({ref}) has {len(changed)} uncommitted change(s) under {MOD}/; "
                      f"this build takes {ref}'s last commit, without them:")
                for x in changed[:10]:
                    print(f"  {x}")


def collect(base: str, ref: str, out: Path, release: bool = False) -> tuple[Path | None, Path | None, list[str], list[str], list[str]]:
    """Write what ref changes relative to base into <out>/scripts and <out>/files.

    Also returns the localization CSVs, menu XML files and sound banks on ref (all of
    them: vanilla has none). With release, the in-game test scripts (TESTS) and test data (TEST_FILES) are left out.
    """
    scripts, files, other, deleted = [], [], [], []
    for status, path in changed_paths(base, ref):
        if status == "D":
            deleted.append(path)
        elif path.startswith(SCRIPTS):
            if release and path.startswith(TESTS):
                continue
            scripts.append(path)
        elif path.startswith(FILES):
            if release and path in TEST_FILES:
                continue
            files.append(path)
        elif path.startswith(LOCALIZATION) or path.startswith(MENU) or path.startswith(SOUND):
            pass
        else:
            other.append(path)
    localization = [p for p in git("ls-tree", "-r", "--name-only", ref, "--", LOCALIZATION).decode().splitlines()
                    if p.endswith(".csv")]
    menus = [p for p in git("ls-tree", "-r", "--name-only", ref, "--", MENU).decode().splitlines()
             if p.endswith(".xml")]
    banks = [p for p in git("ls-tree", "-r", "--name-only", ref, "--", SOUND).decode().splitlines()
             if p.endswith(".bnk")]

    if deleted:
        print(f"warning: {len(deleted)} file(s) deleted on {ref}; a mod cannot delete game files:")
        for p in deleted:
            print(f"  {p}")
    if other:
        print("error: this script cannot build these changes yet:")
        for p in other:
            print(f"  {p}")
        sys.exit(1)
    vanilla_scripts = [p for p in scripts if not p.startswith(SCRIPTS + "local/")]
    if vanilla_scripts:
        # The mod ships no copies of vanilla scripts (docs/development.md, Choosing a technique). Such paths
        # mean --base is not the vanilla release ref is built on, e.g. a new release's vanilla commit not yet
        # on vanilla-5.x: build with --base <that commit's branch>.
        print(f"error: {ref} changes {len(vanilla_scripts)} vanilla script(s) relative to {base} "
              f"(is --base the vanilla release {ref} is built on?):")
        for p in vanilla_scripts[:10]:
            print(f"  {p}")
        sys.exit(1)
    if not scripts and not files and not localization and not menus and not banks:
        print(f"nothing to build: {ref} changes nothing relative to {base}")
        sys.exit(1)

    result = []
    for paths, prefix, sub in ((scripts, SCRIPTS, "scripts"), (files, FILES, "files")):
        target_dir = out / sub
        if target_dir.exists():
            shutil.rmtree(target_dir)
        if not paths:
            result.append(None)
            continue
        for path in paths:
            target = target_dir / path[len(prefix):]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(git("cat-file", "blob", f"{ref}:{path}"))
        print(f"collected {len(paths)} file(s) under {sub}/ from {ref}:")
        for path in paths:
            print(f"  {path[len(prefix):]}")
        result.append(target_dir)
    return result[0], result[1], localization, menus, banks


def encode_strings(ref: str, csv_paths: list[str], out: Path) -> Path | None:
    """Merge the localization CSVs per language and encode one <lang>.w3strings each."""
    strings_dir = out / "strings"
    if strings_dir.exists():
        shutil.rmtree(strings_dir)
    if not csv_paths:
        return None
    strings_dir.mkdir()
    by_lang: dict[str, tuple[list, list]] = {}
    owner: dict[tuple[str, int], str] = {}
    tmp = out / "csv.tmp"
    for path in csv_paths:
        tmp.write_bytes(git("cat-file", "blob", f"{ref}:{path}"))
        lang, strings, keys = w3strings.read_csv(tmp)
        all_strings, all_keys = by_lang.setdefault(lang, ([], []))
        for sid, text in strings:
            if (lang, sid) in owner:
                print(f"error: string id {sid} is in both {owner[(lang, sid)]} and {path}")
                sys.exit(1)
            owner[(lang, sid)] = path
            all_strings.append((sid, text))
        all_keys.extend(keys)
    tmp.unlink()
    for lang, (strings, keys) in sorted(by_lang.items()):
        (strings_dir / f"{lang}.w3strings").write_bytes(w3strings.encode(lang, strings, keys))
    print(f"encoded strings: {', '.join(f'{lang} ({len(s)})' for lang, (s, _) in sorted(by_lang.items()))}")
    return strings_dir


def copy_scripts(src: Path, out: Path) -> Path:
    """Copy a folder of scripts (laid out like content/scripts) into <out>/scripts."""
    if not src.is_dir():
        print(f"error: {src} is not a folder")
        sys.exit(1)
    target_dir = out / "scripts"
    if target_dir.exists():
        shutil.rmtree(target_dir)
    shutil.copytree(src, target_dir)
    paths = sorted(p.relative_to(target_dir).as_posix() for p in target_dir.rglob("*.ws"))
    print(f"collected {len(paths)} script(s) from {src}:")
    for path in paths:
        print(f"  {path}")
    return target_dir


def wcc(redkit: Path, args: list[str], out: Path, log_name: str, what: str) -> None:
    """Run a wcc_lite commandlet; exit with its [Error][WCC] lines if it fails."""
    exe = redkit / "bin" / "x64_RedKit" / "wcc_lite.exe"
    if not exe.exists():
        print(f"error: {exe} not found (pass --redkit)")
        sys.exit(1)
    # -agreetoterms accepts the REDkit EULA, which wcc_lite otherwise asks for in a dialog
    # that blocks the build (the project owner accepted it and approved passing the flag).
    # wcc_lite writes REDkit's wcc.log, script cache and temp\ and editoruser.settings, and listens on
    # port 37000: one run at a time across all checkouts (an OS file lock, freed if this process dies).
    lock = game_lock.FileLock(game_lock.Env().state / "wcc.lock", timeout=3600, what="the compiler slot (another wcc_lite run holds it)",
                              quiet=False)
    with lock:
        result = subprocess.run([str(exe), *args, "-agreetoterms"], cwd=exe.parent, capture_output=True, text=True,
                                errors="replace", timeout=600, creationflags=paths.BELOW_NORMAL)
    log = out / log_name
    log.write_text(result.stdout + result.stderr, encoding="utf-8")
    # wcc_lite also logs unrelated [Error] lines about missing config files and asserts
    errors = [line for line in (result.stdout + result.stderr).splitlines() if "][Error][WCC]" in line]
    if result.returncode != 0:
        print(f"error: {what} failed:")
        for line in errors:
            print(f"  {line.split('][Error][WCC] ', 1)[-1]}")
        print(f"full log: {log}")
        sys.exit(1)


def compile_scripts(scripts_dir: Path, game: Path, redkit: Path, out: Path) -> Path:
    """Compile the game's scripts plus the mod's into a blob; exit on errors."""
    blob_dir = out / "scripts.rsblob"
    if blob_dir.exists():
        shutil.rmtree(blob_dir)
    print("compiling scripts with wcc_lite ...")
    # wcc_lite wants directories with a trailing backslash
    wcc(redkit, ["compilescripts", str(game / "content" / "content0" / "scripts") + "\\",
                 f"-patch={scripts_dir}\\", f"-out={blob_dir}"], out, "compile.log", "script compilation")
    print(f"scripts compile (log: {out / 'compile.log'})")
    return blob_dir / "blob.rsblob"


def pack_files(files_dir: Path, redkit: Path, out: Path) -> Path:
    """Pack the mod's game files into a bundle with its metadata store; exit on errors."""
    bundle_dir = out / "bundles"
    if bundle_dir.exists():
        shutil.rmtree(bundle_dir)
    bundle_dir.mkdir()
    print("packing files with wcc_lite ...")
    wcc(redkit, ["pack", f"-dir={files_dir}\\", f"-outdir={bundle_dir}\\", "-compression=ZLIB"],
        out, "pack.log", "packing")
    wcc(redkit, ["metadatastore", f"-path={bundle_dir}\\"], out, "metadatastore.log", "metadata store")
    print(f"packed: {', '.join(sorted(p.name for p in bundle_dir.iterdir()))}")
    return bundle_dir


def pack_sounds(ref: str, bank_paths: list[str], out: Path) -> Path | None:
    """Pack the branch's Wwise banks into <out>/sound/soundspc.cache."""
    sound_dir = out / "sound"
    if sound_dir.exists():
        shutil.rmtree(sound_dir)
    if not bank_paths:
        return None
    banks_dir = sound_dir / "banks"
    banks_dir.mkdir(parents=True)
    banks = []
    for path in bank_paths:
        bank = banks_dir / Path(path).name
        bank.write_bytes(git("cat-file", "blob", f"{ref}:{path}"))
        banks.append(bank)
    cache = sound_dir / "soundspc.cache"
    soundcache.pack(cache, banks)
    print(f"packed sound banks: {', '.join(b.name for b in banks)}")
    return cache


def assemble(out: Path, name: str, source: str, scripts_dir: Path | None, blob: Path | None,
             bundle_dir: Path | None, strings_dir: Path | None = None, ref: str = "",
             menus: list[str] | None = None, sound_cache: Path | None = None) -> Path:
    """Lay out the mod folder: script blob (or loose scripts), bundles, strings, menus."""
    mod_dir = out / name
    if mod_dir.exists():
        shutil.rmtree(mod_dir)
    content = mod_dir / "content"
    content.mkdir(parents=True)
    parts = []
    if blob:
        shutil.copy2(blob, content / "precompiled.rsblob")
        parts.append("precompiled.rsblob")
    elif scripts_dir:
        shutil.copytree(scripts_dir, content / "scripts")
        parts.append("loose scripts")
    if bundle_dir:
        for f in bundle_dir.iterdir():
            shutil.copy2(f, content / f.name)
        parts.append("bundle")
    if strings_dir:
        for f in strings_dir.iterdir():
            shutil.copy2(f, content / f.name)
        parts.append("strings")
    if sound_cache:
        shutil.copy2(sound_cache, content / sound_cache.name)
        parts.append("sound banks")
    if menus:
        menu_dir = mod_dir / MENU_DIR
        menu_dir.mkdir(parents=True)
        for path in menus:
            (menu_dir / Path(path).name).write_bytes(git("cat-file", "blob", f"{ref}:{path}"))
        parts.append(f"menu ({', '.join(Path(p).name for p in menus)})")
    (mod_dir / MARKER).write_text(f"{source}\n")
    print(f"built {mod_dir} ({', '.join(parts)})")
    return mod_dir


def install(mod_dir: Path, game: Path) -> None:
    target = game / "mods" / mod_dir.name
    if target.exists():
        if not (target / MARKER).exists():
            print(f"error: {target} exists and was not installed by this script; not touching it")
            sys.exit(1)
        # remove the menu files the previous install put into the game's bin folder
        for line in (target / MARKER).read_text().splitlines()[1:]:
            old = game / line.strip()
            if line.strip() and old.is_file():
                old.unlink()
        shutil.rmtree(target)
    shutil.copytree(mod_dir, target, ignore=shutil.ignore_patterns("bin"))
    installed = []
    menu_src = mod_dir / MENU_DIR
    if menu_src.is_dir():
        (game / MENU_DIR).mkdir(parents=True, exist_ok=True)
        for f in sorted(menu_src.iterdir()):
            dest = game / MENU_DIR / f.name
            if dest.exists():
                print(f"error: {dest} already exists and is not ours; not overwriting it")
                sys.exit(1)
            shutil.copy2(f, dest)
            installed.append((MENU_DIR / f.name).as_posix())
    marker = target / MARKER
    lines = [marker.read_text().splitlines()[0], *installed]
    marker.write_text("".join(f"{line}\n" for line in lines))
    print(f"installed to {target}" + (f" (menu: {', '.join(installed)})" if installed else ""))


def check_settings(name: str, enable: bool) -> None:
    settings = documents_dir() / "The Witcher 3" / "mods.settings"
    cfg = configparser.ConfigParser()
    cfg.optionxform = str
    if settings.exists():
        cfg.read(settings, encoding="utf-8-sig")
    if cfg.has_section(name):
        state = "enabled" if cfg[name].get("Enabled", "1").strip() == "1" else "DISABLED"
        print(f"{settings}: [{name}] is {state}")
        return
    if not enable:
        print(f"{settings}: no [{name}] entry (pass --enable to add one)")
        return
    with settings.open("a", encoding="utf-8") as f:
        if settings.stat().st_size:
            f.write("\n")
        f.write(f"[{name}]\nEnabled=1\nPriority=100\n")
    print(f"{settings}: added [{name}] Enabled=1 Priority=100")


def gate_install(args) -> "game_lock.Gate":
    """Installing changes the shared game: the holder's token (or --parent), and the game closed."""
    try:
        g = game_lock.gate(args.holder, args.parent, "build_mod.py install")
    except game_lock.Refused as e:
        print(f"refused: {e}")
        sys.exit(e.code)
    game_lock.selftest_stop(g, "build_mod.py install")
    if game_lock.Env().game_running():
        print("error: the game is running; quit it first (python tools/game.py quit): scripts load only at game start")
        sys.exit(1)
    return g


def install_from(args) -> None:
    """Install a build made earlier (--out of a compile-only build), without rebuilding."""
    src = args.install_from.resolve()
    mod_dir = src / args.name
    if not (mod_dir / MARKER).exists():
        print(f"error: {mod_dir} is not a build of this script (no {MARKER}); build it first with --ref ... --out {src}")
        sys.exit(1)
    g = gate_install(args)
    install(mod_dir, args.game)
    marker = (args.game / "mods" / args.name / MARKER).read_text().splitlines()[0].strip()
    if args.name == "modGhostMode":
        game_lock.record_install(g, marker)
    print(f"installed build: {marker}")
    check_settings(args.name, args.enable)


def uninstall(args) -> None:
    """Remove the mod this script installed (and its menu files): the game slot is shared with
    TriangleGhostMode, whose runs must not load this mod. A folder in <game>/mods loads even without
    a mods.settings entry."""
    target = args.game / "mods" / args.name
    if not target.exists():
        print(f"{target} is not installed")
        return
    if not (target / MARKER).exists():
        print(f"error: {target} was not installed by this script; not touching it")
        sys.exit(1)
    gate_install(args)
    for line in (target / MARKER).read_text().splitlines()[1:]:
        old = args.game / line.strip()
        if line.strip() and old.is_file():
            old.unlink()
    shutil.rmtree(target)
    print(f"uninstalled {target}")


def package(mod_dir: Path, out: Path, name: str, ref: str) -> Path:
    """Zip a release build laid out like the game folder, so installing it is extracting it into <game>:
    mods/<name>/... (the mod) and bin/config/r4game/user_config_matrix/pc/*.xml (its options menu). Text files in
    the ref's release/ folder (manual install steps, e.g. key binding lines) go next to the mod, in mods/<name>/.
    Nothing is installed; the zip is for the player or for publishing."""
    import zipfile
    commit = git("rev-parse", "--short", ref).decode().strip()
    zip_path = out / f"{name}-{commit}.zip"
    if zip_path.exists():
        zip_path.unlink()
    count = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(mod_dir.rglob("*")):
            if not f.is_file() or f.name == MARKER:
                continue
            rel = f.relative_to(mod_dir)
            z.write(f, rel.as_posix() if rel.parts[0] == "bin" else (Path("mods") / name / rel).as_posix())
            count += 1
        for p in git("ls-tree", "--name-only", ref, "release/").decode().split():
            if p.endswith(".txt"):
                z.writestr((Path("mods") / name / Path(p).name).as_posix(), git("show", f"{ref}:{p}"))
                count += 1
    print(f"packaged {count} files: {zip_path} (extract it into the game folder to install)")
    return zip_path


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", help="branch or commit to build (required with no --scripts or --install-from)")
    ap.add_argument("--scripts", type=Path, help="build the scripts in this folder instead of a branch's changes")
    ap.add_argument("--base", default="vanilla-5.x", help="vanilla ref to diff against (default: vanilla-5.x)")
    ap.add_argument("--name", default=MOD, help=f"mod folder name (default: {MOD})")
    ap.add_argument("--out", type=Path, help="output directory (required to build; one per area and commit, e.g. build/wgt-<commit>)")
    ap.add_argument("--install-from", type=Path, metavar="OUT", help="install the build in OUT (an earlier --out) without rebuilding")
    ap.add_argument("--uninstall", action="store_true", help="remove the installed mod (needs --holder); do it before releasing the slot")
    ap.add_argument("--holder", help="AREA:TOKEN of the game slot's holder (tools/game_lock.py), needed to install")
    ap.add_argument("--parent", action="store_true", help="the parent only: install without the lock check (logged)")
    ap.add_argument("--install", action="store_true", help="copy the built mod into <game>/mods")
    ap.add_argument("--enable", action="store_true", help="with --install: add the mod to mods.settings if missing")
    ap.add_argument("--game", type=Path, help="game install directory (default: W3_GAME_DIR or Steam's, see tools/paths.py)")
    ap.add_argument("--redkit", type=Path, help="REDkit install directory, for wcc_lite (default: W3_REDKIT_DIR or Steam's)")
    ap.add_argument("--release", action="store_true", help="leave out the in-game test scripts (<mod>/scripts/local/prep/tests/): a build to play or publish")
    ap.add_argument("--package", action="store_true", help="zip the build laid out like the game folder (mods/<name>, the menu under bin/...), ready to install by extracting it into the game folder or to publish; implies --release; installs nothing")
    ap.add_argument("--loose", action="store_true", help="ship loose scripts instead of precompiled.rsblob")
    ap.add_argument("--no-compile", action="store_true", help="with --loose: skip the wcc_lite compile check")
    args = ap.parse_args()
    if args.no_compile and not args.loose:
        ap.error("--no-compile needs --loose (the blob is the compiler's output)")
    if args.package and (args.scripts or args.loose or args.install_from):
        ap.error("--package zips a release build of a branch: no --scripts, --loose or --install-from")
    if args.package:
        args.release = True
    args.game = args.game or paths.game_dir()
    if args.uninstall:
        uninstall(args)
        return
    if args.install_from:
        if args.ref or args.scripts or args.install:
            ap.error("--install-from installs an existing build: no --ref, --scripts or --install")
        install_from(args)
        return
    if not args.ref and not args.scripts:
        ap.error("--ref is required (the branch to build, e.g. prep/<slice>, or master)")
    if not args.out:
        ap.error("--out is required (a folder of your own, e.g. build/<area>-<commit>)")
    if args.install and args.scripts and not args.parent:
        ap.error("installing --scripts builds (modAutomation) is the parent's: --parent")
    gate = gate_install(args) if args.install else None  # fail fast, before a minute of building
    paths.below_normal()
    out = args.out.resolve()
    args.redkit = args.redkit or paths.redkit_dir()
    if args.ref:
        warn_uncommitted(args.ref)

    strings_dir, menus, sound_cache = None, [], None
    if args.scripts:
        scripts_dir, files_dir = copy_scripts(args.scripts.resolve(), out), None
    else:
        scripts_dir, files_dir, csv_paths, menus, bank_paths = collect(args.base, args.ref, out, args.release)
        strings_dir = encode_strings(args.ref, csv_paths, out)
        sound_cache = pack_sounds(args.ref, bank_paths, out)
    blob = None
    if scripts_dir and not args.no_compile:
        blob = compile_scripts(scripts_dir, args.game, args.redkit, out)
    bundle_dir = pack_files(files_dir, args.redkit, out) if files_dir else None
    source = str(args.scripts) if args.scripts else f"{args.ref} {git('rev-parse', args.ref).decode().strip()}"
    mod_dir = assemble(out, args.name, source, scripts_dir, None if args.loose else blob, bundle_dir, strings_dir,
                       args.ref, menus, sound_cache)
    if args.package:
        package(mod_dir, out, args.name, args.ref)
    if args.install:
        gate = gate_install(args)  # again: the build took a while
        install(mod_dir, args.game)
        if args.name == "modGhostMode":
            game_lock.record_install(gate, (args.game / "mods" / args.name / MARKER).read_text().splitlines()[0].strip())
        check_settings(args.name, args.enable)


if __name__ == "__main__":
    main()
