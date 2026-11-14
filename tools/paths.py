"""Where the game and REDkit are installed, without hard-coded paths.

Each tool takes its install folders from here:

    W3_GAME_DIR     The Witcher 3 (5.x) install folder
    W3_REDKIT_DIR   The Witcher 3 REDkit install folder
    STEAM_DIR       the Steam folder, only used when the two above are not set

Without the environment variables the folders are looked up in Steam: the Steam folder
from the registry (HKCU\\Software\\Valve\\Steam, SteamPath), its libraries from
steamapps\\libraryfolders.vdf, and each app's folder from its appmanifest_<id>.acf.

    python tools/paths.py      prints what it finds

Also shared by the tools: the user's Documents folder (`documents_dir`), the required
`--worktree` argument of the generators and checks (`add_worktree`), and below-normal CPU
priority for builds and generators (`below_normal`), so they disturb the game's
timing-sensitive checks less while another agent holds the game (docs/tools.md).
"""

import argparse
import ctypes
import os
import re
import sys
from ctypes import wintypes
from pathlib import Path

MOD = "modPreparations"  # the mod's folder in this repository (and its name once installed)

GAME_APP = "292030"      # The Witcher 3: Wild Hunt
REDKIT_APP = "2684660"   # The Witcher 3 REDkit


def steam_dir() -> Path | None:
    if os.environ.get("STEAM_DIR"):
        return Path(os.environ["STEAM_DIR"])
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            return Path(winreg.QueryValueEx(key, "SteamPath")[0])
    except OSError:
        return None


def steam_libraries() -> list[Path]:
    steam = steam_dir()
    if not steam:
        return []
    libraries = [steam]
    vdf = steam / "steamapps" / "libraryfolders.vdf"
    if vdf.exists():
        for value in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(encoding="utf-8", errors="replace")):
            path = Path(value.replace("\\\\", "\\"))
            if path not in libraries:
                libraries.append(path)
    return libraries


def steam_app_dir(app_id: str) -> Path | None:
    for library in steam_libraries():
        manifest = library / "steamapps" / f"appmanifest_{app_id}.acf"
        if manifest.exists():
            m = re.search(r'"installdir"\s+"([^"]+)"', manifest.read_text(encoding="utf-8", errors="replace"))
            if m:
                return library / "steamapps" / "common" / m.group(1)
    return None


def _find(env: str, app_id: str, what: str) -> Path:
    if os.environ.get(env):
        return Path(os.environ[env])
    found = steam_app_dir(app_id)
    if found:
        return found
    sys.exit(f"error: cannot find {what}: not installed through Steam (app {app_id}); set {env} to its folder")


def game_dir() -> Path:
    return _find("W3_GAME_DIR", GAME_APP, "The Witcher 3")


def redkit_dir() -> Path:
    return _find("W3_REDKIT_DIR", REDKIT_APP, "The Witcher 3 REDkit")


def documents_dir() -> Path:
    """The user's Documents folder, following OneDrive or other redirection."""
    folderid_documents = ctypes.c_byte * 16
    guid = folderid_documents(*bytes.fromhex("D09AD3FD8F23AF46ADB46C85480369C7"))
    path = ctypes.c_wchar_p()
    shell32 = ctypes.windll.shell32
    shell32.SHGetKnownFolderPath.argtypes = [ctypes.c_void_p, wintypes.DWORD, wintypes.HANDLE, ctypes.POINTER(ctypes.c_wchar_p)]
    if shell32.SHGetKnownFolderPath(ctypes.byref(guid), 0, None, ctypes.byref(path)) != 0:
        return Path.home() / "Documents"
    result = Path(path.value)
    ctypes.windll.ole32.CoTaskMemFree(path)
    return result


BELOW_NORMAL = 0x4000  # BELOW_NORMAL_PRIORITY_CLASS, also usable as subprocess creationflags


def below_normal() -> None:
    """Lower this process (and the processes it starts) to below-normal CPU priority."""
    try:
        k32 = ctypes.windll.kernel32
        k32.GetCurrentProcess.restype = wintypes.HANDLE
        k32.SetPriorityClass.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        k32.SetPriorityClass(k32.GetCurrentProcess(), BELOW_NORMAL)
    except (AttributeError, OSError, ctypes.ArgumentError):
        pass


def _worktree(value: str) -> str:
    if not os.path.isdir(os.path.join(value, MOD)):
        raise argparse.ArgumentTypeError(f"{value} is not a mod worktree (no {MOD} folder)")
    return value


def add_worktree(ap) -> None:
    """The generators' and checks' --worktree: required, so no tool reads or writes another area's
    worktree by default (parallel ports, docs/proposals/parallel-ports.md). Also lowers the priority."""
    ap.add_argument("--worktree", required=True, type=_worktree,
                    help="the mod worktree to read and write: the area's (../TGM-<area>) or the main checkout's (.)")
    below_normal()


if __name__ == "__main__":
    print(f"steam:  {steam_dir()}")
    print(f"game:   {game_dir()}")
    print(f"redkit: {redkit_dir()}")
    print(f"documents: {documents_dir()}")
